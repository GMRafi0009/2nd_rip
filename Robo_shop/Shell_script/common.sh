#!/bin/bash

set -Eeuo pipefail


# ==============================================================================
# Common Variables
# ==============================================================================

readonly SCRIPT_NAME="$(basename "$0")"


# ==============================================================================
# Logging Functions
# ==============================================================================

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

    error "${SCRIPT_NAME} failed at line ${line_number} with exit code ${exit_code}."

    exit "${exit_code}"
}


trap 'on_error $LINENO' ERR


# ==============================================================================
# Root Validation
# ==============================================================================

validate_root() {

    if [[ "$(id -u)" -ne 0 ]]; then
        error "Root access is required."
        error "Please run this script with root access."
        error "Example: sudo ${SCRIPT_NAME}"
        exit 1
    fi

    log "Root access validated."
}


# ==============================================================================
# Operating System Validation
# ==============================================================================

validate_rhel() {

    local expected_version="${1}"

    if [[ ! -r /etc/os-release ]]; then
        error "/etc/os-release not found."
        exit 1
    fi

    source /etc/os-release

    if [[ "${ID}" != "rhel" ]]; then
        error "Unsupported operating system: ${ID}"
        exit 1
    fi

    if [[ "${VERSION_ID}" != "${expected_version}" ]]; then
        error "Expected RHEL ${expected_version}, found ${VERSION_ID}."
        exit 1
    fi

    log "Operating system validated: ${PRETTY_NAME}"
}


# ==============================================================================
# Architecture Validation
# ==============================================================================

validate_architecture() {

    local expected_architecture="${1}"

    local architecture
    architecture="$(uname -m)"

    if [[ "${architecture}" != "${expected_architecture}" ]]; then
        error "Unsupported architecture: ${architecture}"
        exit 1
    fi

    log "Architecture validated: ${architecture}"
}


# ==============================================================================
# Command Validation
# ==============================================================================

validate_commands() {

    local command

    for command in "$@"; do

        if ! command -v "${command}" >/dev/null 2>&1; then
            error "Required command not found: ${command}"
            exit 1
        fi

    done

    log "Required commands validated."
}


# ==============================================================================
# Package Validation
# ==============================================================================

is_package_installed() {

    local package_name="${1}"

    rpm -q "${package_name}" >/dev/null 2>&1
}


# ==============================================================================
# Service Validation
# ==============================================================================

verify_service_active() {

    local service_name="${1}"

    if systemctl is-active --quiet "${service_name}"; then

        log "Service '${service_name}' is active."

    else

        error "Service '${service_name}' is not active."
        error "Displaying service status:"

        systemctl status "${service_name}" --no-pager >&2

        exit 1

    fi
}


# ==============================================================================
# Service Enable
# ==============================================================================

enable_service() {

    local service_name="${1}"

    log "Enabling service '${service_name}'."

    if ! systemctl enable "${service_name}"; then
        error "Failed to enable service '${service_name}'."
        exit 1
    fi

    log "Service '${service_name}' enabled."
}


# ==============================================================================
# Service Start
# ==============================================================================

start_service() {

    local service_name="${1}"

    log "Starting service '${service_name}'."

    if ! systemctl start "${service_name}"; then

        error "Failed to start service '${service_name}'."

        systemctl status "${service_name}" --no-pager >&2

        exit 1
    fi

    log "Service '${service_name}' started."
}