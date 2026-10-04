# --------------------------------------------------
# Copy systemd service
# --------------------------------------------------

cp \
    /home/ec2-user/2nd_rip/Robo_shop/project_2/shipping.service \
    /etc/systemd/system/shipping.service \
    &>> "$LOGFILE"

VALIDATE $? "Copying Shipping systemd service"

# --------------------------------------------------
# Reload systemd
# --------------------------------------------------

systemctl daemon-reload &>> "$LOGFILE"
VALIDATE $? "Reloading systemd"

# --------------------------------------------------
# Enable Shipping
# --------------------------------------------------

systemctl enable shipping &>> "$LOGFILE"
VALIDATE $? "Enabling Shipping service"

# --------------------------------------------------
# Start Shipping
# --------------------------------------------------

systemctl restart shipping &>> "$LOGFILE"

sleep 10

if systemctl is-active --quiet shipping; then
    echo -e "Shipping service ... $G ACTIVE $N"
else
    echo -e "$R ERROR :: Shipping service failed to start $N"
    journalctl -u shipping -n 100 --no-pager
    exit 1
fi

# --------------------------------------------------
# Verify port
# --------------------------------------------------

if ss -lnt | grep -q ':8080 '; then
    echo -e "Shipping port 8080 ... $G LISTENING $N"
else
    echo -e "$R ERROR :: Shipping is not listening on port 8080 $N"
    journalctl -u shipping -n 100 --no-pager
    exit 1
fi

# --------------------------------------------------
# Verify API
# --------------------------------------------------

curl -fsS http://localhost:8080/api/shipping/codes \
    &>> "$LOGFILE"

VALIDATE $? "Checking Shipping country codes API"