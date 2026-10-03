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

REDIS_SERVICE="redis"
REDIS_PORT="6379"

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

dnf module disable redis -y &>> "$LOGFILE"
VALIDATE $? "Disabling existing Redis module"

dnf module enable redis:7 -y &>> "$LOGFILE"
VALIDATE $? "Enabling Redis 7 module"

dnf install redis -y &>> "$LOGFILE"
VALIDATE $? "Installing Redis"

redis-server --version &>> "$LOGFILE"
VALIDATE $? "Checking Redis installation"

REDIS_CONFIG="/etc/redis/redis.conf"

if [ ! -f "$REDIS_CONFIG" ]
then
    echo -e "${R}ERROR :: Redis configuration file not found: $REDIS_CONFIG${N}"
    exit 1
fi

sed -i \
    's/^[[:space:]]*bind .*/bind 0.0.0.0/' \
    "$REDIS_CONFIG" \
    &>> "$LOGFILE"
VALIDATE $? "Configuring Redis network binding"

if grep -qE '^[[:space:]]*protected-mode' "$REDIS_CONFIG"
then
    sed -i \
        's/^[[:space:]]*protected-mode.*/protected-mode yes/' \
        "$REDIS_CONFIG" \
        &>> "$LOGFILE"
    VALIDATE $? "Enabling Redis protected mode"
else
    echo "protected-mode yes" >> "$REDIS_CONFIG"
    VALIDATE $? "Adding Redis protected mode"
fi

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

systemctl enable "$REDIS_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Enabling Redis service"

systemctl restart "$REDIS_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Starting Redis service"

systemctl is-active --quiet "$REDIS_SERVICE"
VALIDATE $? "Checking Redis service health"

redis-cli ping &>> "$LOGFILE"
VALIDATE $? "Testing Redis connectivity"

echo -e "${G}Redis setup completed successfully${N}"