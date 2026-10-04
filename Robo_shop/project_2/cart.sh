#!/bin/bash

ID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/$0-$TIMESTAMP.log"

echo "script stareted executing at $TIMESTAMP" &>> $LOGFILE

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
	echo -e "$R ERROR :: Please run.this script with root access $N"
	exit 1.# you.can give other.than 0
else
	echo "You are root user"
fi # fi means reverse of if, indicating condition end

dnf module disable nodejs -y

VALIDATE $? "Disabling current NodeJS" &>> $LOGFILE

dnf module enable nodejs:18 -y

VALIDATE $? "enabling nodejs:18" &>> $LOGFILE

dnf install nodejs -y

VALIDATE $? "installing nodejs:18" &>> $LOGFILE

id roboshop
if [ $? -ne 0 ]
then
	useradd roboshop
	VALIDATE $? "roboshop user creation"
else
	echo -e "roboshop user already exist $Y SKIPPING $N"
fi

mkdir -p /app

VALIDATE $? "creating app directory" &>> $LOGFILE

curl -L -o /tmp/cart.zip https://roboshop-builds.s3.amazonaws.com/cart.zip

VALIDATE $? "downloding the cart application" &>> $LOGFILE

cd /app
unzip /tmp/cart.zip

VALIDATE $? "unziping application files" &>> $LOGFILE

npm install

VALIDATE $? "installing application dependences" &>> $LOGFILE

cp /home/ec2-user/2nd_rip/Robo_shop/Project/cart.service /etc/systemd/system/cart.service

VALIDATE $? "Copying cart service file" &>> $LOGFILE

systemctl daemon-reload

VALIDATE $? "cart daemon reload" &>> $LOGFILE

systemctl enable cart &>> $LOGFILE

VALIDATE $? "Enable cart"

systemctl start cart &>> $LOGFILE

VALIDATE $? "Starting cart"

