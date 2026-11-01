"""The open-file soft limit doubles as descriptors are opened."""

import subprocess
import sys
import textwrap


def test_wakeup_doubles_the_soft_nofile_limit():
    script = textwrap.dedent(
        """
        import resource
        import sys

        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        if hard < 256 and hard != resource.RLIM_INFINITY:
            sys.exit(0)
        resource.setrlimit(resource.RLIMIT_NOFILE, (64, hard))
        from daffi._wakeup import WakeupFd

        opened = [WakeupFd(pipe=True) for _ in range(40)]
        try:
            raised, _ = resource.getrlimit(resource.RLIMIT_NOFILE)
        finally:
            for channel in opened:
                channel.close()
        # 40 pipes are 80 descriptors. Growth starts 100 below the limit,
        # so 64 doubles to 128 and then to 256. 80 + 100 fits in 256.
        if raised != 256 and not (hard < 256 and raised == hard):
            sys.exit(f"soft limit became {raised}, expected 256")
        """
    )
    proc = subprocess.run(
        [sys.executable, "-c", script],
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr or proc.stdout
