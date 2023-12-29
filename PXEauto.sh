#!/usr/bin/bash

systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

cat > /etc/sysconfig/network-scripts/ifcfg-ens33 <<EOF
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="static"
DEFROUTE="yes"
IPADDR=192.168.1.2
PREFIX=24
GATEWAY=192.168.1.1
DNS1=114.114.114.114
DNS2=8.8.8.8
DEVICE="ens33"
ONBOOT="yes"
EOF

yum install -y dhcp tftp tftp-server syslinux wget vsftpd pykickstart

cat > /etc/dhcp/dhcpd.conf <<EOF
ddns-update-style interim;
ignore client-updates;
authoritative;
allow booting;
allow bootp;
allow unknown-clients;

 subnet 192.168.1.0 netmask 255.255.255.0 
{
   range 192.168.1.100 192.168.1.200;
   option domain-name-servers 192.168.1.2;
   option domain-name "server1.example.com";
   option routers 192.168.1.1;
   option broadcast-address 192.168.1.255;
   default-lease-time 600;
   max-lease-time 7200;
 
   # PXE SERVER IP
   next-server 192.168.1.2;     # DHCP server ip
   filename "pxelinux.0";
 }
EOF

cat > /etc/xinetd.d/tftp <<EOF
service tftp
{
     socket_type          = dgram
     protocol                = udp
     wait                      = yes
     user                    = root
     server                  = /usr/sbin/in.tftpd
     server_args             = -s /tftpboot
     disable                 = no
     per_source              = 11
     cps                     = 100 2
     flags                   = IPv4
 }
EOF

cp /usr/share/syslinux/{pxelinux.0,menu.c32,memdisk,mboot.c32,chain.c32} /var/lib/tftpboot/
mkdir /var/lib/tftpboot/pxelinux.cfg
mkdir /var/lib/tftpboot/netboot

mount /dev/cdrom /mnt
cp -rf /mnt/* /var/ftp/pub/

cp /var/ftp/pub/images/pxeboot/vmlinuz /var/lib/tftpboot/netboot/
cp /var/ftp/pub/images/pxeboot/initrd.img /var/lib/tftpboot/netboot/


cat > /var/ftp/pub/ks.cfg <<EOF
#platform=x86, AMD64, or Intel EM64T
 #version=DEVEL
 # Firewall configuration
 firewall --disabled
 # Install OS instead of upgrade
 install
 # Use NFS installation media
 url --url="ftp://192.168.1.2/pub/"
 rootpw --plaintext 1
 # Use graphical install
 graphical
 firstboot disable
 # System keyboard
 keyboard us
 # System language
 lang en_US
 # SELinux configuration
 selinux disabled
 # Installation logging level
 logging level=info
# System timezone
 timezone Asia/Shanghai
 # System bootloader configuration
 bootloader location=mbr
 clearpart --all --initlabel
 part swap --asprimary --fstype="swap" --size=1024
 part /boot --fstype xfs --size=200
 part pv.01 --size=1 --grow
 volgroup rootvg01 pv.01
 logvol / --fstype xfs --name=lv01 --vgname=rootvg01 --size=1 --grow
 reboot

%packages
 @core
 wget
 %end

%post
 %end
EOF
ksvalidator /var/ftp/pub/ks.cfg

cat > /var/lib/tftpboot/pxelinux.cfg/default <<EOF
 default menu.c32
 prompt 0
 timeout 30
 MENU TITLE Togogo.net Linux Training

 LABEL centos7_x64
 MENU LABEL CentOS 7 X64 for newrain
 KERNEL /netboot/vmlinuz
 APPEND  initrd=/netboot/initrd.img inst.repo=ftp://192.168.1.2/pub ks=ftp://192.168.1.2/pub/ks.cfg
EOF

systemctl restart network
systemctl enable dhcpd vsftpd tftp
systemctl restart dhcpd vsftpd tftp
