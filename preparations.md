# Preparations
Please complete the steps below, prior to going to the workshop (preferably the day before, and not when arriving to the conference room in the morning... :-) ) 

In order to complete the workshop, you will need:
* Git
* Azure CLI
* Kubectl
* Docker 

If you do not already have these on your system, please follow the steps below.

## Git
The preferred way (of course!) is to use WSL, Windows Subsystem for Linux, to get a linux environment on your windows system. The Ubuntu install comes with git out of the box. Please follow the instructions here: https://docs.microsoft.com/en-us/windows/wsl/install-win10. 

If, for some reason, you do not want to run WSL, there are many alternatives for running git. For instance: 
* Git SCM for windows: https://gitforwindows.org/
* Git SCM for Mac: https://git-scm.com/download/mac

### Verify installation
When installation has finished, make sure that you can clone a repository. For instance, you can clone the repo that we will use during the workshop (after switching to a suitable folder on your local machine):
```console
git clone https://github.com/Azure-Samples/azure-voting-app-redis.git
```

Then go into the folder ````azure-voting-app-redis```` and make sure there are some files in there. 

## Azure CLI
If WSL/Ubuntu is used you can use `apt` to install Azure CLI. Follow the instructions here:
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest#install

If another shell is used, you are on your own! Look for guidance here: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest

### Verify installation
Run 
```console
az login
``` 
and login with your usual credentials, to connect to the Azure cloud.

## Kubectl
You can use the Azure CLI to install kubectl, like so:
```console
az acs kubernetes install-cli --install-location /usr/local/bin/kubectl
```

### Verify installation
```console
 kubectl version
```
This will show the client version for kubectl, but it will probably report an error because it is not able to connect to the server. This is OK for now.

## Docker
* Install Docker for windows: https://store.docker.com/editions/community/docker-ce-desktop-windows
* Install Docker for Mac: https://store.docker.com/editions/community/docker-ce-desktop-mac

### Verify installation
Run:
```console
docker run hello-world
``` 

and read the output to confirm that all is OK with the installation
