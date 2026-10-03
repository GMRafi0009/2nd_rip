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

RABBITMQ_SERVICE="rabbitmq-server"
RABBITMQ_USER="roboshop"

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

echo "Importing RabbitMQ signing keys" &>> "$LOGFILE"

rpm --import \
    https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc \
    &>> "$LOGFILE"
VALIDATE $? "Importing RabbitMQ signing key"

rpm --import \
    https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key \
    &>> "$LOGFILE"
VALIDATE $? "Importing Erlang signing key"

rpm --import \
    https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key \
    &>> "$LOGFILE"
VALIDATE $? "Importing RabbitMQ server signing key"

cat > /etc/yum.repos.d/rabbitmq.repo <<'EOF'
[modern-erlang]
name=modern-erlang-el9
baseurl=https://yum1.rabbitmq.com/erlang/el/9/$basearch
        https://yum2.rabbitmq.com/erlang/el/9/$basearch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md

[modern-erlang-noarch]
name=modern-erlang-el9-noarch
baseurl=https://yum1.rabbitmq.com/erlang/el/9/noarch
        https://yum2.rabbitmq.com/erlang/el/9/noarch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
        https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md

[rabbitmq-el9]
name=rabbitmq-el9
baseurl=https://yum2.rabbitmq.com/rabbitmq/el/9/$basearch
        https://yum1.rabbitmq.com/rabbitmq/el/9/$basearch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
        https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md

[rabbitmq-el9-noarch]
name=rabbitmq-el9-noarch
baseurl=https://yum2.rabbitmq.com/rabbitmq/el/9/noarch
        https://yum1.rabbitmq.com/rabbitmq/el/9/noarch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
        https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md
EOF

VALIDATE $? "Configuring RabbitMQ repositories"

dnf clean all &>> "$LOGFILE"
VALIDATE $? "Cleaning DNF metadata"

dnf makecache &>> "$LOGFILE"
VALIDATE $? "Refreshing DNF metadata"

dnf install -y logrotate &>> "$LOGFILE"
VALIDATE $? "Installing logrotate"

dnf install -y erlang rabbitmq-server &>> "$LOGFILE"
VALIDATE $? "Installing Erlang and RabbitMQ"

rabbitmqctl version &>> "$LOGFILE"
VALIDATE $? "Checking RabbitMQ installation"

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

systemctl enable "$RABBITMQ_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Enabling RabbitMQ service"

systemctl start "$RABBITMQ_SERVICE" &>> "$LOGFILE"
VALIDATE $? "Starting RabbitMQ service"

systemctl is-active --quiet "$RABBITMQ_SERVICE"
VALIDATE $? "Checking RabbitMQ service health"

if rabbitmqctl list_users 2>/dev/null | \
    awk '{print $1}' | grep -qx "$RABBITMQ_USER"
then
    echo -e "${Y}${RABBITMQ_USER} RabbitMQ user already exists SKIPPING${N}"
else
    read -r -s -p "Enter password for RabbitMQ user ${RABBITMQ_USER}: " RABBITMQ_PASSWORD
    echo

    if [ -z "$RABBITMQ_PASSWORD" ]
    then
        echo -e "${R}ERROR :: RabbitMQ password cannot be empty${N}"
        exit 1
    fi

    rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASSWORD" \
        &>> "$LOGFILE"
    VALIDATE $? "Creating RabbitMQ user"

    unset RABBITMQ_PASSWORD
fi

rabbitmqctl set_permissions \
    -p / \
    "$RABBITMQ_USER" \
    ".*" \
    ".*" \
    ".*" \
    &>> "$LOGFILE"
VALIDATE $? "Setting RabbitMQ permissions"

rabbitmqctl list_users &>> "$LOGFILE"
VALIDATE $? "Validating RabbitMQ users"

echo -e "${G}RabbitMQ setup completed successfully${N}"