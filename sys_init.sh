#!/usr/bin/bash

ip a |grep eth0 &>/dev/null
if [ $? -eq 0 ];then
	net="eth0"
else
	net="ens33"
fi

sed -i "s/ONBOOT=no/ONBOOT=yes/g" /etc/sysconfig/network-scripts/ifcfg-$net
systemctl restart network
if [ $? -eq 0 ];then
	net="Network is successful!"
else
	net="Failed to modify network!"
fi

rm -rf /etc/yum.repos.d/*
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/centos7_base.repo
yum clean all
yum makecache fast
yum remove epel-release -y
yum install epel-release -y
yum install wget lrzsz htop net-tools vim htop iotop python3 python3-devel lsof ntp -y

if [ $? -eq 0 ];then
	yum_repo="Yum source configure successful!"
	soft="Install to software successful!"
else
	yum_repo="Yum source configure failed!"
	soft="Install software is failed!"
fi

systemctl disable --now firewalld
if [ $? -eq 0 ];then
	sl="Close selinux is successful!"
else
	sl="Close selinux is failed!"
fi
setenforce 0
sed -i 's\SELINUX=enforcing\SELINUX=disabled\g' /etc/selinux/config
if [ $? -eq 0 ];then
	fw="Firewalld close is successful!"
else 
	fw="Firewalld to close failed!"
fi


#if [ "$1" == "-y" ];then
#	echo ttyS0 >> /etc/securetty 
#	if [ $? -eq 0 ];then
#		echo "Add ttyS0 to /etc/securetty is successful!"
#	else
#		echo "Add ttyS0 to /etc/securetty is failed!"
#	fi
#	
#	tty="inux16 \/vmlinuz-3.10.0-1160.el7.x86_64 root=\/dev\/mapper\/centos-root ro crashkernel=auto rd.lvm.lv=centos\/root rd.lvm.lv=centos\/swap rhgb quiet LANG=en_US.UTF-8 "
#	sed -i "s/${tty}/${tty}console=ttyS0" /etc/grub2.cfg
#	if [ $? -eq 0 ];then
#                echo "Add ttyS0 to /etc/grub2.cfg linux16(1) is successful!"
#        else
#                echo "Add ttyS0 to /etc/grub2.cfg linux16(1) is failed!"
#        fi
#
#	tty="linux16 \/vmlinuz-0-rescue-7f8e28e36fc74c13b310f8e9af670df9 root=\/dev\/mapper\/centos-root ro crashkernel=auto rd.lvm.lv=centos\/root rd.lvm.lv=centos\/swap rhgb quiet "
#	sed -i "s/${tty}/${tty}console=ttyS0/g" /etc/grub2.cfg
#	if [ $? -eq 0 ];then
#                echo "Add ttyS0 to /etc/grub2.cfg linux16(2) is successful!"
#        else
#                echo "Add ttyS0 to /etc/grub2.cfg linux16(2) is failed!"
#        fi
#	systemctl enable --now serial-getty@ttyS0
#	if [ $? -eq 0 ];then	
#		echo "serial-getty@ttyS0 is startup successful!"
#	else
#		echo "serial-getty@ttyS0 is start up failed!"
#	fi
#fi

echo
echo $net
echo $yum_repo
echo $soft
echo $sl
echo $fw
