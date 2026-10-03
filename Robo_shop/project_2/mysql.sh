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

MYSQL_SERVICE="mysqld"
MYSQL_REPO_RPM="https://dev.mysql.com/get/mysql84-community-release-el9-4.noarch.rpm"

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

dnf install "$MYSQL_REPO_RPM" -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL 8.4 repository"

dnf repolist all | grep -q "mysql84-community"
VALIDATE $? "Checking MySQL 8.4 repository"

dnf config-manager --set-enabled mysql84-community &>> "$LOGFILE"
VALIDATE $? "Enabling MySQL 8.4 repository"

dnf makecache &>> "$LOGFILE"
VALIDATE $? "Refreshing DNF metadata"

dnf install mysql-community-server -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL Community Server"

mysqld --version &>> "$LOGFILE"
VALIDATE $? "Checking MySQL installation"

systemctl enable "$MYSQL_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Enabling MySQL Server"

systemctl start "$MYSQL_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Starting MySQL Server"

systemctl is-active --quiet "$MYSQL_SERVICE"
VALIDATE $? "Checking MySQL Server health"

if grep -q "temporary password" /var/log/mysqld.log
then
    echo -e "${G}MySQL temporary password generated successfully${N}"
else
    echo -e "${R}ERROR :: MySQL temporary password not found${N}"
    exit 1
fi

TEMP_PASSWORD=$(grep "temporary password" /var/log/mysqld.log | tail -1 | awk '{print $NF}')

if [ -z "$TEMP_PASSWORD" ]
then
    echo -e "${R}ERROR :: MySQL temporary password is empty${N}"
    exit 1
fi

echo -e "${G}MySQL temporary password found${N}"

echo
echo -e "${Y}IMPORTANT:${N}"
echo "Change the temporary MySQL root password before using the database."
echo
echo "Run:"
echo "mysql --connect-expired-password -uroot -p"
echo
echo "Then:"
echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '<STRONG_PASSWORD>';"
echo

echo -e "${G}MySQL 8.4 installation completed successfully${N}"