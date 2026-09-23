#!/bin/bash

set -Eeuo pipefail


# ==============================================================================
# Bootstrap Configuration
# ==============================================================================

readonly SCRIPT_NAME="$(basename "$0")"

readonly REPOSITORY_URL="https://github.com/GMRafi0009/2nd_rip.git"

readonly REPOSITORY_DIR="/opt/2nd_rip"

readonly COMMIT_ID="cfaea0c77c520bb4fdf559a918b4ddaa9bacf4bd"

readonly INSTALL_SCRIPT_RELATIVE_PATH="Robo_shop/Shell_script/install-mysql.sh"

readonly INSTALL_SCRIPT="${REPOSITORY_DIR}/${INSTALL_SCRIPT_RELATIVE_PATH}"

readonly SERVICE_NAME="mysqld"

readonly LOG_FILE="/var/log/mysql-bootstrap.log"


# ==============================================================================
# Logging
# ==============================================================================

exec > >(tee -a "${LOG_FILE}") 2>&1


log() {

    printf '[INFO] %s\n' "$*"
}


error() {

    printf '[ERROR] %s\n' "$*" >&2
}


# ==============================================================================
# Error Handling
# ==============================================================================

on_error() {

    local exit_code=$?
    local line_number=$1

    error "User Data failed at line ${line_number} with exit code ${exit_code}."

    exit "${exit_code}"
}


trap 'on_error $LINENO' ERR


# ==============================================================================
# Root Validation
# ==============================================================================

validate_root() {

    if [[ "$(id -u)" -ne 0 ]]; then

        error "User Data must run as root."

        exit 1
    fi

    log "Root access validated."
}


# ==============================================================================
# Git Installation
# ==============================================================================

install_git() {

    if command -v git >/dev/null 2>&1; then

        log "Git is already installed."

        return 0
    fi


    log "Installing Git."

    dnf install -y git

    log "Git installation completed."
}


# ==============================================================================
# Repository Cleanup
# ==============================================================================

remove_existing_repository() {

    if [[ -d "${REPOSITORY_DIR}" ]]; then

        log "Removing existing repository directory."

        rm -rf "${REPOSITORY_DIR}"
    fi
}


# ==============================================================================
# Repository Clone
# ==============================================================================

clone_repository() {

    log "Cloning GitHub repository."

    git clone \
        "${REPOSITORY_URL}" \
        "${REPOSITORY_DIR}"

    log "GitHub repository cloned."
}


# ==============================================================================
# Checkout Exact Commit
# ==============================================================================

checkout_commit() {

    log "Checking out commit ${COMMIT_ID}."

    git \
        -C "${REPOSITORY_DIR}" \
        checkout \
        --detach \
        "${COMMIT_ID}"

    log "Required commit checked out."
}


# ==============================================================================
# Commit Verification
# ==============================================================================

verify_commit() {

    local current_commit

    current_commit="$(
        git \
            -C "${REPOSITORY_DIR}" \
            rev-parse HEAD
    )"


    if [[ "${current_commit}" != "${COMMIT_ID}" ]]; then

        error "Git commit verification failed."
        error "Expected: ${COMMIT_ID}"
        error "Found:    ${current_commit}"

        exit 1
    fi


    log "Git commit verified: ${current_commit}"
}


# ==============================================================================
# Installation Script Verification
# ==============================================================================

verify_installation_script() {

    if [[ ! -f "${INSTALL_SCRIPT}" ]]; then

        error "Installation script not found:"
        error "${INSTALL_SCRIPT}"

        exit 1
    fi


    log "Installation script found:"
    log "${INSTALL_SCRIPT}"
}


# ==============================================================================
# Installation Script Permissions
# ==============================================================================

configure_installation_script_permissions() {

    chmod 700 "${INSTALL_SCRIPT}"

    log "Installation script permissions configured."
}


# ==============================================================================
# Execute Installation Script
# ==============================================================================

execute_installation_script() {

    log "Starting installation."
    log "Script: ${INSTALL_SCRIPT}"

    "${INSTALL_SCRIPT}"

    log "Installation script completed successfully."
}


# ==============================================================================
# Service Verification
# ==============================================================================

verify_service() {

    if systemctl is-active --quiet "${SERVICE_NAME}"; then

        log "Service '${SERVICE_NAME}' is ACTIVE."

    else

        error "Service '${SERVICE_NAME}' is NOT ACTIVE."

        systemctl status \
            "${SERVICE_NAME}" \
            --no-pager \
            >&2

        exit 1
    fi
}


# ==============================================================================
# Final Result
# ==============================================================================

display_final_result() {

    log "=================================================="
    log "EC2 bootstrap completed successfully."
    log "Repository: ${REPOSITORY_URL}"
    log "Commit:     ${COMMIT_ID}"
    log "Script:     ${INSTALL_SCRIPT}"
    log "Service:    ${SERVICE_NAME}"
    log "Status:     ACTIVE"
    log "=================================================="
}


# ==============================================================================
# Main
# ==============================================================================

main() {

    log "=================================================="
    log "Starting EC2 bootstrap."
    log "=================================================="


    # --------------------------------------------------------------------------
    # 1. Validate root
    # --------------------------------------------------------------------------

    validate_root


    # --------------------------------------------------------------------------
    # 2. Install Git
    # --------------------------------------------------------------------------

    install_git


    # --------------------------------------------------------------------------
    # 3. Remove existing repository
    # --------------------------------------------------------------------------

    remove_existing_repository


    # --------------------------------------------------------------------------
    # 4. Clone repository
    # --------------------------------------------------------------------------

    clone_repository


    # --------------------------------------------------------------------------
    # 5. Checkout exact commit
    # --------------------------------------------------------------------------

    checkout_commit


    # --------------------------------------------------------------------------
    # 6. Verify commit
    # --------------------------------------------------------------------------

    verify_commit


    # --------------------------------------------------------------------------
    # 7. Verify installation script
    # --------------------------------------------------------------------------

    verify_installation_script


    # --------------------------------------------------------------------------
    # 8. Configure installation script permissions
    # --------------------------------------------------------------------------

    configure_installation_script_permissions


    # --------------------------------------------------------------------------
    # 9. Execute installation script
    # --------------------------------------------------------------------------

    execute_installation_script


    # --------------------------------------------------------------------------
    # 10. Verify service
    # --------------------------------------------------------------------------

    verify_service


    # --------------------------------------------------------------------------
    # 11. Final result
    # --------------------------------------------------------------------------

    display_final_result
}


# ==============================================================================
# Script Entry Point
# ==============================================================================

main "$@"

exit 0