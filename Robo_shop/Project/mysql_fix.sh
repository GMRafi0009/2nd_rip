#!/bin/bash

set -Eeuo pipefail

ID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(basename "$0")
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

echo "Script started executing at $TIMESTAMP" &>> "$LOGFILE"

VALIDATE() {
    if [ "$1" -ne 0 ]
    then
        echo -e "$2 ... $R FAILED $N"
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N"
    fi
}

# Root validation
if [ "$ID" -ne 0 ]
then
    echo -e "$R ERROR :: Please run this script with root access $N"
    exit 1
else
    echo "You are root user"
fi

# Install MySQL repository
dnf install https://dev.mysql.com/get/mysql84-community-release-el9-4.noarch.rpm -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL repository"

# Install MySQL server
dnf install mysql-community-server -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL Server"

# Enable MySQL
systemctl enable mysqld &>> "$LOGFILE"
VALIDATE $? "Enabling MySQL Server"

# Start MySQL
systemctl start mysqld &>> "$LOGFILE"
VALIDATE $? "Starting MySQL Server"

# Check MySQL service
systemctl is-active --quiet mysqld
VALIDATE $? "Checking MySQL Server status"

# Get temporary root password
TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | tail -1 | awk '{print $NF}')

if [ -z "$TEMP_PASSWORD" ]
then
    echo -e "$R ERROR :: Temporary MySQL root password not found $N"
    exit 1
fi

echo -e "$G Temporary MySQL password found $N"

# Change root password
mysql --connect-expired-password \
    -uroot \
    -p"$TEMP_PASSWORD" \
    -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'RoboShop@1';" \
    &>> "$LOGFILE"

VALIDATE $? "Setting MySQL root password"

# Create remote root user for LAB
mysql -uroot -p'RoboShop@1' \
    -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'RoboShop@1';" \
    &>> "$LOGFILE"

VALIDATE $? "Creating remote root user"

# Grant privileges to remote root user
mysql -uroot -p'RoboShop@1' \
    -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;" \
    &>> "$LOGFILE"

VALIDATE $? "Granting remote root privileges"

# Reload privileges
mysql -uroot -p'RoboShop@1' \
    -e "FLUSH PRIVILEGES;" \
    &>> "$LOGFILE"

VALIDATE $? "Reloading MySQL privileges"

# Verify users
mysql -uroot -p'RoboShop@1' \
    -e "SELECT user, host, plugin FROM mysql.user;" \
    &>> "$LOGFILE"

VALIDATE $? "Validating MySQL users"

echo -e "$G MySQL setup completed successfully $N"