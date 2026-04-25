"""
Crash-diagnosis harness for the long-running router/worker scenario.

Runs:  N_CALLERS callers  →  Router  →  Worker(N_WORKERS threads)

Each subprocess writes its native (Zig) log to a separate file so we can
reconstruct the exact event sequence across processes when a crash occurs.

Usage:
    python tests/perf/_diag_leak.py [N_CALLERS] [N_WORKERS] [CALL_DELAY_S] [MAX_WAIT_S]

Log files:
    /tmp/dafi_router.log   — router process (Zig native log)
    /tmp/dafi_worker.log   — worker process (Zig native log + faulthandler)
    /tmp/dafi_callers.log  — callers process (Zig native log)
"""

import multiprocessing as mp
mp.set_start_method("spawn", force=True)

import sys, time, socket, os, logging

HOST    = "127.0.0.1"
PAYLOAD = {"x": 42, "msg": "hello"}

ROUTER_LOG  = "/tmp/dafi_router.log"
WORKER_LOG  = "/tmp/dafi_worker.log"
CALLERS_LOG = "/tmp/dafi_callers.log"


def _free_port():
    with socket.socket() as s:
        s.bind((HOST, 0))
        return s.getsockname()[1]


def _redirect_native_log(log_path: str, native_level: int = 0) -> None:
    """Redirect fd-2 (stderr) to *log_path* and enable native Zig logging."""
    with open(log_path, "w") as f:
        os.dup2(f.fileno(), 2)  # native write(2,...) goes here
    from daffi import dfcore
    dfcore.setLogLevel(native_level)   # 0=DEBUG, 1=INFO, 2=WARN, 3=ERR, 4=off


# ─── subprocesses ─────────────────────────────────────────────────────────────

def proc_router(port):
    _redirect_native_log(ROUTER_LOG, native_level=0)

    # Python logging → same file so we see both Python and Zig events together
    logging.basicConfig(
        level=logging.DEBUG,
        filename=ROUTER_LOG,
        filemode="a",
        format="%(asctime)s [py-router] %(levelname)s %(message)s",
    )

    from daffi import Router
    r = Router(app_name="diag-router", host=HOST, port=port)
    r.start()
    r.join()


def proc_worker(port, n_workers):
    _redirect_native_log(WORKER_LOG, native_level=0)

    # Enable faulthandler on fd-2 (now the log file) so SIGSEGV/SIGABRT dumps
    # a native Python stack trace into the log.
    import faulthandler
    faulthandler.enable()

    logging.basicConfig(
        level=logging.DEBUG,
        filename=WORKER_LOG,
        filemode="a",
        format="%(asctime)s [py-worker] %(levelname)s %(message)s",
    )

    from daffi import Client, callback

    @callback
    def echo(p):
        return p

    logging.info(f"worker starting  n_workers={n_workers}")
    c = Client(app_name="diag-worker", host=HOST, port=port, workers=n_workers)
    c.connect()
    logging.info("worker connected and ready")

    try:
        while True:
            time.sleep(1)
    except (KeyboardInterrupt, SystemExit):
        logging.info("worker received interrupt")
    except Exception as e:
        logging.exception(f"worker exception: {e}")
    finally:
        logging.info("worker stopping")
        c.stop()
    logging.info("worker done")


def proc_callers(port, n_callers, delay_s):
    _redirect_native_log(CALLERS_LOG, native_level=1)  # INFO only — callers are noisy

    logging.basicConfig(
        level=logging.WARNING,
        filename=CALLERS_LOG,
        filemode="a",
        format="%(asctime)s [py-callers] %(levelname)s %(message)s",
    )

    import threading
    from daffi import Client

    clients = []
    for i in range(n_callers):
        try:
            cl = Client(app_name=f"dc-{i:03d}", host=HOST, port=port)
            clients.append((cl, cl.connect()))
        except Exception as e:
            if i < 5:
                logging.warning(f"caller {i} connect failed: {e}")

    logging.warning(f"connected {len(clients)}/{n_callers} callers")

    stop = threading.Event()
    calls = [0]; errors = [0]; lock = threading.Lock()

    def run(cl, conn):
        rpc = conn.rpc(timeout=10)
        while not stop.is_set():
            try:
                rpc.echo(PAYLOAD)
                with lock:
                    calls[0] += 1
                time.sleep(delay_s)
            except Exception:
                with lock:
                    errors[0] += 1
                time.sleep(0.1)

    threads = [
        threading.Thread(target=run, args=(cl, conn), daemon=True)
        for cl, conn in clients
    ]
    for t in threads:
        t.start()

    # Run until main process kills us
    try:
        while True:
            time.sleep(60)
            with lock:
                logging.warning(f"status: calls={calls[0]} errors={errors[0]}")
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        stop.set()


