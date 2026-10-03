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

MONGODB_HOST="mongodb.3gb.online"
NODEJS_STREAM="18"
USER_SERVICE="user"

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

dnf module disable nodejs -y &>> "$LOGFILE"
VALIDATE $? "Disabling existing NodeJS module stream"

dnf module enable "nodejs:${NODEJS_STREAM}" -y &>> "$LOGFILE"
VALIDATE $? "Enabling NodeJS ${NODEJS_STREAM}"

dnf install nodejs -y &>> "$LOGFILE"
VALIDATE $? "Installing NodeJS ${NODEJS_STREAM}"

node --version &>> "$LOGFILE"
VALIDATE $? "Checking NodeJS installation"

npm --version &>> "$LOGFILE"
VALIDATE $? "Checking npm installation"

if id roboshop &>> "$LOGFILE"
then
    echo -e "roboshop user already exists ${Y}SKIPPING${N}"
else
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"
fi

mkdir -p /app &>> "$LOGFILE"
VALIDATE $? "Creating application directory"

curl -fL -o /tmp/user.zip \
    https://roboshop-builds.s3.amazonaws.com/user.zip \
    &>> "$LOGFILE"
VALIDATE $? "Downloading User application"

cd /app
VALIDATE $? "Changing to /app"

unzip -o /tmp/user.zip &>> "$LOGFILE"
VALIDATE $? "Unzipping User application"

npm install &>> "$LOGFILE"
VALIDATE $? "Installing application dependencies"

chown -R roboshop:roboshop /app &>> "$LOGFILE"
VALIDATE $? "Setting application ownership"

cp /home/ec2-user/2nd_rip/Robo_shop/Project/user.service \
    /etc/systemd/system/user.service \
    &>> "$LOGFILE"
VALIDATE $? "Copying User service file"

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

systemctl enable "$USER_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Enabling User service"

systemctl restart "$USER_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Starting User service"

systemctl is-active --quiet "$USER_SERVICE"
VALIDATE $? "Checking User service health"

cp /home/ec2-user/2nd_rip/Robo_shop/Project/mongo.repo \
    /etc/yum.repos.d/mongodb-org-8.0.repo \
    &>> "$LOGFILE"
VALIDATE $? "Copying MongoDB repository"

dnf install mongodb-mongosh -y &>> "$LOGFILE"
VALIDATE $? "Installing MongoDB Shell"

mongosh --host "$MONGODB_HOST" \
    --file /app/schema/user.js \
    &>> "$LOGFILE"
VALIDATE $? "Loading User data into MongoDB"

systemctl restart "$USER_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Restarting User service"

systemctl is-active --quiet "$USER_SERVICE"
VALIDATE $? "Final User service health check"

echo -e "${G}User service setup completed successfully${N}"