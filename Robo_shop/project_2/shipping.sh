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

SHIPPING_SERVICE="shipping"
SHIPPING_DIR="/app"
MYSQL_HOST="mysql.3gb.online"
MYSQL_SCHEMA="/app/db/schema.sql"

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

dnf install maven -y &>> "$LOGFILE"
VALIDATE $? "Installing Maven"

mvn --version &>> "$LOGFILE"
VALIDATE $? "Checking Maven installation"

java -version &>> "$LOGFILE"
VALIDATE $? "Checking Java installation"

if id roboshop &>> "$LOGFILE"
then
    echo -e "roboshop user already exists ${Y}SKIPPING${N}"
else
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"
fi

mkdir -p "$SHIPPING_DIR" &>> "$LOGFILE"
VALIDATE $? "Creating application directory"

curl -fL -o /tmp/shipping.zip \
    https://roboshop-builds.s3.amazonaws.com/shipping.zip \
    &>> "$LOGFILE"
VALIDATE $? "Downloading Shipping application"

cd "$SHIPPING_DIR"
VALIDATE $? "Changing to application directory"

unzip -o /tmp/shipping.zip &>> "$LOGFILE"
VALIDATE $? "Unzipping Shipping application"

mvn clean package &>> "$LOGFILE"
VALIDATE $? "Building Shipping application"

if [ ! -f target/shipping-1.0.jar ]
then
    echo -e "${R}ERROR :: target/shipping-1.0.jar was not created${N}"
    exit 1
fi

mv -f target/shipping-1.0.jar "$SHIPPING_DIR/shipping.jar" &>> "$LOGFILE"
VALIDATE $? "Creating shipping.jar"

chown -R roboshop:roboshop "$SHIPPING_DIR" &>> "$LOGFILE"
VALIDATE $? "Setting application ownership"

if [ ! -f "$MYSQL_SCHEMA" ]
then
    echo -e "${R}ERROR :: MySQL schema file not found: $MYSQL_SCHEMA${N}"
    exit 1
fi

cp /home/ec2-user/2nd_rip/Robo_shop/Project/shipping.service \
    /etc/systemd/system/shipping.service \
    &>> "$LOGFILE"
VALIDATE $? "Copying Shipping service file"

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $