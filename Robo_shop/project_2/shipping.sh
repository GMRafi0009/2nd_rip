#!/bin/bash

set -Eeuo pipefail

ID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/shipping-$TIMESTAMP.log"

echo "Shipping script started executing at $TIMESTAMP" &>> "$LOGFILE"

VALIDATE() {
    local STATUS="$1"
    local MESSAGE="$2"

    if [ "$STATUS" -ne 0 ]; then
        echo -e "$MESSAGE ... $R FAILED $N"
        echo "Check log file: $LOGFILE"
        exit 1
    else
        echo -e "$MESSAGE ... $G SUCCESS $N"
    fi
}

# --------------------------------------------------
# Root validation
# --------------------------------------------------

if [ "$ID" -ne 0 ]; then
    echo -e "$R ERROR :: Please run this script with root access $N"
    exit 1
else
    echo -e "$G You are root user $N"
fi

# --------------------------------------------------
# Install Maven
# --------------------------------------------------

dnf install maven -y &>> "$LOGFILE"
VALIDATE $? "Installing Maven"

# --------------------------------------------------
# Create roboshop user
# --------------------------------------------------

if id roboshop &>> "$LOGFILE"; then
    echo -e "roboshop user already exists $Y SKIPPING $N"
else
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"
fi

# --------------------------------------------------
# Create application directory
# --------------------------------------------------

mkdir -p /app
VALIDATE $? "Creating /app directory"

# --------------------------------------------------
# Download Shipping application
# --------------------------------------------------

curl -fL -o /tmp/shipping.zip \
    https://roboshop-builds.s3.amazonaws.com/shipping.zip \
    &>> "$LOGFILE"

VALIDATE $? "Downloading Shipping application"

# --------------------------------------------------
# Extract application
# --------------------------------------------------

cd /app

unzip -o /tmp/shipping.zip &>> "$LOGFILE"
VALIDATE $? "Extracting Shipping application"

# --------------------------------------------------
# Build application
# --------------------------------------------------

mvn clean package &>> "$LOGFILE"
VALIDATE $? "Building Shipping application"

# --------------------------------------------------
# Rename JAR
# --------------------------------------------------

mv target/shipping-1.0.jar shipping.jar &>> "$LOGFILE"
VALIDATE $? "Creating shipping.jar"

# --------------------------------------------------
# Install MySQL client BEFORE database initialization
# --------------------------------------------------

dnf install mysql -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL client"

# --------------------------------------------------
# Verify MySQL connectivity
# --------------------------------------------------

mysql \
    -h mysql.3gb.online \
    -uroot \
    -p'RoboShop@1' \
    -e "SELECT 1;" \
    &>> "$LOGFILE"

VALIDATE $? "Checking MySQL connectivity"

# --------------------------------------------------
# Load Shipping database schema/data
# --------------------------------------------------

if [ ! -f /app/db/schema.sql ]; then
    echo -e "$R ERROR :: /app/db/schema.sql not found $N"
    exit 1
fi

mysql \
    -h mysql.3gb.online \
    -uroot \
    -p'RoboShop@1' \
    < /app/db/schema.sql \
    &>> "$LOGFILE"

VALIDATE $? "Loading Shipping database schema/data"

# --------------------------------------------------
# Verify Shipping database
# --------------------------------------------------

mysql \
    -h mysql.3gb.online \
    -uroot \
    -p'RoboShop@1' \
    -e "SHOW DATABASES;" \
    &>> "$LOGFILE"

VALIDATE $? "Verifying Shipping database"

# --------------------------------------------------
# Copy systemd service
# --------------------------------------------------

cp /home/ec2-user/2nd_rip/Robo_shop/Project/shipping.service \
    /etc/systemd/system/shipping.service \
    &>> "$LOGFILE"

VALIDATE $? "Copying Shipping systemd service"

# --------------------------------------------------
# Reload systemd
# --------------------------------------------------

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

# --------------------------------------------------
# Enable Shipping
# --------------------------------------------------

systemctl enable shipping &>> "$LOGFILE"
VALIDATE $? "Enabling Shipping service"

# --------------------------------------------------
# Start Shipping
# --------------------------------------------------

systemctl start shipping &>> "$LOGFILE"
VALIDATE $? "Starting Shipping service"

# --------------------------------------------------
# Verify Shipping service
# --------------------------------------------------

sleep 5

if systemctl is-active --quiet shipping; then
    echo -e "Shipping service ... $G ACTIVE $N"
else
    echo -e "$R ERROR :: Shipping service is not active $N"
    journalctl -u shipping -n 50 --no-pager
    exit 1
fi

# --------------------------------------------------
# Verify Shipping API
#
# Change 8080 if shipping.service uses another port.
# --------------------------------------------------

SHIPPING_PORT=8080

if curl -fsS \
    "http://localhost:${SHIPPING_PORT}/api/shipping/codes" \
    &>> "$LOGFILE"; then

    echo -e "Shipping /api/shipping/codes ... $G SUCCESS $N"

else

    echo -e "$R ERROR :: /api/shipping/codes is not responding successfully $N"
    echo
    echo "Recent Shipping logs:"
    journalctl -u shipping -n 50 --no-pager
    echo
    echo "Full log: $LOGFILE"
    exit 1

fi

echo
echo -e "$G ============================================== $N"
echo -e "$G Shipping deployment completed successfully $N"
echo -e "$G Log file: $LOGFILE $N"
echo -e "$G ============================================== $N"