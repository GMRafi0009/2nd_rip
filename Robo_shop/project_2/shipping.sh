#!/bin/bash

set -Eeuo pipefail

# ============================================================
# RoboShop - Shipping Service Installation
# LAB ENVIRONMENT ONLY
# ============================================================

ID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

SCRIPT_NAME=$(basename "$0")
TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

# ------------------------------------------------------------
# Application configuration
# ------------------------------------------------------------

APP_DIR="/app"
ZIP_FILE="/tmp/shipping.zip"
DOWNLOAD_URL="https://roboshop-builds.s3.amazonaws.com/shipping.zip"

SERVICE_NAME="shipping"
SERVICE_FILE="/etc/systemd/system/shipping.service"

CART_ENDPOINT="cart.3gb.online:8080"

# ------------------------------------------------------------
# MySQL configuration
# LAB ONLY
# ------------------------------------------------------------

MYSQL_HOST="mysql.3gb.online"

MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD="RoboShop@1"

MYSQL_APP_USER="shipping"
MYSQL_APP_PASSWORD="RoboShop@1"

MYSQL_DATABASE="cities"

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

echo "Script started at ${TIMESTAMP}" &>> "$LOGFILE"

log() {
    echo -e "$(date '+%F %T') $*" | tee -a "$LOGFILE"
}

VALIDATE() {
    if [ "$1" -ne 0 ]; then
        echo -e "$2 ... ${R}FAILED${N}"
        echo "Check log file: $LOGFILE"
        exit 1
    else
        echo -e "$2 ... ${G}SUCCESS${N}"
    fi
}

on_error() {
    local exit_code=$?
    local line_number=$1

    echo -e "${R}ERROR: Script failed at line ${line_number}${N}" \
        | tee -a "$LOGFILE"

    echo -e "${R}Check log file: ${LOGFILE}${N}" \
        | tee -a "$LOGFILE"

    exit "$exit_code"
}

trap 'on_error $LINENO' ERR

# ============================================================
# 1. Root validation
# ============================================================

if [ "$ID" -ne 0 ]; then

    echo -e "${R}ERROR :: Please run this script with root access${N}"
    exit 1

fi

echo -e "You are ${G}root user${N}"

# ============================================================
# 2. Install required packages
# ============================================================

dnf install maven -y &>> "$LOGFILE"
VALIDATE $? "Installing Maven"

dnf install mysql -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL client"

# ============================================================
# 3. Validate required commands
# ============================================================

command -v java &>> "$LOGFILE"
VALIDATE $? "Checking Java"

command -v mvn &>> "$LOGFILE"
VALIDATE $? "Checking Maven"

command -v mysql &>> "$LOGFILE"
VALIDATE $? "Checking MySQL client"

command -v curl &>> "$LOGFILE"
VALIDATE $? "Checking curl"

command -v unzip &>> "$LOGFILE"
VALIDATE $? "Checking unzip"

# ============================================================
# 4. Create roboshop user
# ============================================================

if id roboshop &>> "$LOGFILE"; then

    echo -e "roboshop user already exists ${Y}SKIPPING${N}"

else

    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"

fi

# ============================================================
# 5. Create application directory
# ============================================================

mkdir -p "$APP_DIR"
VALIDATE $? "Creating application directory"

# ============================================================
# 6. Download Shipping application
# ============================================================

curl -fL \
    -o "$ZIP_FILE" \
    "$DOWNLOAD_URL" \
    &>> "$LOGFILE"

VALIDATE $? "Downloading Shipping application"

# ============================================================
# 7. Extract Shipping application
# ============================================================

unzip -o "$ZIP_FILE" -d "$APP_DIR" &>> "$LOGFILE"
VALIDATE $? "Extracting Shipping application"

# ============================================================
# 8. Build Shipping application
# ============================================================

cd "$APP_DIR"

mvn clean package &>> "$LOGFILE"
VALIDATE $? "Building Shipping application"

# ============================================================
# 9. Create shipping.jar
# ============================================================

if [ -f "$APP_DIR/target/shipping-1.0.jar" ]; then

    mv -f \
        "$APP_DIR/target/shipping-1.0.jar" \
        "$APP_DIR/shipping.jar" \
        &>> "$LOGFILE"

    VALIDATE $? "Creating shipping.jar"

