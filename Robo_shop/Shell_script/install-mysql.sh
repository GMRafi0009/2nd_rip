#!/bin/bash

set -Eeuo pipefail


# ==============================================================================
# Load Common Functions
# ==============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPT="${SCRIPT_DIR}/common.sh"

if [[ ! -f "${COMMON_SCRIPT}" ]]; then
    printf '[ERROR] Common script not found: %s\n' "${COMMON_SCRIPT}" >&2
    exit 1
fi

source "${COMMON_SCRIPT}"


# ==============================================================================
# MySQL Configuration
# ==============================================================================

readonly EXPECTED_RHEL_VERSION="9.7"
readonly EXPECTED_ARCHITECTURE="x86_64"

readonly MYSQL_REPO_RPM="mysql97-community-release-el9-1.noarch.rpm"

readonly MYSQL_REPO_URL="https://dev.mysql.com/get/${MYSQL_REPO_RPM}"

readonly MYSQL_PACKAGE="mysql-community-server"

readonly MYSQL_SERVICE="mysqld"


# ==============================================================================
# Temporary Directory
# ==============================================================================

TMP_DIR=""


# ==============================================================================
# Cleanup
# ==============================================================================

cleanup() {

    if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
}


trap cleanup EXIT


# ==============================================================================
# MySQL Repository Installation
# ==============================================================================

install_mysql_repository() {

    log "Creating temporary directory."

    TMP_DIR="$(mktemp -d)"

    log "Downloading official MySQL repository package."

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --output "${TMP_DIR}/${MYSQL_REPO_RPM}" \
        "${MYSQL_REPO_URL}"

    log "Installing MySQL repository."

    dnf install -y \
        "${TMP_DIR}/${MYSQL_REPO_RPM}"

    log "Refreshing DNF metadata."

    dnf makecache

    verify_mysql_repository
}


# ==============================================================================
# MySQL Repository Verification
# ==============================================================================

verify_mysql_repository() {

    log "Verifying MySQL repository."

    if ! dnf repolist enabled | grep -qi 'mysql'; then
        error "MySQL repository is not enabled."
        exit 1
    fi

    log "MySQL repository verified."
}


# ==============================================================================
# MySQL Package Installation
# ==============================================================================

install_mysql_package() {

    log "Installing MySQL Community Server."

    if ! dnf install -y "${MYSQL_PACKAGE}"; then

        error "MySQL installation failed."
        error "Check the DNF output above for the installation error."

        exit 1
    fi

    log "MySQL package installation completed."
}


# ==============================================================================
# MySQL Package Verification
# ==============================================================================

verify_mysql_package() {

    log "Verifying MySQL package."

    if is_package_installed "${MYSQL_PACKAGE}"; then

        log "MySQL package installation verified."

    else

        error "MySQL package verification failed."
        error "Package '${MYSQL_PACKAGE}' is not installed."

        exit 1
    fi
}


# ==============================================================================
# MySQL Version
# ==============================================================================

display_mysql_version() {

    local mysql_version

    mysql_version="$(mysqld --version)"

    log "Installed MySQL: ${mysql_version}"
}


# ==============================================================================
# Main Function
# ==============================================================================

main() {

    log "=================================================="
    log "Starting MySQL installation."
    log "=================================================="


    # --------------------------------------------------------------------------
    # 1. Validate root
    # --------------------------------------------------------------------------

    validate_root


    # --------------------------------------------------------------------------
    # 2. Validate operating system
    # --------------------------------------------------------------------------

    validate_rhel "${EXPECTED_RHEL_VERSION}"


    # --------------------------------------------------------------------------
    # 3. Validate architecture
    # --------------------------------------------------------------------------

    validate_architecture "${EXPECTED_ARCHITECTURE}"


    # --------------------------------------------------------------------------
    # 4. Validate required commands
    # --------------------------------------------------------------------------

    validate_commands curl rpm dnf systemctl


    # --------------------------------------------------------------------------
    # 5. Check whether MySQL is already installed
    # --------------------------------------------------------------------------

    if is_package_installed "${MYSQL_PACKAGE}"; then

        log "MySQL Community Server is already installed."

    else

        # ----------------------------------------------------------------------
        # 6. Install MySQL repository
        # ----------------------------------------------------------------------

        install_mysql_repository


        # ----------------------------------------------------------------------
        # 7. Install MySQL package
        # ----------------------------------------------------------------------

        install_mysql_package

    fi


    # --------------------------------------------------------------------------
    # 8. Verify MySQL package
    # --------------------------------------------------------------------------

    verify_mysql_package


    # --------------------------------------------------------------------------
    # 9. Enable MySQL service
    # --------------------------------------------------------------------------

    enable_service "${MYSQL_SERVICE}"


    # --------------------------------------------------------------------------
    # 10. Start MySQL service
    # --------------------------------------------------------------------------

    start_service "${MYSQL_SERVICE}"


    # --------------------------------------------------------------------------
    # 11. Verify MySQL service
    # --------------------------------------------------------------------------

    verify_service_active "${MYSQL_SERVICE}"


    # --------------------------------------------------------------------------
    # 12. Display MySQL version
    # --------------------------------------------------------------------------

    display_mysql_version


    # --------------------------------------------------------------------------
    # 13. Final result
    # --------------------------------------------------------------------------

    log "=================================================="
    log "MySQL installation completed successfully."
    log "MySQL service: ACTIVE"
    log "=================================================="
}


# ==============================================================================
# Script Entry Point
# ==============================================================================

main "$@"

exit 0