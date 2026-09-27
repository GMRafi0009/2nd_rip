#!/bin/bash

set -Eeuo pipefail

require_root() {
    [ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
}