else

    echo -e "${R}ERROR :: target/shipping-1.0.jar not found${N}"
    exit 1

fi

# ============================================================
# 10. Check remote MySQL connectivity
# ============================================================

mysql \
    -h "$MYSQL_HOST" \
    -u"$MYSQL_ROOT_USER" \
    -p"$MYSQL_ROOT_PASSWORD" \
    -e "SELECT VERSION();" \
    &>> "$LOGFILE"

VALIDATE $? "Checking MySQL connectivity"

# ============================================================
# 11. Check whether city data already exists
#
# IMPORTANT:
# schema.sql contains DROP TABLE IF EXISTS.
#
# Therefore we DO NOT blindly execute schema.sql.
# If city data already exists, preserve it.
# ============================================================

CITY_COUNT=0

if mysql \
    -h "$MYSQL_HOST" \
    -u"$MYSQL_ROOT_USER" \
    -p"$MYSQL_ROOT_PASSWORD" \
    -Nse "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.cities;" \
    &>> "$LOGFILE"
then

    CITY_COUNT=$(
        mysql \
            -h "$MYSQL_HOST" \
            -u"$MYSQL_ROOT_USER" \
            -p"$MYSQL_ROOT_PASSWORD" \
            -Nse "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.cities;" \
            2>> "$LOGFILE"
    )

fi

echo "Existing city count: ${CITY_COUNT}" | tee -a "$LOGFILE"

# ============================================================
# 12. Initialize database only when city data is absent
# ============================================================

if [ "$CITY_COUNT" -gt 0 ]; then

    echo -e "City data already exists ${G}SKIPPING database initialization${N}"

else

    echo -e "${Y}City data not found. Initializing database...${N}"

    # --------------------------------------------------------
    # Create schema
    # --------------------------------------------------------

    mysql \
        -h "$MYSQL_HOST" \
        -u"$MYSQL_ROOT_USER" \
        -p"$MYSQL_ROOT_PASSWORD" \
        < "$APP_DIR/db/schema.sql" \
        &>> "$LOGFILE"

    VALIDATE $? "Loading Shipping database schema"

    # --------------------------------------------------------
    # Load master data
    # --------------------------------------------------------

    mysql \
        -h "$MYSQL_HOST" \
        -u"$MYSQL_ROOT_USER" \
        -p"$MYSQL_ROOT_PASSWORD" \
        < "$APP_DIR/db/master-data.sql" \
        &>> "$LOGFILE"

    VALIDATE $? "Loading Shipping city master data"

fi

# ============================================================
# 13. Create Shipping application user
#
# DO NOT use app-user.sql because it explicitly requests:
#
# mysql_native_password
#
# Your MySQL 9.7 server uses caching_sha2_password.
# ============================================================

mysql \
    -h "$MYSQL_HOST" \
    -u"$MYSQL_ROOT_USER" \
    -p"$MYSQL_ROOT_PASSWORD" \
    -e "
CREATE USER IF NOT EXISTS '${MYSQL_APP_USER}'@'%' IDENTIFIED BY '${MYSQL_APP_PASSWORD}';

ALTER USER '${MYSQL_APP_USER}'@'%'
IDENTIFIED BY '${MYSQL_APP_PASSWORD}';

GRANT ALL ON ${MYSQL_DATABASE}.* TO '${MYSQL_APP_USER}'@'%';

FLUSH PRIVILEGES;
" \
    &>> "$LOGFILE"

VALIDATE $? "Creating Shipping database user"

# ============================================================
# 14. Verify Shipping database user
# ============================================================

DB_USER_PLUGIN=$(
    mysql \
        -h "$MYSQL_HOST" \
        -u"$MYSQL_ROOT_USER" \
        -p"$MYSQL_ROOT_PASSWORD" \
        -Nse "
SELECT plugin
FROM mysql.user
WHERE user='${MYSQL_APP_USER}'
AND host='%';
" \
        2>> "$LOGFILE"
)

echo "Shipping authentication plugin: ${DB_USER_PLUGIN}" \
    | tee -a "$LOGFILE"

if [ "$DB_USER_PLUGIN" !=]()