# ─── main monitor loop ────────────────────────────────────────────────────────

def _tail(path: str, n: int = 60) -> str:
    """Return the last *n* lines of *path*, or an error message."""
    try:
        with open(path) as f:
            lines = f.readlines()
        return "".join(lines[-n:])
    except Exception as e:
        return f"<could not read {path}: {e}>"


if __name__ == "__main__":
    N_CALLERS  = int(sys.argv[1])   if len(sys.argv) > 1 else 100
    N_WORKERS  = int(sys.argv[2])   if len(sys.argv) > 2 else 100
    DELAY      = float(sys.argv[3]) if len(sys.argv) > 3 else 0.01
    MAX_WAIT_S = int(sys.argv[4])   if len(sys.argv) > 4 else 120

    # Clear previous logs
    for p in (ROUTER_LOG, WORKER_LOG, CALLERS_LOG):
        open(p, "w").close()

    print(
        f"callers={N_CALLERS}  worker_threads={N_WORKERS}  "
        f"delay={DELAY}s  max_wait={MAX_WAIT_S}s",
        flush=True,
    )
    print(
        f"logs: router={ROUTER_LOG}  worker={WORKER_LOG}  "
        f"callers={CALLERS_LOG}",
        flush=True,
    )

    port   = _free_port()
    router = mp.Process(target=proc_router,  args=(port,), daemon=True)
    worker = mp.Process(target=proc_worker,  args=(port, N_WORKERS), daemon=True)

    router.start()
    time.sleep(0.5)
    worker.start()
    time.sleep(2.5)   # wait for worker to connect + handshake

    callers = mp.Process(target=proc_callers, args=(port, N_CALLERS, DELAY), daemon=True)
    callers.start()

    # ── monitor ──────────────────────────────────────────────────────────────
    poll_interval = 3   # seconds between liveness checks
    elapsed       = 0
    crash_at      = None

    while elapsed < MAX_WAIT_S:
        time.sleep(poll_interval)
        elapsed += poll_interval

        r_ok = router.is_alive()
        w_ok = worker.is_alive()
        c_ok = callers.is_alive()

        if not r_ok or not w_ok:
            who = []
            if not r_ok:
                who.append(f"ROUTER(exitcode={router.exitcode})")
            if not w_ok:
                who.append(f"WORKER(exitcode={worker.exitcode})")
            crash_at = elapsed
            print(f"\n!!! CRASH at t={elapsed}s: {', '.join(who)} !!!", flush=True)
            break

        if elapsed % 15 == 0:
            print(f"t={elapsed:4d}s  router=OK  worker=OK  callers={c_ok}", flush=True)

    else:
        print(f"\nAll processes survived {MAX_WAIT_S}s — no crash detected.", flush=True)

    # ── kill everything ───────────────────────────────────────────────────────
    for p in (callers, worker, router):
        try:
            p.terminate()
        except Exception:
            pass
    for p in (callers, worker, router):
        p.join(timeout=5)

    # ── print logs ────────────────────────────────────────────────────────────
    SEP = "=" * 70

    if crash_at is not None:
        print(f"\n{SEP}")
        print(f"ROUTER log (last 60 lines from {ROUTER_LOG}):")
        print(SEP)
        print(_tail(ROUTER_LOG, 60))

        print(f"\n{SEP}")
        print(f"WORKER log (last 80 lines from {WORKER_LOG}):")
        print(SEP)
        print(_tail(WORKER_LOG, 80))

        print(f"\n{SEP}")
        print(f"CALLERS log (last 20 lines from {CALLERS_LOG}):")
        print(SEP)
        print(_tail(CALLERS_LOG, 20))
    else:
        print("\nNo crash — logs omitted (use --tail to view them manually).")
