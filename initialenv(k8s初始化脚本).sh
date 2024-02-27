#!/usr/bin/env bash
# coding: utf-8
#
# author: liuchao
# email: mirs_chao@163.com
# usage: initial kubernetes nodes environments.


# machines's firewalld NetWorkManager offline.
systemctl disable --now firewalld NetworkManager
sed -ri "s/^SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config

# machines's swap partment offline. 关闭swap分区，因为低版本k8s不支持
swapoff -a && sysctl -w vm.swappiness=0
sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab

# domaininfo lookup  此处因为已经做过了域名解析，故此注释
#cat <<-EOF >>/etc/hosts
#MASTER     MASTER_HOSTNAME
#WORKER1    WORKER1_HOSTNAME
#WORKER2    WORKER2_HOSTNAME
#EOF

# configure yumrepo 此处为创建docker源并安装docker，已经安装过docker 19.03-15
#curl -o /etc/yum.repos.d/docker-ce.repo https://mirrors.ustc.edu.cn/docker-ce/linux/centos/docker-ce.repo  #docker要指定版本，最好用19.03-15
#sed -i 's#download.docker.com#mirrors.ustc.edu.cn/docker-ce#' /etc/yum.repos.d/docker-ce.repo
#
#sed -e 's|^mirrorlist=|#mirrorlist=|g' \
#    -e 's|^#baseurl=http://mirror.centos.org/centos|baseurl=https://mirrors.ustc.edu.cn/centos|g' \
#    -i.bak \
#    /etc/yum.repos.d/CentOS-Base.repo
#
#yum clean all && yum -y install epel-release
#
#sed -e 's|^metalink=|#metalink=|g' \
#    -e 's|^#baseurl=https\?://download.fedoraproject.org/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
#    -e 's|^#baseurl=https\?://download.example/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
#    -i.bak \
#    /etc/yum.repos.d/epel.repo

yum makecache fast

# install require software
yum -y install wget jq psmisc vim net-tools telnet yum-utils \
               device-mapper-persistent-data lvm2 git ntpdate \
               ipvsadm ipset sysstat conntrack libseccomp #docker-ce 装过docker了

# sync timezone  同步时间，服务器为阿里云
echo "*/5 * * * *       /usr/sbin/ntpdate -b ntp.aliyun.com" >>/var/spool/cron/root

# initial source
cat <<-EOF >>/etc/security/limits.conf
* soft nofile 655360
* hard nofile 131072
* soft nproc 655350
* hard nproc 655350
* soft memlock unlimited
* hard memlock unlimited
EOF

cat <<-EOF >>/etc/modules-load.d/ipvs.conf
ip_vs
ip_vs_lc
ip_vs_wlc
ip_vs_rr
ip_vs_wrr
ip_vs_lblc
ip_vs_lblcr
ip_vs_dh
ip_vs_sh
ip_vs_fo
ip_vs_nq
ip_vs_sed
ip_vs_ftp
ip_vs_sh
nf_conntrack
ip_tables
ip_set
xt_set
ipt_set
ipt_rpfilter
ipt_REJECT
ipip
EOF

#内核调优
cat <<-EOF >>/etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
fs.may_detach_mounts = 1
vm.overcommit_memory = 1
vm.panic_on_oom = 0
fs.inotify.max_user_watches = 89100
fs.file-max = 52706963
fs.nr_open = 52706963
net.netfilter.nf_conntrack_max = 2310720
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 327680
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_conntrack_max = 65536
net.ipv4.tcp_timestamps = 0
net.core.somaxconn = 16384
EOF

systemctl enable --now docker.service
cat <<-EOF >/etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl daemon-reload && systemctl restart docker

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF

yum makecache fast

clear && echo "initial complete!!!"
