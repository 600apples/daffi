#!/usr/bin/env bash
# Regenerate all self-signed TLS certificates for the 05_tls example.
# Run from the certs/ directory:
#   cd examples/service_to_service/05_tls/certs && bash gen_certs.sh
set -euo pipefail

DAYS=3650

echo "==> Generating CA key and self-signed certificate..."
openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.crt -days $DAYS -nodes \
    -subj "/C=US/ST=Dev/O=daffi-example/CN=daffi-CA"

echo "==> Generating server private key and CSR..."
openssl req -newkey rsa:2048 -keyout server.key -out server.csr -nodes \
    -subj "/C=US/ST=Dev/O=daffi-example/CN=127.0.0.1"

echo "==> Signing server certificate with the CA..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days $DAYS \
    -extfile <(printf "subjectAltName=IP:127.0.0.1,DNS:localhost")

echo "==> Done. Files:"
ls -1 *.crt *.key
