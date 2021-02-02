# OneTouchDeployRancher

This repository is for deploying a Rancher (v2.5.5) and K8S cluster(v1.19.6) in an on-premise environment.
The entire deployment does not need Internet but prerequisite stage still need Internet to prepare necessary package and images.

### Prerequisite

There are two things that you need to prepare first.

- Necessary package for host

`docker`, `kubectl`, `curl` and `jq` for master node. To install `kubectl` can refer to [here](https://kubernetes.io/docs/tasks/tools/install-kubectl/). Make sure `root` account can operate `kubectl` command since below deployment needs `root` account.
 
`docker` for worker node.

- Rancher images and registry image

We need to pre-download Rancher images in other online environment since we want to install K8S in an offline site. Also, registry image is also needed. In the end, there should be two files named `rancher-images.tar.gz` and `registry2.7.tar` under `images` folder.

To download Rancher images, according to [offical website](https://rancher.com/docs/rancher/v2.x/en/installation/other-installation-methods/air-gap/populate-private-registry/), you can do this in an online environment:
```
cd scripts

sudo bash rancher-save-images.sh --image-list ../images/rancher-images.txt
```
Then, it will generate `rancher-images.tar.gz` on the same directory.

PS. `rancher-save-images.sh` is already in `scripts` folder.

PS. `rancher-images.txt` is already in `images` folder. To be noticed, this `rancher-images.txt` is main for K8S version `v1.19.6` and Rancher `v2.5.5`, available for 4 cni plugins: `flannel`, `canal`,`calico` and `weave`. Make sure this `rancher-images.txt` is used in above command.

To download registry image, you can refer to [docker hub](https://hub.docker.com/_/registry) for 2.7 tag.
```
docker pull registry:2.7

docker save -o registry2.7.tar registry:2.7
```

### Install AIO (Rancher + K8S master node)

Clone this repository and make sure you have `rancher-images.tar.gz` and `registry2.7.tar` under `images` folder.

There are two steps to deploy Rancher and K8S :

Below steps should be done as a `root`. So we switch to `root` account first (The command may be different from other OS):
```
sudo su
```

- Deploy private registry
```
cd scripts

sudo bash deploy --master-ip $(your_master_ip) -- deploy-registry
```
It will bring a registry named `registry` that contains all Rancher images and is listening on 5000 port.

PS. Deploying registry may take several minutes to complete.

PS. After registry is deployed successfully, it is ok to ignore error message like: "No such image: XXX" or "image is being used ..." since the loaded Rancher images are deleted automatically.

- Start to deploy
```
cd scripts

sudo bash deploy --master-ip $(your_master_ip) --cluster-name $(your_cluster_name) --cni $(your_cni_plugin) -- deploy-master
```

This may take a few minutes to complete.

After the deployment is done, you can login Rancher by: "https://$(your_master_ip):8443". Default password is `123456`. You can check whether the cluster is normal or not by UI or using `kubectl` command:
```
kubectl cluster-info

kubectl get nodes
```

### Add worker node

When master node is good to go, you can add worker node into this cluster.
```
cd scripts

sudo bash deploy -- worker-command
```

Then you can copy the output which is docker command to worker node and start to deploy. You can login Rancher UI to check progress of deploying the worker node.

### Remove Rancher and K8S cluster

Execute below command to remove all the components in master node:
```
cd scripts

sudo bash clean.sh
```

Registry will not be removed by default, if you want to remove it:
```
cd scripts

sudo bash clean.sh registry-flush
```
If you want to clear Rancher from the worker node, you can also refer to [here](https://www.rancher.co.jp/docs/rke/latest/en/managing-clusters/)
