#!/bin/sh
docker stop $(docker ps -qa)
if [ "$1" = "registry-flush" ]; then
  docker system prune --force
  docker volume rm $(docker volume ls -q)
else
  docker restart registry
  docker system prune --force
  registryvolume=$(docker inspect registry | grep volumes)
  for vol in $(docker volume ls -q); do 
    if [[ $registryvolume == *"$vol"* ]]; then
      echo "Skip registry volume $vol for not removing it."
    else
      docker volume rm $vol
    fi 
  done
fi
docker rmi -f $(docker images -q)
for mount in $(mount | egrep '/var/lib/kubelet(.*)type (tmpfs|ceph)' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do umount $mount; done
cleanupdirs="/etc/ceph /etc/cni /etc/kubernetes /opt/cni /opt/rke /run/secrets/kubernetes.io /run/calico /run/flannel /var/lib/calico /var/lib/etcd /var/lib/cni /var/lib/kubelet /var/lib/rancher/rke/log /var/log/containers /var/log/pods /var/run/calico"
for dir in $cleanupdirs; do
  echo "Removing $dir"
  rm -rf $dir
done
cleanupinterfaces="flannel.1 cni0 tunl0 weave"
for interface in $cleanupinterfaces; do
  echo "Deleting $interface"
  ip link delete $interface
done

echo "Flush all iptables"
iptables -F -t nat
iptables -X -t nat
iptables -F -t mangle
iptables -X -t mangle
iptables -F
iptables -X
/etc/init.d/docker restart

