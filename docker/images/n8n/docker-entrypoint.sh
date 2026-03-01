#!/bin/sh
set -e

# Load .env from S3 if S3_ENV_URI is set (e.g. s3://bucket/n8n.env)
if [ -n "$S3_ENV_URI" ]; then
  if command -v aws >/dev/null 2>&1; then
    echo "Loading env from S3: $S3_ENV_URI"
    tmp_env="/tmp/n8n-env.$$"
    if aws s3 cp "$S3_ENV_URI" "$tmp_env" 2>/dev/null; then
      set -a
      # shellcheck source=/dev/null
      . "$tmp_env"
      set +a
      rm -f "$tmp_env"
    else
      echo "Warning: failed to fetch S3_ENV_URI=$S3_ENV_URI" >&2
    fi
  else
    echo "Warning: S3_ENV_URI set but aws CLI not available" >&2
  fi
fi

if [ -d /opt/custom-certificates ]; then
  echo "Trusting custom certificates from /opt/custom-certificates."
  export NODE_OPTIONS="--use-openssl-ca $NODE_OPTIONS"
  export SSL_CERT_DIR=/opt/custom-certificates
  c_rehash /opt/custom-certificates
fi

if [ "$#" -gt 0 ]; then
  exec n8n "$@"
else
  exec n8n
fi
