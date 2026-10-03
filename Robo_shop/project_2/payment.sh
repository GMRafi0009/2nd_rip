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

PAYMENT_SERVICE="payment"
PAYMENT_DIR="/app"

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

if [ "$ID" -ne 0 ]
then
    echo -e "${R}ERROR :: Please run this script with root access${N}"
    exit 1
else
    echo "You are root user"
fi

if ! command -v dnf &>> "$LOGFILE"
then
    echo -e "${R}ERROR :: dnf command not found${N}"
    exit 1
fi

dnf install python3 python3-pip python3-devel gcc -y &>> "$LOGFILE"
VALIDATE $? "Installing Python dependencies"

python3 --version &>> "$LOGFILE"
VALIDATE $? "Checking Python installation"

pip3 --version &>> "$LOGFILE"
VALIDATE $? "Checking pip installation"

if id roboshop &>> "$LOGFILE"
then
    echo -e "roboshop user already exists ${Y}SKIPPING${N}"
else
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"
fi

mkdir -p "$PAYMENT_DIR" &>> "$LOGFILE"
VALIDATE $? "Creating application directory"

curl -fL -o /tmp/payment.zip \
    https://roboshop-builds.s3.amazonaws.com/payment.zip \
    &>> "$LOGFILE"
VALIDATE $? "Downloading Payment application"

cd "$PAYMENT_DIR"
VALIDATE $? "Changing to application directory"

unzip -o /tmp/payment.zip &>> "$LOGFILE"
VALIDATE $? "Unzipping Payment application"

pip3 install -r requirements.txt &>> "$LOGFILE"
VALIDATE $? "Installing Python application dependencies"

if [ ! -f "$PAYMENT_DIR/payment.ini" ]
then
    echo -e "${R}ERROR :: /app/payment.ini not found${N}"
    exit 1
fi

chown -R roboshop:roboshop "$PAYMENT_DIR" &>> "$LOGFILE"
VALIDATE $? "Setting application ownership"

cp /home/ec2-user/2nd_rip/Robo_shop/Project/payment.service \
    /etc/systemd/system/payment.service \
    &>> "$LOGFILE"
VALIDATE $? "Copying Payment service file"

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

systemctl enable "$PAYMENT_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Enabling Payment service"

systemctl restart "$PAYMENT_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Starting Payment service"

systemctl is-active --quiet "$PAYMENT_SERVICE"
VALIDATE $? "Checking Payment service health"

echo -e "${G}Payment service setup completed successfully${N}"