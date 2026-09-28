#!/bin/bash

set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly TIMESTAMP="$(date '+%Y-%m-%d-%H-%M-%S')"
readonly LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# To use the log function:
# log "Deployment started"
#
# Output:
# [2026-09-27 03:33:10] Deployment started

VALIDATE() {
    local status="$1"
    local message="$2"

    if [ "$status" -ne 0 ]; then
        echo -e "$message ... ${R}FAILED${N}" | tee -a "$LOGFILE"
        return "$status"
    else
        echo -e "$message ... ${G}SUCCESS${N}" | tee -a "$LOGFILE"
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${R}ERROR: Script must be run with root privileges.${N}" >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <package1> <package2> ..." >&2
    exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
    echo -e "${R}ERROR: dnf command not found.${N}" >&2
    exit 1
fi

log "Script started"

for package in "$@"; do
    if dnf list installed "$package" >/dev/null 2>&1; then
        echo -e "${package} ... ${Y}SKIPPING${N}" | tee -a "$LOGFILE"
        continue
    fi

    if dnf install -y "$package" >>"$LOGFILE" 2>&1; then
        VALIDATE 0 "Installation of $package"
    else
        VALIDATE 1 "Installation of $package"
        exit 1
    fi
done

log "Script completed successfully"

exit 0