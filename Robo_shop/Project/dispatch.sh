#!/bin/bash

ID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

rabbitmq_host=rabbitmq.3gb.online

TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/$0-$TIMESTAMP.log"

echo "script started executing at $TIMESTAMP" &>> $LOGFILE

VALIDATE(){
	if [ $1 -ne 0 ]
	then
		echo -e "$2 ... $R FAILED $N"
		exit 1
	else
		echo -e "$2 ... $G SUCCESS $N"
	fi
}

if [ $ID -ne 0 ]
then
	echo -e "$R ERROR :: Please run this script with root access $N"
	exit 1
else
	echo "You are root user"
fi


dnf install golang -y &>> $LOGFILE

VALIDATE $? "Installing Golang"


id roboshop &>> $LOGFILE

if [ $? -ne 0 ]
then
	useradd roboshop
	VALIDATE $? "roboshop user creation"
else
	echo -e "roboshop user already exist $Y SKIPPING $N"
fi


mkdir -p /app &>> $LOGFILE

VALIDATE $? "creating app directory"


curl -L -o /tmp/dispatch.zip https://roboshop-builds.s3.amazonaws.com/dispatch.zip &>> $LOGFILE

VALIDATE $? "Downloading dispatch"


cd /app &>> $LOGFILE

VALIDATE $? "Changing to app directory"


unzip -o /tmp/dispatch.zip &>> $LOGFILE

VALIDATE $? "unziping the dispatch files"


go mod init dispatch &>> $LOGFILE

VALIDATE $? "Initializing Go module"


go get &>> $LOGFILE

VALIDATE $? "Downloading Go dependencies"


go build &>> $LOGFILE

VALIDATE $? "Building dispatch application"


cp /home/ec2-user/2nd_rip/Robo_shop/Project/dispatch.service /etc/systemd/system/dispatch.service &>> $LOGFILE

VALIDATE $? "Copying dispatch service"


systemctl daemon-reload &>> $LOGFILE

VALIDATE $? "daemon reload"


systemctl enable dispatch &>> $LOGFILE

VALIDATE $? "Enable dispatch"


systemctl start dispatch &>> $LOGFILE

VALIDATE $? "Start dispatch"