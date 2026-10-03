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

curl -fL -o /tmp/catalogue.zip \
    https://roboshop-builds.s3.amazonaws.com/catalogue.zip \
    &>> "$LOGFILE"
VALIDATE $? "Downloading Catalogue application"

cd /app
VALIDATE $? "Changing to /app"

unzip -o /tmp/catalogue.zip &>> "$LOGFILE"
VALIDATE $? "Unzipping Catalogue application"

npm install &>> "$LOGFILE"
VALIDATE $? "Installing application dependencies"

cp /home/ec2-user/2nd_rip/Robo_shop/Project/catalogue.service \
    /etc/systemd/system/catalogue.service \
    &>> "$LOGFILE"
VALIDATE $? "Copying Catalogue service file"

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

systemctl enable catalogue &>> "$LOGFILE"
VALIDATE $? "Enabling Catalogue service"

systemctl restart catalogue &>> "$LOGFILE"
VALIDATE $? "Starting Catalogue service"

systemctl is-active --quiet catalogue
VALIDATE $? "Checking Catalogue service health"

cp /home/ec2-user/2nd_rip/Robo_shop/Project/mongo.repo \
    /etc/yum.repos.d/mongo.repo \
    &>> "$LOGFILE"
VALIDATE $? "Copying MongoDB repository"

dnf install mongodb-mongosh -y &>> "$LOGFILE"
VALIDATE $? "Installing MongoDB client"

mongosh --host "$MONGODB_HOST" \
    --file /app/schema/catalogue.js \
    &>> "$LOGFILE"
VALIDATE $? "Loading Catalogue data into MongoDB"

systemctl restart catalogue &>> "$LOGFILE"
VALIDATE $? "Restarting Catalogue service after database initialization"

systemctl is-active --quiet catalogue
VALIDATE $? "Final Catalogue service health check"

echo -e "${G}Catalogue service setup completed successfully${N}"
