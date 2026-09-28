#!/bin/bash

set -Eeuo pipefail

readonly LOGFILE="/var/log/ec2-user-data.log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "=========================================="
echo "EC2 User Data Started: $(date)"
echo "=========================================="

# Install Git
dnf install -y git

# Clone GitHub repository
cd /opt
git clone -b main https://github.com/GMRafi0009/2nd_rip.git

# Go to the directory containing the script
cd /opt/2nd_rip/Robo_shop/Shell_script

# Make the existing script executable
chmod +x install-package.sh

# Run the existing script and install MySQL Server
./install-package.sh mysql-server

# Enable and start MySQL
systemctl enable --now mysqld.service

echo "MySQL installation and startup completed successfully."

echo "=========================================="
echo "EC2 User Data Completed: $(date)"
echo "=========================================="