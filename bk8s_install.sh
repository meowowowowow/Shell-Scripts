#!/usr/bin/bash

#此处设置master各机器的主机名和IP，以及负载均衡VIP 
d_ip=10.9.22.188:12888
export M1HOSTNAME="master-1"
export M2HOSTNAME="master-2"
export M3HOSTNAME="master-3"
export LOADBALANCER="10.9.22.99"
export MASTER1="10.9.22.111"
export MASTER2="10.9.22.112"
export MASTER3="10.9.22.113"

#cat <<-EOF
#
#执行此脚本前，一定先：
#    1.安装k8sconfig、下载wget、修改/etc/hosts文件
#    2.升级内核
#    3.所有机器执行k8sconfig/binary-deploys/initialenv.sh 初始化文件
#    4.给其他机器分发完公钥
#    5.修改脚本中关于主机名和IP的变量
#  注意：
#    此脚本从分发二进制指令开始！
#    此脚本不会添加worker机器，请手动添加worker机器!
#    master主机名要改为master-1 master-2这样！
#EOF
#echo "按回车键继续"
#read

restart_conf(){
if [ ! -d ~/k8sconfig ];then
	echo
	echo "未检测到k8sconfig目录，请检查是否执行过初始化，或者是执行过初始化后删除了该目录！"
	exit
fi
clear_

#下载二进制文件
wget  http://${d_ip}/packages/kubernetes/cfssl_1.6.3_linux_amd64 -O /usr/local/bin/cfssl
wget  http://${d_ip}/packages/kubernetes/cfssljson_1.6.3_linux_amd64 -O /usr/local/bin/cfssljson
wget  http://${d_ip}/packages/kubernetes/etcd-v3.5.9-linux-amd64.tar.gz
wget  http://${d_ip}/packages/kubernetes/kubernetes-server-linux-amd64.tar.gz

#分发二进制工具
tar xf kubernetes-server-linux-amd64.tar.gz --strip-components=3 -C /usr/local/bin/ kubernetes/server/bin/kube{let,ctl,-apiserver,-controller-manager,-scheduler,-proxy}
tar -zxvf etcd-v3.5.9-linux-amd64.tar.gz --strip-components=1 -C /usr/local/bin/ etcd-v3.5.9-linux-amd64/etcd{,ctl}

for i in $MASTER2 $MASTER3
do
scp /usr/local/bin/kube* $i:/usr/local/bin/
scp /usr/local/bin/etcd* $i:/usr/local/bin/
done

#删除残留
rm -rf kubernetes-server-linux-amd64.tar.gz 
rm -rf etcd-v3.5.9-linux-amd64.tar.gz

#生成集群内部通信证书
chmod +x /usr/local/bin/cfssl*
cd /root/k8sconfig/binary-deploys/certs/
bash /root/k8sconfig/binary-deploys/certs/generate-certs.sh 
cp /etc/etcd/ssl/* /etc/kubernetes/pki/etcd

#将证书分发给其他master机器
for i in $MASTER2 $MASTER3
do
scp -r /etc/kubernetes/* $i:/etc/kubernetes/
scp /etc/etcd/ssl/* $i:/etc/etcd/ssl/
done

#生成etcd证书
sed 's/LOCALHOSTNAME/'"$M1HOSTNAME"'/; s/MASTER1/'"$MASTER1"'/; s/MASTER2/'"$MASTER2"'/; s/MASTER3/'"$MASTER3"'/; s/MASTER/'"$MASTER1"'/; s/M1HOSTNAME/'"$M1HOSTNAME"'/; s/M2HOSTNAME/'"$M2HOSTNAME"'/; s/M3HOSTNAME/'"$M3HOSTNAME"'/' ~/k8sconfig/binary-deploys/services/etcd/etcd-config.yaml > ~/etcd-config-01.yaml
  
sed 's/LOCALHOSTNAME/'"$M2HOSTNAME"'/; s/MASTER1/'"$MASTER1"'/; s/MASTER2/'"$MASTER2"'/; s/MASTER3/'"$MASTER3"'/; s/MASTER/'"$MASTER2"'/; s/M1HOSTNAME/'"$M1HOSTNAME"'/; s/M2HOSTNAME/'"$M2HOSTNAME"'/; s/M3HOSTNAME/'"$M3HOSTNAME"'/' ~/k8sconfig/binary-deploys/services/etcd/etcd-config.yaml > ~/etcd-config-02.yaml

sed 's/LOCALHOSTNAME/'"$M3HOSTNAME"'/; s/MASTER1/'"$MASTER1"'/; s/MASTER2/'"$MASTER2"'/; s/MASTER3/'"$MASTER3"'/; s/MASTER/'"$MASTER3"'/; s/M1HOSTNAME/'"$M1HOSTNAME"'/; s/M2HOSTNAME/'"$M2HOSTNAME"'/; s/M3HOSTNAME/'"$M3HOSTNAME"'/' ~/k8sconfig/binary-deploys/services/etcd/etcd-config.yaml > ~/etcd-config-03.yaml

cd 
for i in 1 2 3
do
scp etcd-config-0${i}.yaml master-$i:/etc/etcd/etcd.config.yml
scp ~/k8sconfig/binary-deploys/services/etcd/etcd-service-config.service master-$i:/usr/lib/systemd/system/etcd.service
rm -rf etcd-config-0${i}.yaml
done

cd

#配置负载均衡和高可用
cat <<-EOF

在所有主节点机器执行下面命令下载haproxy和keepalived，然后回来按回车键继续！
yum -y install keepalived haproxy

EOF
read

rm -rf /etc/haproxy/haproxy.*
sed  's/MASTER1/'"${MASTER1}"'/; s/MASTER2/'"${MASTER2}"'/; s/MASTER3/'"${MASTER3}"'/; s/M1HOSTNAME/master-1/; s/M2HOSTNAME/master-2/; s/M3HOSTNAME/master-3/' ~/k8sconfig/binary-deploys/services/loadbalancer/haproxy.conf > haproxy.conf


for i in 1 2 3
do
scp haproxy.conf master-$i:/etc/haproxy/haproxy.cfg
done
rm -rf haproxy.conf

cd
sed 's/MSID/ens33/; s/MSI/'"${MASTER1}"'/; s/LOADBALANCER/'"${LOADBALANCER}"'/'  ~/k8sconfig/binary-deploys/services/loadbalancer/keepalived.conf >k1.conf
sed 's/MSID/ens33/; s/MSI/'"${MASTER2}"'/; s/LOADBALANCER/'"${LOADBALANCER}"'/'  ~/k8sconfig/binary-deploys/services/loadbalancer/keepalived.conf >k2.conf
sed 's/MSID/ens33/; s/MSI/'"${MASTER3}"'/; s/LOADBALANCER/'"${LOADBALANCER}"'/'  ~/k8sconfig/binary-deploys/services/loadbalancer/keepalived.conf >k3.conf

chmod +x ~/k8sconfig/binary-deploys/services/loadbalancer/check.sh

for i in 1 2 3
do
scp k${i}.conf master-$i:/etc/keepalived/keepalived.conf
scp ~/k8sconfig/binary-deploys/services/loadbalancer/check.sh master-$i:/etc/keepalived/check_apiserver.sh
rm -rf k${i}.conf
done
sed -i '29i\preempt' /etc/keepalived/keepalived.conf

echo
echo "所有节点包括本机重启keepalived和haproxy后按回车继续"
echo "systemctl restart keepalived haproxy"
echo 
read

#配置APISERVER
for i in $MASTER1 $MASTER2 $MASTER3
do
sed 's/LBMASTER/'"${i}"'/; s/MASTER1/'"${MASTER1}"'/; s/MASTER2/'"${MASTER2}"'/; s/MASTER3/'"${MASTER3}"'/' ~/k8sconfig/binary-deploys/services/cplane/apiserver.service >api.service
scp api.service $i:/usr/lib/systemd/system/kube-apiserver.service
done
rm -rf api.service

#配置controller-manager和scheduler
cd ~
sed 's#POD_NET_SEGMENT#172.16.0.0/12#' ~/k8sconfig/binary-deploys/services/cplane/controller.service >controller.service
for i in $MASTER1 $MASTER2 $MASTER3
do
scp controller.service $i:/usr/lib/systemd/system/kube-controller-manager.service
scp  ~/k8sconfig/binary-deploys/services/cplane/scheduler.service $i:/usr/lib/systemd/system/kube-scheduler.service
done
rm -rf controller.service

cat <<-EOF

所有节点执行下面命令后，回车继续：
systemctl daemon-reload && systemctl restart etcd kube-scheduler kube-controller-manager kube-apiserver

EOF
read

#配置集群证书自动颁发
cd ~/k8sconfig/binary-deploys/services/bootstrap
sed  's/LOADBALANCER/'"${LOADBALANCER}"'/' ~/k8sconfig/binary-deploys/services/bootstrap/create-certs.sh > ~/k8sconfig/binary-deploys/services/bootstrap/cc.sh
bash ~/k8sconfig/binary-deploys/services/bootstrap/cc.sh
cd 

for i in $MASTER2 $MASTER3
do
scp /etc/kubernetes/bootstrap-kubelet.kubeconfig  $i:/etc/kubernetes/bootstrap-kubelet.kubeconfig
done
rm -rf ~/k8sconfig/binary-deploys/services/bootstrap/cc.sh

#配置所有节点的kubelet
for i in $MASTER1 $MASTER2 $MASTER3
do
scp ~/k8sconfig/binary-deploys/services/allmachines/kubelet.service $i:/usr/lib/systemd/system/kubelet.service
scp  ~/k8sconfig/binary-deploys/services/allmachines/kubelet-10.conf $i:/etc/systemd/system/kubelet.service.d/10-kubelet.conf
scp ~/k8sconfig/binary-deploys/services/allmachines/kubelet.yaml $i:/etc/kubernetes/kubelet-conf.yml
scp /etc/etcd/ssl/* $i:/etc/etcd/ssl/
scp -r /etc/kubernetes/* $i:/etc/kubernetes/
done

#配置kube-proxy
sed 's/LOADBALANCER/'"${LOADBALANCER}"'/'  ~/k8sconfig/binary-deploys/services/allmachines/kube-proxy-create.sh > ~/k8sconfig/binary-deploys/services/allmachines/kpc.sh
bash ~/k8sconfig/binary-deploys/services/allmachines/kpc.sh
rm -rf ~/k8sconfig/binary-deploys/services/allmachines/kpc.sh

sed -i 's#POD_NET_SEGMENT#172.16.0.0/12#' ~/k8sconfig/binary-deploys/services/allmachines/kube-proxy.conf

for i in $MASTER1 $MASTER2 $MASTER3
do
scp ~/k8sconfig/binary-deploys/services/allmachines/kube-proxy.service $i:/usr/lib/systemd/system/kube-proxy.service
scp  ~/k8sconfig/binary-deploys/services/allmachines/kube-proxy.conf $i:/etc/kubernetes/kube-proxy.conf
scp /etc/kubernetes/kube-proxy.kubeconfig  $i:/etc/kubernetes/kube-proxy.kubeconfig
done

cat <<-EOF

安装完毕，所有节点执行即可开始使用K8S集群，安装完后按回车：
systemctl daemon-reload && systemctl restart etcd kubelet kube-proxy kube-apiserver kube-scheduler kube-controller-manager

EOF

echo "是否立即安装插件？[yes/no]"
read yn
case yn in 
	"yes")
		install_calico
	;;
	"no")
		exit
	;;
	*)
		echo "退出！"
		exit
	;;
esac	

rm -rf ~/.~~~k8s_install~~~
}

clear_(){
	rm -rf ~/kernel-lt*
	rm -rf ~/k8sconfig.tar.gz
}

clear_k8s(){
	pkill etcd
	pkill kubelet
	pkill kube-proxy
	pkill kube-scheduler
	pkill kube-controller-manager
	pkill kube-apiserver
	pkill haproxy
	pkill keepalived
	
	yum erase keepalived haproxy -y
	yum erase docker* -y
	rm -rf /etc/haproxy
	rm -rf /etc/keepalived
	rm -rf /usr/local/bin/*
	rm -rf /etc/kubernetes
	rm -rf /etc/etcd
	rm -rf ~/.kube
	rm -rf ~/.pki
	rm -rf /var/lib/etcd
	rm -rf /usr/lib/systemd/system/kube*
	rm -rf /usr/lib/systemd/system/etcd*
	rm -rf /var/lib/kubelet
	rm -rf /var/log/kubernetes
	rm -rf /etc/systemd/system/kubelet.service.d
	rm -rf /etc/cni/
	rm -rf /var/lib/calico/
}

install_calico(){
	 cd ~/k8sconfig/binary-deploys
       	 sed -i 's#etcd_endpoints: "http://<ETCD_IP>:<ETCD_PORT>"#etcd_endpoints: "https://'"${MASTER1}"':2379,https://'"${MASTER2}"':2379,https://'"${MASTER3}"':2379"#g' calico-etcd.yaml
	 ETCD_CA=$(cat /etc/kubernetes/pki/etcd/etcd-ca.pem | base64 | tr -d '\n')
	 ETCD_CERT=$(cat /etc/kubernetes/pki/etcd/etcd.pem | base64 | tr -d '\n')
	 ETCD_KEY=$(cat /etc/kubernetes/pki/etcd/etcd-key.pem | base64 | tr -d '\n')

	 sed -i "s@# etcd-key: null@etcd-key: ${ETCD_KEY}@g; s@# etcd-cert: null@etcd-cert: ${ETCD_CERT}@g; s@# etcd-ca: null@etcd-ca: ${ETCD_CA}@g" calico-etcd.yaml
	 sed -i 's#etcd_ca: ""#etcd_ca: "/calico-secrets/etcd-ca"#g; s#etcd_cert: ""#etcd_cert: "/calico-secrets/etcd-cert"#g; s#etcd_key: ""#etcd_key: "/calico-secrets/etcd-key"#g' calico-etcd.yaml
	 sed  's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g; s@#   value: "192.168.0.0/16"@  value: '"172.16.0.0/12"'@g;' calico-etcd.yaml > /yaml/calico-etcd.yaml
       	 kubectl apply -f /yaml/calico-etcd.yaml
	
	 cd
	
cat <<-EOF
cddalico安装完毕，按1回车开始安装coredns,按其他键退出：
EOF
read core
if [ $core -eq 1 ];then
	install_coredns
else
	exit
fi
}

install_coredns(){
	cd ~/k8sconfig/binary-deploys/services/coredns

	bash deploy.sh -s -i 10.96.0.10 >coredns.yaml
	COREDNS_VERSION=$(grep "image:" coredns.yaml | awk '{ print $2 }')
	sed "s#${COREDNS_VERSION}#coredns/coredns:1.8.4#" coredns.yaml > /yaml/coredns.yaml
	kubectl apply -f /yaml/coredns.yaml
	cd
cat <<-EOF
coredns服务安装完成，等待拉取镜像完成即可。
EOF
}
s_init(){
	curl -O http://${d_ip}:12888/packages/kubernetes/k8sconfig.tar.gz
	tar xf k8sconfig.tar.gz

	sed -i 's/$MASTER1_HOSTNAME/'"$MASTER1"'/; s/$MASTER3_HOSTNAME/'"$MASTER2"'/; s/$MASTER2_HOSTNAME/'"$MASTER3"'/;' /root/k8sconfig/binary-deploys/initialenv.sh
	for i in $MASTER1 $MASTER2 $MASTER3
	do
		scp ~/k8sconfig/binary-deploys/initialenv.sh $i:~/
	done	
	echo "在所有机器执行:

	      sh ~/initialenv.sh

之后即可开始进行安装K8S集群。"
}

delete_coredns(){
	kubectl delete service kube-dns -n kube-system
	kubectl delete deployment coredns -n kube-system
	kubectl delete configmap coredns -n kube-system	
	kubectl delete clusterrolebinding system:coredns
	kubectl delete clusterrole system:coredns
	kubectl delete serviceaccount coredns -n kube-system
	cd /yaml
	kubectl delete -f coredns.yaml
	cd 
	echo
	echo "coreDNS删除完成！"
}
delete_calico(){
	# 删除DaemonSet
	kubectl delete daemonset -n kube-system calico-node
	
	# 删除Deployment（如果存在）
	kubectl delete deployment -n kube-system calico-typha
	
	# 删除ConfigMaps
	kubectl delete configmap -n kube-system calico-config
	
	# 删除ServiceAccount
	kubectl delete serviceaccount -n kube-system calico-node
	kubectl delete serviceaccount -n kube-system calico-kube-controllers
	
	# 删除ClusterRoles和ClusterRoleBindings
	kubectl delete clusterrole calico-node calico-kube-controllers
	kubectl delete clusterrolebinding calico-node calico-kube-controllers
	
	kubectl delete networkpolicy --all --namespace=kube-system
	## 查看当前的IP池
	#calicoctl get ippool -o wide
	#
	## 删除IP池
	#calicoctl delete ippool <ippool-name>
	# 清理Calico相关目录和文件
	rm -rf /etc/cni/net.d/calico-kubeconfig
	rm -rf /var/lib/calico/	
	
	cd /yaml
	kubectl delete -f calico-etcd.yaml 
	cd
	echo
	echo "删除calico完成！"
}

init(){
#判断如果有标记文件存在则提示
if [ -f ~/.~~~k8s_install~~~ ];then
read -p  "提示，之前执行过初始化，不建议重新执行初始化！按1继续，其他退出
" str
fi
if [ "$str" != 1 ];then
exit
fi


curl -O http://${d_ip}:12888/packages/kubernetes/k8sconfig.tar.gz
curl -O http://${d_ip}:12888/packages/kubernetes/kernel-lt-5.4.226-1.el7.elrepo.x86_64.rpm
curl -O http://${d_ip}:12888/packages/kubernetes/kernel-lt-devel-5.4.226-1.el7.elrepo.x86_64.rpm
tar xf k8sconfig.tar.gz

sed -i 's/$MASTER1_HOSTNAME/'"$MASTER1"'/; s/$MASTER3_HOSTNAME/'"$MASTER2"'/; s/$MASTER2_HOSTNAME/'"$MASTER3"'/;' /root/k8sconfig/binary-deploys/initialenv.sh
for i in $MASTER1 $MASTER2 $MASTER3
do
scp ~/k8sconfig/binary-deploys/initialenv.sh $i:~/
scp kernel-lt-5.4.226-1.el7.elrepo.x86_64.rpm $i:/root/
scp kernel-lt-devel-5.4.226-1.el7.elrepo.x86_64.rpm $i:/root/
done

#创建标记文件，用于提醒原来是否执行过初始化
touch ~/.~~~k8s_install~~~
cat <<-EOF

在包括本节点内所有节点执行：
bash initialenv.sh
yum -y localinstall kernel-lt-*
grub2-set-default 0 && grub2-mkconfig -o /etc/grub2.cfg
grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
reboot

EOF
}

help_(){
cat <<-EOF

	选项1：未安装过K8S的纯净电脑，可以先按照：1-2的顺序正常进行安装K8S集群。（主节点执行即可）
	选项2：安装过K8S集群，并且执行过4选项清除过K8S的安装后，想要再次安装，可以执行此步骤进行简单初始化。（主节点执行即可）
	选项3：在执行过1或者2的初始化后，选择此项继续安装K8S集群，主节点执行即可，根据提示操作。
	选项4：清除K8S集群的安装，需要在所有节点执行，会彻底删除K8S的所有数据，包括配置文件、K8S程序等，但不会删除调优的参数。
	选项5：安装clico网络插件
	选项6：安装coredns服务发现
	选项11：删除coredns
	选项12：删除calico
EOF
}

if [ "$1" == "-h" ];then
	help_
	exit
fi

cat <<-EOF

			1.执行初始化。
			2.执行简单初始化。
			3.开始安装K8S集群(必须在初始化之后)。
			4.执行清理程序彻底清除K8S集群的安装，以便重装使用(但不会清理内核调优过的配置)。
			5.安装calico插件
			6.安装coreDNS网络发现
			11.删除calico
			12.删除coreDNS
			0.帮助
			9.或者其他：退出
EOF
read ttt

case $ttt in
	1)
		init	
	;;
	2)
		s_init
	;;
	3)
		restart_conf
	;;
	4)
		clear_k8s
	;;
	5)
		install_calico	
	;;
	6)
		install_coredns	
	;;
	12)
		delete_coredns
	;;
	11)
		delete_calico
	;;
	0)
		help_
	;;
	9)
		echo "退出安装！"
		exit
	;;
	*)
		echo "输入错误，退出"
		exit
	;;
esac
