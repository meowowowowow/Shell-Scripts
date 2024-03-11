#!/usr/bin/env bash
#>
#> author: liuchao
#> email: mirs_chao@163.com


#>>> 名称解析
cat <<-EOF >>/etc/hosts
$MASTER1         10.9.22.111
$MASTER2         10.9.22.113
$MASTER3         10.9.22.112
$WORKER1         $WORKER1_HOSTNAME
$WORKER2         $WORKER2_HOSTNAME
EOF

#>>> 关闭防火墙及selinux
systemctl disable --now firewalld
sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

#>>> 更新系统内rpm软件包(除内核外)
yum -y update --exclude=kernel*

#>>> 安装必要的依赖软件包
yum -y install device-mapper-persistent-data lvm2 wget jq psmisc vim net-tools telnet git ntpdate
if [ $? -eq 0 ];then
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  echo "Asia/Shanghai" >/etc/timezone
  echo '*/5 * * * *    ntpdate -b ntp.aliyun.com' >/var/spool/cron/${USER}
fi

#>>> 配置系统docker安装源
#curl -o /etc/yum.repos.d/docker-ce.repo https://mirrors.ustc.edu.cn/docker-ce/linux/centos/docker-ce.repo
#sed -i 's#download.docker.com#mirrors.ustc.edu.cn/docker-ce#' /etc/yum.repos.d/docker-ce.repo
#sed -i 's#gpgcheck=1#gpgcheck=0#' /etc/yum.repos.d/docker-ce.repo

#>>> 关闭swap功能
swapoff -a && sysctl -w vm.swappiness=0
sed -i '/swap/d' /etc/fstab

#>>> 设置最大文件打开数
cat <<-EOF >/etc/security/limits.d/99-k8s.conf
* soft nofile 655360
* hard nofile 131072
* soft nproc 655350
* hard nproc 655350
* soft memlock unlimited
* hard memlock unlimited
EOF

#>>> 安装ipvs并生成内核配置
yum -y install ipvsadm ipset sysstat conntrack libseccomp
if [ $? -eq 0 ];then
cat <<-EOF >/etc/modules-load.d/ipvs.conf
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
fi

#>>> k8s内核配置项
cat <<-EOF >/etc/sysctl.d/k8s.conf
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

#>>> 安装docker引擎
#yum -y install docker-ce-19.03.15-3.el7 docker-ce-cli-19.03.15-3.el7
#if [ $? -ne 0 ];then
#  echo "docker install failed, please check network or yum-repo."
#  exit 1
#fi
curl -O http://10.9.22.188:12888/packages/docker/docker-ce-19.03.15-3.el7.x86_64.rpm
curl -O http://10.9.22.188:12888/packages/docker/docker-ce-cli-19.03.15-3.el7.x86_64.rpm
yum -y install docker-*
rm -rf docker-*
systemctl enable docker && systemctl start docker && docker version
cat <<-EOF >/etc/docker/daemon.json
{
  "registry-mirrors": ["https://registry.docker-cn.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl daemon-reload && systemctl restart docker

mkdir -p /etc/kubernetes/manifests
mkdir -p /etc/kubernetes/pki
mkdir -p /etc/systemd/system/kubelet.service.d
mkdir -p /var/lib/kubelet
mkdir -p /var/log/kubernetes
mkdir -p /etc/etcd/ssl

echo "please download kernel package to update kernel."
