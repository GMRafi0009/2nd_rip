#!/bin/bash

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

# Install Maven
dnf install maven -y &>> "$LOGFILE"
VALIDATE $? "installing Maven"

# Create roboshop user if not exists
id roboshop &>> "$LOGFILE"

if [ $? -ne 0 ]
then
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "roboshop user creation"
else
    echo -e "roboshop user already exists ... $Y SKIPPING $N"
fi

# Create application directory
mkdir -p /app
VALIDATE $? "creating app directory"

# Download Shipping application
curl -L -o /tmp/shipping.zip \
    https://roboshop-builds.s3.amazonaws.com/shipping.zip \
    &>> "$LOGFILE"

VALIDATE $? "downloading Shipping application"

# Extract application
cd /app

unzip -o /tmp/shipping.zip &>> "$LOGFILE"
VALIDATE $? "unzipping Shipping application"

# Build application
mvn clean package &>> "$LOGFILE"
VALIDATE $? "building Shipping application"

# Rename application JAR
mv target/shipping-1.0.jar shipping.jar &>> "$LOGFILE"
VALIDATE $? "renaming Shipping JAR"

# Copy systemd service
cp /home/ec2-user/2nd_rip/Robo_shop/Project/shipping.service \
    /etc/systemd/system/shipping.service \
    &>> "$LOGFILE"

VALIDATE $? "copying Shipping service file"

# Reload systemd
systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "doing systemd daemon-reload"

# Install MySQL client
dnf install mysql -y &>> "$LOGFILE"
VALIDATE $? "installing MySQL client"

# Load cities database schema
mysql -h mysql.3gb.online \
    -uroot \
    -p'RoboShop@1' \
    < /app/db/schema.sql \
    &>> "$LOGFILE"

VALIDATE $? "loading cities database schema"

# Load cities master data
mysql -h mysql.3gb.online \
    -uroot \
    -p'RoboShop@1' \
    < /app/db/master-data.sql \
    &>> "$LOGFILE"

VALIDATE $? "loading cities master data"

# Verify cities data
CITY_COUNT=$(mysql -h mysql.3gb.online \
    -uroot \
    -p'RoboShop@1' \
    -Nse "SELECT COUNT(*) FROM cities.cities;" \
    2>> "$LOGFILE")

if [ "$CITY_COUNT" -le 0 ]
then
    echo -e "$R ERROR :: Cities master data was not loaded $N"
    exit 1
else
    echo -e "$G Cities master data loaded successfully: $CITY_COUNT rows $N"
fi

# Enable Shipping
systemctl enable shipping &>> "$LOGFILE"
VALIDATE $? "enabling Shipping"

# Start Shipping
systemctl start shipping &>> "$LOGFILE"
VALIDATE $? "starting Shipping"

echo -e "$G Shipping setup completed successfully $N"
