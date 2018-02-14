#!/bin/bash
cat /root/hostNames | while read HOSTNAME
do
echo "==========================${HOSTNAME} -- Set PasswordLess"
        sshpass -f passw.txt ssh-copy-id root@${HOSTNAME}
        hostname
done
