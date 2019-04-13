#!/bin/sh -u
#
# CST8213
# Qichen Jia
# This script documents and tries to excute the CST8213 SBA tasks.
#
PATH=/bin:/usr/bin:/sbin ; export PATH          # (2) PATH line
umask 022                                    # (3) umask line
#
# Variables
testuser=cst8213
testuserpass=cst8213
#ncport1=234
#ncport2=432
testservernet=172.16.30.44
testclientnet=172.16.31.44
testaliasnet=172.16.32.44
testdomain1=snow.lab
testdomain2=snow.lab
vdomain1=white.lab
testmaildomain=bashful.lab
testmaildomain2=sleppy.lab
testhostname=jia00025-cli.$testdomain1
# LDAP
ldapdb=bdb
ldapcn=ldapadm
ldapdc1=grumpy
ldapdc2=lab
ldapdir=grumpy.lab

#
# Required Setup Section
#
yum install postfix
yum install bind

systemctl stop NetworkManager.service
systemctl disable NetworkManager.service
useradd $testuser -g wheel -p $testuserpass

hostnamectl set-hostname $testhostname
echo "`cat /etc/sysconfig/network-scripts/ifcfg-ens33 | grep UUID`" >> sbac/ifcfg-ens33
echo "`cat /etc/sysconfig/network-scripts/ifcfg-ens34 | grep UUID`" >> sbac/ifcfg-ens34

#
cp sbac/ifcfg-ens33 /etc/sysconfig/network-scripts/ifcfg-ens33 
cp sbac/ifcfg-ens34 /etc/sysconfig/network-scripts/ifcfg-ens34

#
echo "$testclientnet $testhostname" >> sbac/hosts
cp sbac/hosts /etc/hosts 
#
echo "nameserver $testclientnet" >> sbac/resolv.conf
echo "search $testdomain1" >> sbac/resolv.conf
#echo "search $testdomain2" >> sbac/resolv.conf
cp sbac/resolv.conf /etc/resolv.conf 
#
#
# cp sbac/nsswitch.conf /etc/nsswitch.conf 
#
systemctl restart network

# Minor Services Section
# SSH
# cp sbac/sshd_config1 /etc/ssh/sshd_config
# systemctl restart sshd
#
# SSH for client
#ssh-keygen -t rsa
#ssh-copy-id $testuser@$testservernet
#ssh-copy-id root@$testservernet
#
# Firewall / NC
#nc -kvl $ncport1
#echo "iptables -A INPUT -s 172.16.31.0/24 -p tcp --dport $ncport1 -j ACCEPT" >> sbac/FWrules.sh
#echo "iptables -A INPUT -p tcp --dport $ncport1 -j REJECT" >> sbac/FWrules.sh
#./sbac/FWrules.sh
#
# Postfix

# DNS
# Edit DNS config file
echo -e "zone \".\" IN {
	type hint;
	file \"named.ca\";
};

zone \"$testdomain1\" IN {
	type slave;
	file \"slaves/named.$testdomain1\";
    masters { $testservernet; };
};

zone \"$vdomain1\" IN {
        type slave;
        file \"slaves/named.$vdomain1\";
        masters { $testservernet; };
};

zone \"$testmaildomain\" IN {
        type slave;
        file \"slaves/named.$testmaildomain\";
        masters { $testservernet; };
};

zone \"$testmaildomain2\" IN {
        type slave;
        file \"slaves/named.$testmaildomain2\";
        masters { $testservernet; };
};

zone \"16.172.IN-ADDR.ARPA\" in {
        type slave;
        file \"slaves/named.16.172\";
        masters { $testservernet; };
};

include \"/etc/named.rfc1912.zones\";
#include \"/etc/named.root.key\";
" >> sbac/namedslave.conf

# Copy config and forward zone files
cp sbac/namedslave.conf /etc/named.conf 
#
# YOU NEED TO CONFIG THE SLAVE ZONES IN CLIENT !!!!!
#
# Restart DNS service
systemctl restart named
#
# Major services
# Firewall / NC
#nc -kvl $ncport2
#echo "iptables -A INPUT -s 172.16.30.0/24 -p tcp --dport $ncport2 -j ACCEPT" >> sbac/FWrules.sh
#echo "iptables -A INPUT -s 172.16.32.0/24 -p tcp --dport $ncport2 -j ACCEPT" >> sbac/FWrules.sh
#echo "iptables -A INPUT -p tcp --dport $ncport2 -j REJECT" >> sbac/FWrules.sh
#./sbac/FWrules.sh
#
# SSH
#cp sbac/sshd_config2 /etc/ssh/sshd_config
#systemctl restart sshd
#
# LDAP
yum install openldap
yum install openldap-clients
echo -e "#
# LDAP Defaults
#

# See ldap.conf(5) for details
# This file should be world readable but not world writable.

#BASE	dc=example,dc=com
#URI	ldap://ldap.example.com ldap://ldap-master.example.com:666
BASE dc=$ldapdc1,dc=$ldapdc2
URI  ldap://$testservernet

#SIZELIMIT	12
#TIMELIMIT	15
#DEREF		never

TLS_CACERTDIR	/etc/openldap/certs

# Turning this off breaks GSSAPI used with krb5 when rdns = false
SASL_NOCANON	on" > /etc/openldap/ldap.conf

yum install nss-pam-ldapd
echo -e "uri ldap://$testservernet/
base dc=$ldapdc1,dc=$ldapdc2" >> /etc/nslcd.conf
# Add ldap to the /etc/nsswitch.conf file as the last source of hosts: entry, "hosts: files dns ldap"
systemctl start nslcd
systemctl enable nslcd
systemctl restart named
#getent hosts
#
# Samba
yum install samba-client
yum install samba-common
yum install cifs-utils
# mkdir /mnt/samba
# mount -t cifs //$testservernet/...sharename... /mnt/samba -o user= ,pass= 
#
# NFS
yum install nfs-utils
mkdir /mnt/nfs
mount -o intr -t nfs $testservernet:/srv/nfs/share /mnt/nfs