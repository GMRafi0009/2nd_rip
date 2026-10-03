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

NGINX_SERVICE="nginx"
WEB_ROOT="/usr/share/nginx/html"
WEB_PACKAGE="/tmp/web.zip"
WEB_URL="https://roboshop-builds.s3.amazonaws.com/web.zip"
NGINX_CONFIG="/etc/nginx/default.d/roboshop.conf"

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

dnf install nginx -y &>> "$LOGFILE"
VALIDATE $? "Installing Nginx"

nginx -v &>> "$LOGFILE"
VALIDATE $? "Checking Nginx installation"

systemctl enable "$NGINX_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Enabling Nginx service"

systemctl start "$NGINX_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Starting Nginx service"

systemctl is-active --quiet "$NGINX_SERVICE"
VALIDATE $? "Checking Nginx service health"

if [ ! -d "$WEB_ROOT" ]
then
    mkdir -p "$WEB_ROOT" &>> "$LOGFILE"
    VALIDATE $? "Creating Nginx web root"
fi

rm -rf "${WEB_ROOT:?}"/* &>> "$LOGFILE"
VALIDATE $? "Removing default web content"

curl -fL -o "$WEB_PACKAGE" \
    "$WEB_URL" \
    &>> "$LOGFILE"
VALIDATE $? "Downloading Web application"

unzip -o "$WEB_PACKAGE" \
    -d "$WEB_ROOT" \
    &>> "$LOGFILE"
VALIDATE $? "Extracting Web application"

if [ ! -f "$WEB_ROOT/index.html" ]
then
    echo -e "${R}ERROR :: $WEB_ROOT/index.html not found${N}"
    exit 1
fi

cp /home/ec2-user/2nd_rip/Robo_shop/Project/roboshop.conf \
    "$NGINX_CONFIG" \
    &>> "$LOGFILE"
VALIDATE $? "Copying RoboShop Nginx configuration"

nginx -t &>> "$LOGFILE"
VALIDATE $? "Validating Nginx configuration"

systemctl reload "$NGINX_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Reloading Nginx configuration"

systemctl is-active --quiet "$NGINX_SERVICE"
VALIDATE $? "Checking final Nginx service health"

curl -f http://localhost/health \
    &>> "$LOGFILE"
VALIDATE $? "Checking Nginx health endpoint"

echo -e "${G}Web service setup completed successfully${N}"