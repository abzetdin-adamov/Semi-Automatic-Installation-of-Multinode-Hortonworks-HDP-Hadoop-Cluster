#!/bin/bash
cat /root/hostNames | while read HOSTNAME
do
sshpass -f /root/passw.txt ssh -T root@${HOSTNAME} << EOF
echo "==========================${HOSTNAME} -- Set Hostname"
hostnamectl set-hostname ${HOSTNAME}
hostname
EOF
done
