#!/bin/bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo touch /etc/apt/sources.list.d/kubernetes.list
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get -y update
sudo apt-get install -y kubectl
sudo apt-get -y install docker.io
sudo systemctl start docker
sudo systemctl enable docker
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
curl -L https://git.io/get_helm.sh | sudo bash
