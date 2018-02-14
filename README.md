# Semi-Automatic Installation of Multinode Hortonworks HDP Hadoop Cluster

In this tutorial you will be guided щт how to install Multinode Hortonworks HDP Hadoop Cluster in easy way. We will use shell scripts to implement some repeatable commands on remote hosts.  
We assume that there are 5 computers (or virtual machines): 1 of them will serve as master node (NameNode), 4 others as slaves (DataNode). We also assume that root password is same in all 5 nodes. 
The difference of this tutorial is this: same guidelines can be used to install Hadoop cluster on any number of nodes (from several to hundreds) without significant affecting time and efforts. 

**Preparing Environment for Installation**

Installation will be accomplished on master node (in my case `namenode.hadoop.ada).
```
yum -y update && yum -y upgrade
```
following command to enable EPEL repo on CentOS/RHEL server: 
```
yum install epel-release
```
To partially automate some of installation steps we need the capability to run commands on remote machines through SSH logining. We can easily achieve this using sshpass utility.
```
yum install pssh
yum install python-pip
```
We will install Hadoop cluster using root user.
```
su root
```
root password is written into file located in root's home directory to avoid entering the password each time:
```
echo "pawword" >> ./passw.txt
chmod 600 passw.txt
```
We add the list of all nodes and their FQDNs to `/etc/hosts`
```
192.168.33.50 namenode.hadoop.ada
192.168.33.51 datanode01.hadoop.ada
192.168.33.52 datanode02.hadoop.ada
192.168.33.53 datanode03.hadoop.ada
192.168.33.54 datanode04.hadoop.ada
```
Additionally write all hostnames into file `/root/hostNames` that in shell scripts
```
namenode.hadoop.ada
datanode01.hadoop.ada
datanode02.hadoop.ada
datanode03.hadoop.ada
datanode04.hadoop.ada
```

**1. To change hostnames of all remote nodes, the shell script will be used**

Create new file with extension .sh and type following bash code
```
vi ~/shellscript.sh
```
```
#!/bin/bash
cat /root/hostNames | while read HOSTNAME
do
sshpass -f /root/passw.txt ssh -T root@${HOSTNAME} << EOF
echo "==========================${HOSTNAME}"
hostnamectl set-hostname ${HOSTNAME}
hostname
EOF
done
```
to make file runnable/executable
```
chmod +x shellscript.sh
```

**2. Copy all /etc/hosts to all remote nodes. Copy all /etc/ssh/ssh_known_hosts to all remote nodes**

To avoid being asked to approve fingerprint each time when connect to remote node the first time:
```
ssh-keyscan -H namenode.hadoop.ada >> ~/.ssh/known_hosts
ssh-keyscan -H datanode01.hadoop.ada >> ~/.ssh/known_hosts
ssh-keyscan -H datanode02.hadoop.ada >> ~/.ssh/known_hosts
ssh-keyscan -H datanode03.hadoop.ada >> ~/.ssh/known_hosts
ssh-keyscan -H datanode04.hadoop.ada >> ~/.ssh/known_hosts
```
To make known_hosts work for all users
```
cp ~/.ssh/known_hosts /etc/ssh/ssh_known_hosts
```
Now rund following bash script
```
#!/bin/bash
cat /root/hostNames | while read HOSTNAME
do
echo "==========================${HOSTNAME}"
        sshpass -f passw.txt scp /etc/hosts/ root@${HOSTNAME}:/etc/hosts
        sshpass -f passw.txt scp /etc/ssh/ssh_known_hosts root@${HOSTNAME}:/etc/ssh/ssh_known_hosts
done
```
**3. Set PasswordLess SSH authentication**

In order to install Hortonworks HDP using Ambari, we need to set passwordless SSH access from master-node (namenode) where Ambari server will be installed to all slave-nodes. 
To do so, we should generate RSA keys (private and public) using `ssh-keygen` utility using default settings for location pressing ENTER, leave empty password pressing ENTER two times.
```
ssh-keygen
```
or just use following command to do things in silent mode
```
ssh-keygen -f id_rsa -t rsa -N ""
```
Following bash code will copy public key generated for master-node to all remote nodes adding the key to the authorized_keys file on each node.
```
#!/bin/bash
cat /root/hostNames | while read HOSTNAME
do
echo "==========================${HOSTNAME}"
        sshpass -f passw.txt ssh-copy-id root@${HOSTNAME}
        hostname
done
```

**4. Update OS kernels and packages in all remote nodes and reboot them**
```
pssh --hosts hostNames -t 10000 --user root -i "yum -y update && yum -y upgrade"
pssh --hosts hostNames --user root -i "reboot"
```
**5. On all remote nodes install packages those we will need later to download distributions and extract them**
```
pssh --hosts hostNames -t 1000 --user root -i "yum -y install zip; yum -y install unzip; yum -y install wget"
```
**6. to replace DNS Servers in all remote nodes**
```
#!/bin/bash
cat /root/hostNames | while read HOSTNAME
do
sshpass -f /root/passw.txt ssh -T root@${HOSTNAME} << EOF
echo "==========================${HOSTNAME} -- Change DNS"
sed -i '/DNS1=current-IP-address/c\DNS1=8.8.8.8' /etc/sysconfig/network-scripts/ifcfg-eno49d1
sed -i '/DNS2=current-IP-address/c\DNS2=8.8.4.4' /etc/sysconfig/network-scripts/ifcfg-eno49d1
systemctl restart network
EOF
done
```
**7. Install Oracle JDK 8 to all remote nodes**
```
pssh --hosts hostNames -t 10000 --user root -i "curl -LO -H 'Cookie: oraclelicense=accept-securebackup-cookie' http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf/jdk-8u151-linux-x64.rpm; rpm -Uvh jdk-8u151-linux-x64.rpm"
 ```
**8. Change max number of open files**
use following commands to check appropriate value in your system
```
ulimit -Sn
ulimit -Hn
```
```
pssh --hosts hostNames -t 1000 --user root -i "echo -e '* soft nofile 10000\n* hard nofile 10000\nroot soft nofile 10000\nroot hard nofile 10000\n' >> /etc/security/limits.conf"
```
**9. Install Network Time Protocol (NTP) on all remote nodes and enable this service**
```
pssh --hosts hostNames -t 1000 --user root -i "yum install -y ntp; systemctl start ntpd; systemctl enable ntpd"
pssh --hosts hostNames -t 1000 --user root -i "systemctl start ntpd; systemctl enable ntpd"
``` 
**10. Install Name Service Caching Daemon (nscd) on all remote nodes and enable this service**
```
pssh --hosts hostNames -t 1000 --user root -i "yum -y install nscd; systemctl start nscd.service; systemctl enable nscd.service" 
```
**11. Configuring iptables - Disable Firewalls**
```
pssh --hosts hostNames -t 1000 --user root -i "systemctl disable firewalld; service firewalld stop"
```
**12. Disable Security-Enhanced Linux (SELinux)**
```
pssh --hosts hostNames -t 1000 --user root -i "sed -i '/SELINUX=enforcing/c\SELINUX=disabled' /etc/selinux/config; echo umask 0022 >> /etc/profile"
```
**13. Create local Repository**

You can skip this step if you will use public repository.

Just for demonstration I installed my local repository on the same master-node (IP: 192.168.33.50) where Ambari server to be installed. But on production installation, it is recommended to choose another machine.
Create local Repository for Ambary, HDP and HDP-UTILS. This is important to do speed-up the installation process. As a result instead of downloding large distributives from Internet, they will be taken from local network.
We will use `wget -b ...` to download in background and save logs in `wget-log` file
```
wget -b http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.6.0.0/ambari-2.6.0.0-centos7.tar.gz
wget -b http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.6.3.0/HDP-2.6.3.0-centos7-rpm.tar.gz
wget -b http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.21/repos/centos7/HDP-UTILS-1.1.0.21-centos7.tar.gz
```
Downlaod .repo files of Ambari and HDP
```
wget http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.6.0.0/ambari.repo
wget http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.6.3.0/hdp.repo
```
Extract .tar files using 
```
tar -xvzf ambari-2.6.0.0-centos7.tar.gz; tar -xvzf HDP-2.6.3.0-centos7-rpm.tar.gz; tar -xvzf HDP-UTILS-1.1.0.21-centos7.tar.gz;
```
You can use tar extractor with --directory key to extract archive into specify directory 
```
mkdir /var/www/html/repo/HDP-UTILS
tar -xvzf HDP-UTILS-1.1.0.21-centos7.tar.gz --directory HDP-UTILS
```
After extracting move folders to root folder of the Web-server
```
mv ambari /var/www/html/repo
mv HDP /var/www/html/repo
mv HDP-UTILS /var/www/html/repo
```
Update .repo files
```
vi ambari.repo
baseurl=http://192.168.33.50/repo/ambari/centos7/2.6.0.0-267/
gpgkey=http://192.168.33.50/repo/ambari/centos7/2.6.0.0-267/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
```
```
vi hdp.repo
baseurl=http://192.168.33.50/repo/HDP/centos7/2.6.3.0-235/
gpgkey=http://192.168.33.50/repo/HDP/centos7/2.6.3.0-235/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
...
baseurl=http://192.168.33.50/repo/HDP-UTILS/
gpgkey=http://192.168.33.50/repo/HDP-UTILS/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
```

Copy .repo files to AMBARI and HDP folders accordingly
```
cp ambari.repo /var/www/html/repo/ambari/centos7/2.6.0.0-267/
cp hdp.repo /var/www/html/repo/HDP/centos7/2.6.3.0-235/
```

**14. Put updated ambari.repo to the repository folder**
```
cp ambari.repo /etc/yum.repos.d
cd /etc/yum.repos.d
```
**15. Install the Ambari Server using local repository**
```
yum install ambari-server -y
```
**16. Setup the Ambari Server**
```
ambari-server setup
```
- accept warning regrading disabled Selinux typing "y"
- accept default root user typing "n"
- Enter 1 to download Oracle JDK 1.8. and accept Oracle licence agreement
- enter "n" at "Enter advanced database configuration" to use default database PostgreSQL (database name is ambari, user / pasword are ambari/bigdata)
- at the end of setup "Ambari Server 'setup' completed successfully."

**17. Start Ambari Server**
```
ambari-server start
```
to check the status of Ambari Server service
```
ambari-server status
```
to stopt Ambari Server
```
ambari-server stop
```
**18. Check Database logs if there any issues**
```
cat /var/log/ambari-server/ambari-server-check-database.log
```
**19. Now its time to login into Ambari Server to setup HDP**

type in your browser the domainname or IP address of machine where you have just installed Ambari Server
```
http://192.168.33.100:8080/
```
type there `admin/admin` as user/password 
follow to instructions to install Hortonworks HDP using Ambari Cluster Install Wizard

**20. DONE**
