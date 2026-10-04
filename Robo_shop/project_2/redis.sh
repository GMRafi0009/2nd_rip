#!/bin/bash

set -Eeuo pipefail

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


dnf module enable redis:7 -y &>> $LOGFILE

VALIDATE $? "Enable Redis 7"

dnf install redis -y &>> $LOGFILE

VALIDATE $? "Install Redis"

redis-server --version &>> $LOGFILE

VALIDATE $? "Check Redis version"

sed -i 's/^bind 127\.0\.0\.1.*$/bind 0.0.0.0/; s/^protected-mode yes$/protected-mode no/' /etc/redis/redis.conf &>> $LOGFILE

VALIDATE $? "allowing remot connections"

systemctl enable redis &>> $LOGFILE

VALIDATE $? "Enable Redis service"

systemctl start redis &>> $LOGFILE

VALIDATE $? "Start Redis service"