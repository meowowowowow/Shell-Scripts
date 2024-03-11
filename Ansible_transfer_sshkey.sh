#!/usr/bin/env bash
#
#author:fff
#date:fff
#email:2394i9023i

if [ ! -f ~/.ssh/id_rsa ];then
	ssh-keygen -t rsa -b 4096 -N "" -C "ansible@fyb.com" -f ${HOME}/.ssh/id_rsa		
fi

rpm -qa | grep expect &>/dev/null
if [ $? -ne 0 ];then
	echo "没有expect,正在安装..."
	yum -y install expect &>/dev/null	
fi		

function ExpectTransferSSHKey(){
	host_ip=$1
	auth_pwd=$2
	
	/usr/bin/expect<<-EOF
	spawn ssh-copy-id root@${host_ip}
	expect "yes/no" {send "yes\r" }
	expect "password:" {send "${auth_pwd}\r" }
	expect eof
EOF
}


for ip in $(cat hosts);do
	       
		ExpectTransferSSHKey "${ip}" $1 	
		
done
echo "完成！"
