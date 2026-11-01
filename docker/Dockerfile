FROM python:3.12-slim-bookworm

WORKDIR /opt

COPY main.py .

RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install daffi

# Listen port comes from DAFFI_PORT at runtime.
CMD ["python3", "-u", "main.py"]
