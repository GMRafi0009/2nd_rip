#!/bin/bash

set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly MYSQL_REPO_RPM="mysql97-community-release-el9-1.noarch.rpm"
readonly MYSQL_REPO_URL="https://dev.mysql.com/get/${MYSQL_REPO_RPM}"
readonly MYSQL_PACKAGE="mysql-community-server"

log() {
    printf '[INFO] %s\n' "$*"
}

error() {
    printf '[ERROR] %s\n' "$*" >&2
}

on_error() {
    local exit_code=$?
    local line_number=$1

    error "${SCRIPT_NAME} failed at line ${line_number} with exit code ${exit_code}."
    exit "$exit_code"
}

trap 'on_error $LINENO' ERR


# ------------------------------------------------------------------------------
# 1. Validate root access
# ------------------------------------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
    error "Root access is required to install MySQL."
    error "Please run this script with root access."
    error "Example: sudo ${SCRIPT_NAME}"
    exit 1
fi

log "Root access validated."


# ------------------------------------------------------------------------------
# 2. Validate operating system
# ------------------------------------------------------------------------------

if [[ ! -r /etc/os-release ]]; then
    error "/etc/os-release not found."
    exit 1
fi

source /etc/os-release

if [[ "${ID}" != "rhel" ]]; then
    error "Unsupported operating system: ${ID}"
    exit 1
fi

if [[ "${VERSION_ID}" != "9.7" ]]; then
    error "Expected RHEL 9.7, found ${VERSION_ID}."
    exit 1
fi

log "Operating system validated: ${PRETTY_NAME}"


# ------------------------------------------------------------------------------
# 3. Validate architecture
# ------------------------------------------------------------------------------

ARCHITECTURE="$(uname -m)"

if [[ "${ARCHITECTURE}" != "x86_64" ]]; then
    error "Unsupported architecture: ${ARCHITECTURE}"
    exit 1
fi

log "Architecture validated: ${ARCHITECTURE}"


# ------------------------------------------------------------------------------
# 4. Validate required commands
# ------------------------------------------------------------------------------

for command in curl rpm dnf systemctl; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        error "Required command not found: ${command}"
        exit 1
    fi
done

log "Required commands validated."


# ------------------------------------------------------------------------------
# 5. Check whether MySQL is already installed
# ------------------------------------------------------------------------------

if rpm -q "${MYSQL_PACKAGE}" >/dev/null 2>&1; then
    log "MySQL Community Server is already installed."
else

    # --------------------------------------------------------------------------
    # 6. Create temporary directory
    # --------------------------------------------------------------------------

    readonly TMP_DIR="$(mktemp -d)"

    cleanup() {
        rm -rf "${TMP_DIR}"
    }

    trap cleanup EXIT

    # --------------------------------------------------------------------------
    # 7. Download official MySQL repository RPM
    # --------------------------------------------------------------------------

    log "Downloading official MySQL repository package."

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --output "${TMP_DIR}/${MYSQL_REPO_RPM}" \
        "${MYSQL_REPO_URL}"

    # --------------------------------------------------------------------------
    # 8. Install MySQL repository
    # --------------------------------------------------------------------------

    log "Installing MySQL repository."

    dnf install -y \
        "${TMP_DIR}/${MYSQL_REPO_RPM}"

    # --------------------------------------------------------------------------
    # 9. Refresh DNF metadata
    # --------------------------------------------------------------------------

    log "Refreshing DNF metadata."

    dnf makecache

    # --------------------------------------------------------------------------
    # 10. Verify MySQL repository
    # --------------------------------------------------------------------------

    if ! dnf repolist enabled | grep -qi 'mysql'; then
        error "MySQL repository is not enabled."
        exit 1
    fi

    log "MySQL repository verified."

    # --------------------------------------------------------------------------
    # 11. Install MySQL
    # --------------------------------------------------------------------------

    log "Installing MySQL Community Server."

    if ! dnf install -y "${MYSQL_PACKAGE}"; then
        error "MySQL installation failed."
        error "Check the DNF output above for the installation error."
        exit 1
    fi

    log "MySQL package installation completed."

fi


# ------------------------------------------------------------------------------
# 12. Verify MySQL package installation
# ------------------------------------------------------------------------------

if rpm -q "${MYSQL_PACKAGE}" >/dev/null 2>&1; then
    log "MySQL package installation verified."
else
    error "MySQL package verification failed."
    error "Package '${MYSQL_PACKAGE}' is not installed."
    exit 1
fi


# ------------------------------------------------------------------------------
# 13. Enable MySQL service
# ------------------------------------------------------------------------------

log "Enabling MySQL service."

if ! systemctl enable mysqld; then
    error "Failed to enable mysqld service."
    exit 1
fi


# ------------------------------------------------------------------------------
# 14. Start MySQL service
# ------------------------------------------------------------------------------

log "Starting MySQL service."

if ! systemctl start mysqld; then
    error "Failed to start mysqld service."

    systemctl status mysqld --no-pager >&2

    exit 1
fi


# ------------------------------------------------------------------------------
# 15. Verify MySQL service
# ------------------------------------------------------------------------------

if systemctl is-active --quiet mysqld; then
    log "MySQL service is active."
else
    error "MySQL service is not active."
    error "Displaying mysqld service status:"

    systemctl status mysqld --no-pager >&2

    exit 1
fi


# ------------------------------------------------------------------------------
# 16. Display installed MySQL version
# ------------------------------------------------------------------------------

MYSQL_VERSION="$(mysqld --version)"

log "Installed MySQL: ${MYSQL_VERSION}"


# ------------------------------------------------------------------------------
# 17. Final result
# ------------------------------------------------------------------------------

log "=================================================="
log "MySQL installation completed successfully."
log "MySQL service: ACTIVE"
log "=================================================="

exit 0
