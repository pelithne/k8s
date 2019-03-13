# Preparations
Please complete the steps below, prior to going to the workshop (preferably the day before, and not when arriving to the conference room in the morning... :-) ) 

In order to complete the workshop, you will need:
* Git
* Azure CLI
* Kubectl
* Docker 

If you do not already have these on your system, please follow the steps below.

## Git

### For windows 10 users
The preferred way (of course!) is to use WSL, Windows Subsystem for Linux, to get a linux environment on your windows system. The Ubuntu install comes with git out of the box. Please follow the instructions here: https://docs.microsoft.com/en-us/windows/wsl/install-win10. 

### For Windows 7 users 
#### NOTE: If you are going to install Docker Toolbox in a later step below (you probably are), then you could skip this step, since git comes with the Docker Toolbox installation.

Git SCM is a popular Git client, which can be found here: https://gitforwindows.org/

Using all defaults during install appears to work fine. When installation finishes, you may want to chose to launch the git bash, to complete the next (verification) step.

### For Mac Users
Git SCM for Mac: https://git-scm.com/download/mac

### Verify installation - for all operating systems above
When installation has finished, make sure that you can clone a repository. For instance, you can clone the repo that we will use during the workshop (after switching to a suitable folder on your local machine):
```console
git clone https://github.com/pelithne/azure-voting-app-redis.git
```

Then go into the folder ```azure-voting-app-redis``` and make sure there are some files in there. 

## Azure CLI

### For Windows 10 users 
If WSL/Ubuntu is used you can use `apt` to install Azure CLI. Follow the instructions here:
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest#install

### For Windows 7 users
Use the MSI Installer found here: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest 

### For Mac users
For Mac you can use brew. Instructions here: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-macos?view=azure-cli-latest

### Verify installation  - for all operating systems above
Run (in cmd, powershell or any other shell you ended up using)
```console
az login
``` 
and login with your usual credentials, to connect to the Azure cloud.

## Kubectl
You can use the Azure CLI to install kubectl, like so:
```console
az aks kubernetes install-cli
```
Follow the instructions to add kubectl to you PATH.

### Verify installation  - for all operating systems above
```console
 kubectl version
```
This will show the client version for kubectl, but it will probably report an error because it is not able to connect to the server. This is OK for now.

## Docker
### Windows 10 users
* Install Docker for windows: https://store.docker.com/editions/community/docker-ce-desktop-windows

### Windows 7 users
* Install docker Toolbox: https://docs.docker.com/toolbox/toolbox_install_windows/

After you have completed the installation, and if you feel a bit adventurous, you can set up the bash shell that comes with Docker Toolbox to also run ````az cli``` and ````kubectl````.

If so, you can run the following commands form the "Docker Toolbox Bash shell"
````
alias az='"C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\python.exe" -Im azure.cli'
alias kubectl=~/.azure-kubectl/kubectl.exe
````


### Mac users
* Install Docker for Mac: https://store.docker.com/editions/community/docker-ce-desktop-mac

### Verify installation  - for all operating systems above

#### Note: If you are behind a proxy, you can add an env parameter to docker run (--env HTTPS_PROXY="https://127.0.0.1:3001")
Run:
```console
docker run hello-world
``` 

and read the output to confirm that all is OK with the installation
