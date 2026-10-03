#!/bin/bash

set -Eeuo pipefail

ID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

SCRIPT_NAME=$(basename "$0")
TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

NODEJS_STREAM="18"
REDIS_HOST="redis.3gb.online"
CATALOGUE_HOST="catalogue.3gb.online"
CATALOGUE_PORT="8080"

echo "Script started executing at $TIMESTAMP" &>> "$LOGFILE"

VALIDATE() {
    if [ "$1" -ne 0 ]
    then
        echo -e "$2 ... ${R}FAILED${N}"
        exit 1
    else
        echo -e "$2 ... ${G}SUCCESS${N}"
    fi
}

# Root validation
if [ "$ID" -ne 0 ]
then
    echo -e "${R}ERROR :: Please run this script with root access${N}"
    exit 1
else
    echo "You are root user"
fi

# Disable existing NodeJS module stream
dnf module disable nodejs -y &>> "$LOGFILE"
VALIDATE $? "Disabling existing NodeJS module stream"

# Enable NodeJS 18
dnf module enable "nodejs:${NODEJS_STREAM}" -y &>> "$LOGFILE"
VALIDATE $? "Enabling NodeJS ${NODEJS_STREAM}"

# Install NodeJS
dnf install nodejs -y &>> "$LOGFILE"
VALIDATE $? "Installing NodeJS ${NODEJS_STREAM}"

# Verify NodeJS
node --version &>> "$LOGFILE"
VALIDATE $? "Checking NodeJS installation"

npm --version &>> "$LOGFILE"
VALIDATE $? "Checking npm installation"

# Create application user if it does not exist
if id roboshop &>> "$LOGFILE"
then
    echo -e "roboshop user already exists ${Y}SKIPPING${N}"
else
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"
fi

# Create application directory
mkdir -p /app &>> "$LOGFILE"
VALIDATE $? "Creating application directory"

# Download Cart application
curl -fL -o /tmp/cart.zip \
    https://roboshop-builds.s3.amazonaws.com/cart.zip \
    &>> "$LOGFILE"

VALIDATE $? "Downloading Cart application"

# Move to application directory
cd /app
VALIDATE $? "Changing to /app"

# Extract application
unzip -o /tmp/cart.zip &>> "$LOGFILE"
VALIDATE $? "Unzipping Cart application"

# Install application dependencies
npm install &>> "$LOGFILE"
VALIDATE $? "Installing application dependencies"

# Install systemd service
cp /home/ec2-user/2nd_rip/Robo_shop/Project/cart.service \
    /etc/systemd/system/cart.service \
    &>> "$LOGFILE"

VALIDATE $? "Copying Cart service file"

# Reload systemd
systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

# Enable Cart service
systemctl enable cart &>> "$LOGFILE"
VALIDATE $? "Enabling Cart service"

# Start Cart service
systemctl start cart &>> "$LOGFILE"
VALIDATE $? "Starting Cart service"

# Verify Cart service
systemctl is-active --quiet cart
VALIDATE $? "Checking Cart service health"

echo -e "${G}Cart service setup completed successfully${N}"