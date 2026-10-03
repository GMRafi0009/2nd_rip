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

RABBITMQ_HOST="rabbitmq.3gb.online"

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

dnf install golang -y &>> "$LOGFILE"
VALIDATE $? "Installing Golang"

go version &>> "$LOGFILE"
VALIDATE $? "Checking Golang installation"

if id roboshop &>> "$LOGFILE"
then
    echo -e "roboshop user already exists ${Y}SKIPPING${N}"
else
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"
fi

mkdir -p /app &>> "$LOGFILE"
VALIDATE $? "Creating application directory"

curl -fL -o /tmp/dispatch.zip \
    https://roboshop-builds.s3.amazonaws.com/dispatch.zip \
    &>> "$LOGFILE"
VALIDATE $? "Downloading Dispatch application"

cd /app
VALIDATE $? "Changing to /app"

unzip -o /tmp/dispatch.zip &>> "$LOGFILE"
VALIDATE $? "Unzipping Dispatch application"

if [ -f /app/go.mod ]
then
    echo -e "Go module already initialized ${Y}SKIPPING${N}"
else
    go mod init dispatch &>> "$LOGFILE"
    VALIDATE $? "Initializing Go module"
fi

go mod tidy &>> "$LOGFILE"
VALIDATE $? "Downloading Go dependencies"

go build -o /app/dispatch &>> "$LOGFILE"
VALIDATE $? "Building Dispatch application"

chown -R roboshop:roboshop /app &>> "$LOGFILE"
VALIDATE $? "Setting application ownership"

cp /home/ec2-user/2nd_rip/Robo_shop/Project/dispatch.service \
    /etc/systemd/system/dispatch.service \
    &>> "$LOGFILE"
VALIDATE $? "Copying Dispatch service file"

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

systemctl enable dispatch &>> "$LOGFILE"
VALIDATE $? "Enabling Dispatch service"

systemctl restart dispatch &>> "$LOGFILE"
VALIDATE $? "Starting Dispatch service"

systemctl is-active --quiet dispatch
VALIDATE $? "Checking Dispatch service health"

echo -e "${G}Dispatch service setup completed successfully${N}"