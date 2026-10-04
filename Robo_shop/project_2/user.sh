#!/bin/bash

set -Eeuo pipefail

ID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

readonly mongodb_host="mongodb.3gb.online"

TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/$(basename "$0")-$TIMESTAMP.log"

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

# Root user validation
if [ "$ID" -ne 0 ]
then
    echo -e "$R ERROR :: Please run this script with root access $N"
    exit 1
else
    echo "You are root user"
fi


# ----------------------------------------------------------
# Install NodeJS 18
# ----------------------------------------------------------

dnf module disable nodejs -y &>> "$LOGFILE"
VALIDATE $? "Disabling current NodeJS"

dnf module enable nodejs:18 -y &>> "$LOGFILE"
VALIDATE $? "Enabling NodeJS 18"

dnf install nodejs -y &>> "$LOGFILE"
VALIDATE $? "Installing NodeJS 18"

node --version &>> "$LOGFILE"
VALIDATE $? "Checking NodeJS version"

npm --version &>> "$LOGFILE"
VALIDATE $? "Checking npm version"


# ----------------------------------------------------------
# Create roboshop user
# ----------------------------------------------------------

if id roboshop &>> "$LOGFILE"
then
    echo -e "roboshop user already exists $Y SKIPPING $N"
else
    useradd roboshop &>> "$LOGFILE"
    VALIDATE $? "Creating roboshop user"
fi


# ----------------------------------------------------------
# Create application directory
# ----------------------------------------------------------

mkdir -p /app &>> "$LOGFILE"
VALIDATE $? "Creating app directory"


# ----------------------------------------------------------
# Download User application
# ----------------------------------------------------------

curl -L -o /tmp/user.zip \
    https://roboshop-builds.s3.amazonaws.com/user.zip \
    &>> "$LOGFILE"

VALIDATE $? "Downloading the user application"


# ----------------------------------------------------------
# Extract application
# ----------------------------------------------------------

cd /app
VALIDATE $? "Changing to /app"

unzip -o /tmp/user.zip &>> "$LOGFILE"
VALIDATE $? "Unzipping application files"


# ----------------------------------------------------------
# Install application dependencies
# ----------------------------------------------------------

npm install &>> "$LOGFILE"
VALIDATE $? "Installing application dependencies"


# ----------------------------------------------------------
# Install User systemd service
# ----------------------------------------------------------

if [ ! -f /home/ec2-user/2nd_rip/Robo_shop/Project/user.service ]
then
    echo -e "$R ERROR :: user.service file not found $N"
    exit 1
fi

cp /home/ec2-user/2nd_rip/Robo_shop/Project/user.service \
   /etc/systemd/system/user.service \
   &>> "$LOGFILE"

VALIDATE $? "Copying user service file"


# ----------------------------------------------------------
# Reload systemd
# ----------------------------------------------------------

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"


# ----------------------------------------------------------
# Enable User service
# ----------------------------------------------------------

systemctl enable user &>> "$LOGFILE"
VALIDATE $? "Enabling user service"


# ----------------------------------------------------------
# Start User service
# ----------------------------------------------------------

systemctl start user &>> "$LOGFILE"
VALIDATE $? "Starting user service"


# ----------------------------------------------------------
# Configure MongoDB repository
# ----------------------------------------------------------

if [ ! -f /home/ec2-user/2nd_rip/Robo_shop/Project/mongo.repo ]
then
    echo -e "$R ERROR :: mongo.repo file not found $N"
    exit 1
fi

cp /home/ec2-user/2nd_rip/Robo_shop/Project/mongo.repo \
   /etc/yum.repos.d/mongo.repo \
   &>> "$LOGFILE"

VALIDATE $? "Copying MongoDB repository"


# ----------------------------------------------------------
# Install MongoDB client
# ----------------------------------------------------------

dnf install mongodb-mongosh -y &>> "$LOGFILE"
VALIDATE $? "Installing MongoDB client"


# ----------------------------------------------------------
# Load User schema into MongoDB
# ----------------------------------------------------------

if [ ! -f /app/schema/user.js ]
then
    echo -e "$R ERROR :: /app/schema/user.js not found $N"
    exit 1
fi

mongosh --host "$mongodb_host" \
    --file /app/schema/user.js \
    &>> "$LOGFILE"

VALIDATE $? "Loading user data into MongoDB"


echo -e "$G User component setup completed successfully $N"
echo "Log file: $LOGFILE"