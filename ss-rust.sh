#!/usr/bin/env bash
set -Eeuo pipefail
exec bash <(curl -fsSL https://raw.githubusercontent.com/shuijiao1/ss-rust-manager/main/ss-rust.sh) "$@"
