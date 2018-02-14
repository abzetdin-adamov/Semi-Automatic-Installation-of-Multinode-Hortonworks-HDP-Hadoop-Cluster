#!/bin/bash
cat /root/hostNames | while read HOSTNAME
do
echo "==========================${HOSTNAME} -- Share Hosts"
        sshpass -f passw.txt scp /etc/hosts/ root@${HOSTNAME}:/etc/hosts
        sshpass -f passw.txt scp /etc/ssh/ssh_known_hosts root@${HOSTNAME}:/etc/ssh/ssh_known_hosts
done
