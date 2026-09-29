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

dnf install maven -y

id roboshop #if roboshop user does not exist, then it is failure
if [ $? -ne 0 ]
then
	useradd roboshop
	VALIDATE $? "roboshop user creation"
else
echo -e "roboshop user already exist $Y SKIPPING $N"

fi 

mkdir -p /app

VALIDATE $? "creating app directory"

curl -L -o /tmp/shipping.zip https://roboshop-builds.s3.amazonaws.com/shipping.zip &>> $LOGFILE

VALIDATE $? "downloding application zip files"

cd /app

unzip -o /tmp/shipping.zip &>> $LOGFILE

VALIDATE $? "unziping the application files"

mvn clean package &>> $LOGFILE

VALIDATE $? "installing application dependences"

mv target/shipping-1.0.jar shipping.jar &>> $LOGFILE

VALIDATE $? "renaming the jar files"

cp /home/ec2-user/2nd_rip/Robo_shop/Project/shipping.service /etc/systemd/system/shipping.service &>> $LOGFILE

VALIDATE $? "copying application files"

systemctl daemon-reload &>> $LOGFILE

VALIDATE $? "doing daemon-reload"

systemctl enable shipping &>> $LOGFILE

VALIDATE $? "enabling shipping"

systemctl start shipping &>> $LOGFILE

VALIDATE $? "starting shipping"

dnf install mysql -y &>> $LOGFILE

VALIDATE $? "installing mysql client"

mysql -h mysql.3gb.online -uroot -pRoboShop@1 </app/schema/shipping.sql &>> $LOGFILE

VALIDATE $? "loading shipping data"

systemctl restart shipping &>> $LOGFILE

VALIDATE $? "restart shipping"