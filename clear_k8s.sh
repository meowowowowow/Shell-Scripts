#!/usr/bin/bash

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
