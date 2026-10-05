#!/bin/bash

set -Eeuo pipefail

# ============================================================
# RoboShop - Shipping Service Installation
# LAB ENVIRONMENT
# ============================================================

ID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

SCRIPT_NAME=$(basename "$0")
TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

# ============================================================
# Application Configuration
# ============================================================

APP_DIR="/app"
ZIP_FILE="/tmp/shipping.zip"
DOWNLOAD_URL="https://roboshop-builds.s3.amazonaws.com/shipping.zip"

SERVICE_NAME="shipping"
SERVICE_FILE="/etc/systemd/system/shipping.service"

CART_ENDPOINT="cart.3gb.online:8080"

# ============================================================
# MySQL Configuration
# ============================================================

MYSQL_HOST="mysql.3gb.online"

MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD must be set}"

MYSQL_APP_USER="shipping"
MYSQL_APP_PASSWORD="${MYSQL_APP_PASSWORD:?MYSQL_APP_PASSWORD must be set}"

MYSQL_DATABASE="cities"

# ============================================================
# Logging
# ============================================================

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
# 1. Root Validation
# ============================================================

if [ "$ID" -ne 0 ]; then

    echo -e "${R}ERROR :: Please run this script with root access${N}"

    exit 1

fi

echo -e "You are ${G}root user${N}"

# ============================================================
# 2. Install Required Packages
# ============================================================

dnf install maven -y &>> "$LOGFILE"
VALIDATE $? "Installing Maven"

dnf install mysql -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL client"

dnf install unzip -y &>> "$LOGFILE"
VALIDATE $? "Installing unzip"

# ============================================================
# 3. Validate Required Commands
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

command -v systemctl &>> "$LOGFILE"
VALIDATE $? "Checking systemctl"

# ============================================================
# 4. Create roboshop User
# ============================================================

if id roboshop &>> "$LOGFILE"; then

    echo -e \
        "roboshop user already exists ... ${Y}SKIPPING${N}"

else

    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"

fi

# ============================================================
# 5. Create Application Directory
# ============================================================

mkdir -p "$APP_DIR"

VALIDATE $? "Creating application directory"

# ============================================================
# 6. Download Shipping Application
# ============================================================

curl -fL \
    -o "$ZIP_FILE" \
    "$DOWNLOAD_URL" \
    &>> "$LOGFILE"

VALIDATE $? "Downloading Shipping application"

# ============================================================
# 7. Extract Shipping Application
# ============================================================

unzip -o \
    "$ZIP_FILE" \
    -d "$APP_DIR" \
    &>> "$LOGFILE"

VALIDATE $? "Extracting Shipping application"

# ============================================================
# 8. Build Shipping Application
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

    echo -e \
        "${R}ERROR :: target/shipping-1.0.jar not found${N}"

    exit 1

fi

# ============================================================
# 10. Check Remote MySQL Connectivity
# ============================================================

mysql \
    -h "$MYSQL_HOST" \
    -u"$MYSQL_ROOT_USER" \
    -p"$MYSQL_ROOT_PASSWORD" \
    -e "SELECT VERSION();" \
    &>> "$LOGFILE"

VALIDATE $? "Checking MySQL connectivity"

# ============================================================
# 11. Check Existing City Data
#
# schema.sql contains:
#
# DROP TABLE IF EXISTS cities;
#
# Therefore we must NOT blindly execute schema.sql.
# ============================================================

CITY_COUNT=0

if mysql \
    -h "$MYSQL_HOST" \
    -u"$MYSQL_ROOT_USER" \
    -p"$MYSQL_ROOT_PASSWORD" \
    -Nse \
    "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.cities;" \
    &>> "$LOGFILE"
then

    CITY_COUNT=$(
        mysql \
            -h "$MYSQL_HOST" \
            -u"$MYSQL_ROOT_USER" \
            -p"$MYSQL_ROOT_PASSWORD" \
            -Nse \
            "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.cities;" \
            2>> "$LOGFILE"
    )

fi

echo "Existing city count: ${CITY_COUNT}" \
    | tee -a "$LOGFILE"

# ============================================================
# 12. Initialize Database
# ============================================================

if [ "$CITY_COUNT" -gt 0 ]; then

    echo -e \
        "City data already exists ... ${G}SKIPPING database initialization${N}"

else

    echo -e \
        "${Y}City data not found. Initializing database...${N}"

    # --------------------------------------------------------
    # Verify schema file
    # --------------------------------------------------------

    if [ ! -f "$APP_DIR/db/schema.sql" ]; then

        echo -e \
            "${R}ERROR :: $APP_DIR/db/schema.sql not found${N}"

        exit 1

    fi

    # --------------------------------------------------------
    # Load schema
    # --------------------------------------------------------

    mysql \
        -h "$MYSQL_HOST" \
        -u"$MYSQL_ROOT_USER" \
        -p"$MYSQL_ROOT_PASSWORD" \
        < "$APP_DIR/db/schema.sql" \
        &>> "$LOGFILE"

    VALIDATE $? "Loading Shipping database schema"

    # --------------------------------------------------------
    # Verify master-data file
    # --------------------------------------------------------

    if [ ! -f "$APP_DIR/db/master-data.sql" ]; then

        echo -e \
            "${R}ERROR :: $APP_DIR/db/master-data.sql not found${N}"

        exit 1

    fi

    # --------------------------------------------------------
    # Load city master data
    # --------------------------------------------------------

    mysql \
        -h "$MYSQL_HOST" \
        -u"$MYSQL_ROOT_USER" \
        -p"$MYSQL_ROOT_PASSWORD" \
        "$MYSQL_DATABASE" \
        < "$APP_DIR/db/master-data.sql" \
        &>> "$LOGFILE"

    VALIDATE $? "Loading Shipping city master data"

fi

# ============================================================
# 13. Verify City Data
# ============================================================

CITY_COUNT=$(
    mysql \
        -h "$MYSQL_HOST" \
        -u"$MYSQL_ROOT_USER" \
        -p"$MYSQL_ROOT_PASSWORD" \
        -Nse \
        "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.cities;" \
        2>> "$LOGFILE"
)

echo "City count after database initialization: ${CITY_COUNT}" \
    | tee -a "$LOGFILE"

if [ "$CITY_COUNT" -eq 0 ]; then

    echo -e \
        "${R}ERROR :: Shipping city data is empty${N}"

    exit 1

fi

echo -e \
    "Shipping city data validation ... ${G}SUCCESS${N}"

# ============================================================
# 14. Create Shipping Application User
#
# DO NOT use app-user.sql.
#
# It contains mysql_native_password, which is not available
# in the current MySQL 9.7 setup.
# ============================================================

mysql \
    -h "$MYSQL_HOST" \
    -u"$MYSQL_ROOT_USER" \
    -p"$MYSQL_ROOT_PASSWORD" \
    -e "
CREATE USER IF NOT EXISTS '${MYSQL_APP_USER}'@'%'
IDENTIFIED BY '${MYSQL_APP_PASSWORD}';

ALTER USER '${MYSQL_APP_USER}'@'%'
IDENTIFIED BY '${MYSQL_APP_PASSWORD}';

GRANT ALL PRIVILEGES
ON ${MYSQL_DATABASE}.*
TO '${MYSQL_APP_USER}'@'%';

FLUSH PRIVILEGES;
" \
    &>> "$LOGFILE"

VALIDATE $? "Creating Shipping database user"

# ============================================================
# 15. Verify Shipping Authentication Plugin
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

if [ -z "$DB_USER_PLUGIN" ]; then

    echo -e \
        "${R}ERROR :: Shipping database user was not found${N}"

    exit 1

fi

echo -e \
    "Shipping authentication plugin validation ... ${G}SUCCESS${N}"

# ============================================================
# 16. Test Shipping Database User
# ============================================================

mysql \
    -h "$MYSQL_HOST" \
    -u"$MYSQL_APP_USER" \
    -p"$MYSQL_APP_PASSWORD" \
    -e "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.cities;" \
    &>> "$LOGFILE"

VALIDATE $? "Testing Shipping database user"

# ============================================================
# 17. Set Application Ownership
# ============================================================

chown -R roboshop:roboshop "$APP_DIR"

VALIDATE $? "Setting application ownership"

# ============================================================
# 18. Create Systemd Service
# ============================================================

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Shipping Service
After=network.target

[Service]
User=roboshop
WorkingDirectory=/app

Environment="CART_ENDPOINT=${CART_ENDPOINT}"
Environment="DB_HOST=${MYSQL_HOST}"

Environment="SPRING_DATASOURCE_URL=jdbc:mysql://${MYSQL_HOST}:3306/${MYSQL_DATABASE}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
Environment="SPRING_DATASOURCE_USERNAME=${MYSQL_APP_USER}"
Environment="SPRING_DATASOURCE_PASSWORD=${MYSQL_APP_PASSWORD}"

ExecStart=/bin/java -jar /app/shipping.jar

SyslogIdentifier=shipping
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

VALIDATE $? "Creating Shipping systemd service"

# ============================================================
# 19. Reload Systemd
# ============================================================

systemctl daemon-reload &>> "$LOGFILE"

VALIDATE $? "Reloading systemd"

# ============================================================
# 20. Enable Shipping Service
# ============================================================

systemctl enable "$SERVICE_NAME" &>> "$LOGFILE"

VALIDATE $? "Enabling Shipping service"

# ============================================================
# 21. Start / Restart Shipping Service
# ============================================================

if systemctl is-active --quiet "$SERVICE_NAME"; then

    systemctl restart "$SERVICE_NAME" &>> "$LOGFILE"

    VALIDATE $? "Restarting Shipping service"

else

    systemctl start "$SERVICE_NAME" &>> "$LOGFILE"

    VALIDATE $? "Starting Shipping service"

fi

# ============================================================
# 22. Wait for Application
# ============================================================

sleep 5

# ============================================================
# 23. Verify Shipping Service
# ============================================================

if systemctl is-active --quiet "$SERVICE_NAME"; then

    echo -e \
        "Shipping service ... ${G}RUNNING${N}"

else

    echo -e \
        "${R}ERROR :: Shipping service is not running${N}"

    systemctl status "$SERVICE_NAME" --no-pager

    exit 1

fi

# ============================================================
# 24. Verify Port 8080
# ============================================================

if ss -lntp | grep -q ':8080'; then

    echo -e \
        "Shipping port 8080 ... ${G}LISTENING${N}"

else

    echo -e \
        "${R}ERROR :: Shipping port 8080 is not listening${N}"

    systemctl status "$SERVICE_NAME" --no-pager

    exit 1

fi

# ============================================================
# 25. Final Status
# ============================================================

echo
echo "============================================================"
echo " Shipping Installation Completed Successfully"
echo "============================================================"
echo "Application : $APP_DIR/shipping.jar"
echo "Database    : $MYSQL_DATABASE"
echo "DB Host     : $MYSQL_HOST"
echo "City Count  : $CITY_COUNT"
echo "Service     : $SERVICE_NAME"
echo "Port        : 8080"
echo "Log File    : $LOGFILE"
echo "============================================================"

systemctl status "$SERVICE_NAME" --no-pager