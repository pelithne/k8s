# 1. Kubernetes Workshop

This workshop/tutorial contains a number of different sections, each addressing a specific aspect of running workloads (containers) in Kubernetes, including how to design CI/CD pipelines.

You will go through the following steps to complete the workshop:

* Use Azure Portal and Azure Cloud Shell
* Setup Azure Container Registry to build and store docker images
* Create Kubernetes Cluster using AKS (Azure Kubernetes Service)
* Deploy application to Kubernetes
* Use Helm to create templated Kubernetes applications
* and more...

# 2. Prerequisites

## 2.1 Subscription
You need a valid Azure subscription. If you do not have one, you can sign up for a free trial account here: <https://azure.microsoft.com/en-us/free/>

To use a specific subscription, use the ````account```` command like this (with your subscription id):
````
az account set --subscription <subscription-id>
````
If don't h ave a shell set up to run this command, there will be instructions further down to do that.

## 2.2. Azure Portal

To make sure you are correctly setup with a working subscription, make sure you can log in to the Azure portal. Go to <https://portal.azure.com> Once logged in, feel free to browse around a little bit to get to know the surroundings!

It might be a good idea to keep a tab with the Azure Portal open during the workshop, to keep track of the Azure resources you create. We will almost exclusively use CLI based tools during the workshop, but everything we do will be visible in the portal, and all the resources we create could also be created using the portal.

## 2.3. Azure Cloud Shell

We will use the Azure Cloud Shell (ACS) throughout the workshop for all our command line needs. This is a web based shell that has all the necessary tools (like kubectl, az cli, helm, etc) pre-installed.

Start cloud shell by typing the address ````shell.azure.com```` into a web browser. If you have not used cloud shell before, you will be asked to create a storage location for cloud shell. Accept that and make sure that you run bash as your shell (not powershell).

**Protip: You can use ctrl-c to copy text in cloud shell. To paste you have to use shift-insert, or use the right mouse button -> paste. If you are on a Mac, you can use the "normal" Cmd+C/Cmd+V.**

**Protip II: Cloud Shell will time out after 20 minutes of inactivity. When you log back in, you will end up in your home directory, so be sure to ````cd```` into where you are supposed to be.**

# 3. Hands-on Exercises 

## 3.1. Get the code

The code for this workshop is located in the same repository that you are looking at now. To *clone* the repository to your cloud shell, do this:

```bash
git clone https://github.com/pelithne/k8s.git
```

Then cd into the repository directory:

````bash
cd k8s
````

## 3.2. View the code

Azure Cloud Shell has a built in code editor, which is based on the popular VS Code editor. To view/edit all the files in the repository, run code like this:

````bash
code .
````

You can navigate the files in the repo in the left hand menu, and edit the files in the right hand window. Use the *right mouse button* to access the various commands (e.g. ````Save```` and ````Quit```` etc).

For instance, you may want to have a look in the ````application/azure-vote-app```` directory. This is where the code for the application is located. Here you can also find the *Dockerfile* which will be used to build your docker image, in a later step.

## 3.3. Create Resource Group

All resources in Azure exists in a *Resource Group*. The resource group is a "placeholder" for all the resources you create. 

All the resources you create in this workshop will use the same Resource Group. Use the commnd below to create the resource group.

If you are working in a shared subscription, make sure that you create a uniqely named resource group, eg by using your corporate signum.

````bash
az group create -n <resource-group-name> -l westeurope
````

## 3.4. ACR - Azure Container Registry

You will use a private Azure Container Registry to *build* and *store* the docker images that you will deploy to Kubernetes. The name of the the ACR needs to be globally unique, and should consist of only lower case letters. You could for instance use your corporate signum.

The reason it needs to be unique, is that your ACR will get a Fully Qualified Domain Name (FQDN), on the form ````<Your unique ACR name>.azurecr.io````

The command below will create the container registry and place it in the Resource Group you created previously.

````bash
az acr create --name <your unique ACR name> --resource-group <resource-group-name> --sku basic --admin-enabled true
````

### 3.4.1. Build images using ACR

Docker images can be built in a number of different ways, for instance by using the docker CLI. Another (and easier!) way is to use *Azure Container Registry Tasks*, which is the approach we will use in this workshop.

The docker image is built using a so called *Dockerfile*. The Dockerfile contains instructions for how to build the image. Feel free to have a look at the Dockerfile in the repository (once again using *code*):

````bash
code application/azure-vote-app/Dockerfile
````

As you can see, this very basic Dockerfile will use a *base image* from ````tiangolo/uwsgi-nginx-flask:python3.6-alpine3.8````.

On top of that base image, it will install [redis-py](https://pypi.org/project/redis/) and then take the contents of the directory ````./azure-vote```` and copy it into the container in the path ````/app````.

To build the docker container image, cd into the right directory, and use the ````az acr build```` command:

````bash
cd application/azure-vote-app
az acr build --image azure-vote-front:v1 --registry <your unique ACR name> --file Dockerfile .
````

### 3.4.2. List images in registry

To return a list of images that have been built, use the ```az acr repository list``` command:

```azurecli
az acr repository list --name <your unique ACR name> --output table
```

This image will be deployed from ACR to a Kubernetes cluster in the next step.

## 3.5. AKS - Azure Kubernetes Service

AKS is the hosted Kubernetes service on Azure.

Kubernetes provides a distributed platform for containerized applications. You build and deploy your own applications and services into a Kubernetes cluster, and let the cluster manage the availability and connectivity. In this step a sample application will be deployed into your own Kubernetes cluster. You will learn how to:

* Create an AKS Kubernetes Cluster
* Connect/validate towards the AKS Cluster
* Update Kubernetes manifest files
* Run an application in Kubernetes
* Test the application

### 3.5.1. Create Kubernetes Cluster

### Note: you may need a special command to create your cluster. Ask you coach for guidance


Create an AKS cluster using ````az aks create````. Lets give the cluster the name  ````k8s````, and run the command:

```azurecli
az aks create --resource-group <resource-group-name> --name k8s --generate-ssh-keys  --load-balancer-sku basic --node-count 1 --node-vm-size Standard_D2s_v4
```

The creation time for the cluster can be up to 10 minutes, so this might be a good time for a leg stretcher and/or cup of coffee!

### 3.5.2. Validate towards Kubernetes Cluster

In order to use `kubectl` you need to connect to the Kubernetes cluster, using the following command (which assumes that you have used the naming proposals above):

```azurecli
az aks get-credentials --resource-group <resource-group-name> --name k8s
```

To verify that your cluster is up and running you can try a kubectl command, like ````kubectl get nodes```` which  will show you the nodes (virtual machines) that are active in your cluster.

````bash
kubectl get nodes
````

### 3.5.3 Create image pull secret
For convenience, we previously allowed "admin" login to our ACR. This enables us to use a Kubernetes secret in the manifest, which will hold the ACR credentials. 

To create the secret, you need credentials. These can be found in the Azure portal. First navigate to your Container Registry. Then go to **Access Keys**. In the blade that opens up, you will see the ````login server````, the ````Username```` and ````Password```` that you will use to create the secret.

Note that the ````login-server```` will be on the format <your unique ACR name>.azurecr.io and that ````Username```` will be the same as "your unique ACR name" used when creating the container registry.

Either one of the two passwords can be used.

To create the secret: 
````
kubectl create secret docker-registry acr-secret --docker-server=<login-server> --docker-username=<Username> --docker-password=<Password> 
````

### 3.5.4. Update a Kubernetes manifest file

You have built a docker image with the sample application, in the Azure Container Registry (ACR). To deploy the application to Kubernetes, you must update the image name in the Kubernetes manifest file to include the ACR login server name. Currently the manifest "points" to a container located in the microsoft repository in *docker hub*.

The manifest file to modify is the one that was downloaded when cloning the repository in a previous step. The location of the manifest file is in the ````./k8s/application/azure-vote-app```` directory.

The sample manifest file from the git repo cloned in the first tutorial uses the login server name of *microsoft*. Open this manifest file with a text editor, such as `code`:

```bash
code azure-vote-all-in-one-redis.yaml
```

Replace *microsoft* with your ACR login server name. The following example shows the original content and where you need to replace the **image**.

Original:

```yaml
containers:
- name: azure-vote-front
  image: mcr.microsoft.com/azuredocs/azure-vote-front:v2
```

Provide the ACR login server and image pull secret so that your manifest file looks like the following example:

```yaml
containers:
- name: azure-vote-front
  image: <your unique ACR name>.azurecr.io/azure-vote-front:v1
imagePullSecrets:
- name: acr-secret  
  
```

Please also take some time to study the manifest file, to get a better understanding of what it contains.

Right click Save and then right click Quit.

### 3.5.5. Deploy the application

To deploy your application, use the ```kubectl apply``` command. This command parses the manifest file and creates the needed Kubernetes objects. Specify the sample manifest file, as shown in the following example:

```console
kubectl apply -f azure-vote-all-in-one-redis.yaml
```

When the manifest is applied, a pod and a service is created. The pod contains the "business logic" of your application and the service exposes the application to the internet. This process can take a few minutes, in part because the container image needs to be downloaded from ACR to the Kubernetes Cluster. 

To monitor the progress of the download, you can use ``kubectl get pods`` and ``kubectl describe pod``, like this:

First use ``kubectl get pods`` to find the name of your pod:

```bash
kubectl get pods
```

Then use ``kubectl describe pod`` with the name of your pod:

```bash
kubectl describe pod <pod name>
```

You can also use ``kubectl describe`` to trouble shoot any problems you might have with the deployment (for instance, a common problem is **Error: ErrImagePull**, which can be caused by incorrect credentials or incorrect address/path to the container in ACR. It can also happen if the Kubernetes Cluster does not have read permission in the Azure Container Registry.

Once your container has been pulled and started, showing state **READY**, you can instead start monitoring the **service** to see when a public IP address has been created.

To monitor progress, use the `kubectl get service`. You will probably have to repeats a few times, as it can take a while to get the public IP address.

```console
kubectl get service azure-vote-front
```

The *EXTERNAL-IP* for the *azure-vote-front* service initially appears as *pending*, as shown in the following example:

```bash
azure-vote-front   10.0.34.242   <pending>     80:30676/TCP   7s
```

When the *EXTERNAL-IP* address changes from *pending* to an actual public IP address, the creation of the service is finished. The following example shows a public IP address is now assigned:

```bash
azure-vote-front   10.0.34.242   52.179.23.131   80:30676/TCP   2m
```

To see the application in action, open a web browser to the external IP address.

![Image of Kubernetes cluster on Azure](./media/azure-vote.png)

### 3.5.6. Update an application in Azure Kubernetes Service (AKS)

After an application has been deployed in Kubernetes, it can be updated by specifying a new container image or image version. When doing so, the update is staged so that only a portion of the deployment is concurrently updated. This staged update enables the application to keep running during the update. It also provides a rollback mechanism if a deployment failure occurs.

In this step the sample Azure Vote app is updated. You learn how to:

* Update the front-end application code
* Create an updated container image
* Deploy the updated container image to AKS

### 3.5.7. Increase number of pods

Let's make a change to the sample application, then update the version already deployed to your AKS cluster. 

First we want to make sure that the update can be completed without service interruption. For this to be possible, we need multiple instances of the front end pod. This will enable Kubernetes to update the app as a "rolling update", which means that it will restart the pods in sequence making sure that one or more is always running.

To achieve that, open the sample manifest file `azure-vote-all-in-one-redis.yaml` and change the number of replicas of the ````azure-vote-front```` pod from 1 to 3, on line 34 (or similar).

````bash
code azure-vote-all-in-one-redis.yaml
````

Change

```yaml
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 1
```

to

```yaml
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 3
```

To activate the new configuration, use ````kubectl apply```` in cloud shell:

````bash
kubectl apply -f azure-vote-all-in-one-redis.yaml
````

Now you can verify the number of running front-end instances with the ```kubectl get pods``` command:

```bash
$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
azure-vote-back-769d45cfcb-gk496    1/1     Running   0          51m
azure-vote-front-74b865bcd9-52xkm   1/1     Running   0          49s
azure-vote-front-74b865bcd9-94lrz   1/1     Running   0          49s
azure-vote-front-74b865bcd9-xfsq8   1/1     Running   0          18m
```

### 3.5.8. Update the application

The sample application source code can be found inside of the *azure-vote* directory. Open the *config_file.cfg* file with an editor, such as `code`:

```bash
code azure-vote/config_file.cfg
```

Change the values for *VOTE1VALUE* and *VOTE2VALUE* to different colors. The following example shows the updated color values:

```bash
# UI Configurations
TITLE = 'Azure Voting App'
VOTE1VALUE = 'Blue'
VOTE2VALUE = 'Purple'
SHOWHOST = 'false'
```

Save and close the file.

### 3.5.9. Update the container image

To build a new front-end image, use ```az acr build``` the same way as before, but make sure to change the version from ````v1```` to ````v2````

```bash
az acr build --image azure-vote-front:v2 --registry <your unique ACR name> --file Dockerfile .
```

This will build a new container image, with the code changes you did in the previous step. The image will be stored in ACR with the same name as before, but with a new version (v2).

You can check that all went well with the ````az acr repository show-tags```` command:

````bash
az acr repository show-tags --name <Your ACR Name> --repository azure-vote-front --output table
````

### 3.5.10. Deploy the updated application

To update the application, you can use  ```kubectl set``` and specify the new application version, but the preferred way is to edit the kubernetes manifest to change the version:

Open the file ````azure-vote-all-in-one-redis.yaml```` again and change ````image:```` from ````<Your ACR Name>.azurecr.io/azure-vote-front:v1```` to ````<Your ACR Name>.azurecr.io/azure-vote-front:v2```` on line 47 (or close to 47...).

Change

```yaml
    spec:
      containers:
      - name: azure-vote-front
        image: <Your ACR Name>.azurecr.io/azure-vote-front:v1
```

To

```yaml
    spec:
      containers:
      - name: azure-vote-front
        image: <Your ACR Name>.azurecr.io/azure-vote-front:v2
```

And then run:

````bash
kubectl apply -f azure-vote-all-in-one-redis.yaml
````

Note in the output of the command, how only the azure-vote-front deployment is *configured* while the others are *unchanged*. This is because the changes made to the manifest only impacts the azure-vote-front deployment. In other words, only the necessary things are changed, while the rest is left untouched.

````bash
deployment.apps/azure-vote-back unchanged
service/azure-vote-back unchanged
deployment.apps/azure-vote-front configured
service/azure-vote-front unchanged
````

To monitor the deployment, use the ```kubectl get pods``` command. As the updated application is deployed, your pods are terminated and re-created with the new container image.

```bash
kubectl get pods
```

The following example output shows pods terminating and new instances running as the deployment progresses:

```bash
kubectl get pods

NAME                               READY     STATUS        RESTARTS   AGE
azure-vote-back-2978095810-gq9g0   1/1       Running       0          5m
azure-vote-front-1297194256-tpjlg  1/1       Running       0          1m
azure-vote-front-1297194256-tptnx  1/1       Running       0          5m
azure-vote-front-1297194256-zktw9  1/1       Terminating   0          1m
```

### 3.5.11. Test the updated application

To view the updated application, first get the external IP address of the `azure-vote-front` service (will be the same as before, since the service was not updated, only the pod):

```console
kubectl get service azure-vote-front
```

Now open a local web browser to the IP address.

![Image of Kubernetes cluster on Azure](./media/vote-app-updated-external.png)

### 3.5.12. Clean-up

Make sure the application is deleted from the cluster (otherwise a later step, which is using Helm, might have issues...)

````bash
kubectl delete -f azure-vote-all-in-one-redis.yaml
````


## 3.7. Extra tasks

If you still have time, and want to learn more.

## 3.8. HELM

Helm is an open-source packaging tool that helps you install and manage the life cycle of Kubernetes applications. Similar to Linux package managers such as APT and Yum, Helm is used to manage Kubernetes charts, which are packages of preconfigured Kubernetes resources.

In this exercise you will use Helm to deploy the same application you just deployed using ````kubectl````.

### 3.8.1. Using Helm

Cloud shell already has helm installed, with the latest version of Helm 3.

If you want to, you can check if helm works by running the ````helm version````command:

````bash
helm version
````

Which should give something like:

````bash
version.BuildInfo{Version:"v3.0.2", GitCommit:"19e47ee3283ae98139d98460de796c1be1e3975f", GitTreeState:"clean", GoVersion:"go1.13.5"}
````

**Note: In the previous version of Helm, there was a server side component as well, named "Tiller". This is no longer the case.**

### 3.8.2. Helm and Azure Vote

The repository that you cloned in the beginning of the tutorial (or during preparations) contains a **helm chart** to deploy the application using **Helm**.

Start by changing the directory to where the **helm chart** is located.

````bash
cd ..
cd application/azvote-helmchart
````

Then you need to update your helm chart to point to the container image you created earlier in the **Azure Container Registry**. This is done in the file ````deployments.yaml```` located in ````azvote-helmchart/templates/````. This is essentially the same thing you did earlier in you kubernetes manifest .yaml file.

Change the line:

````bash
image: microsoft/azure-vote-front:v1
````

to

````bash
image: <your unique ACR name>.azurecr.io/azure-vote-front:v2
````

### 3.8.3. Deploy Azure-vote app using Helm

Deploying the azure-vote app using helm can be done with this command, which will give the Helm deployment a name ````azvote```` and use the helm chart in the ````azvote-helmchart```` (indicated by the dot):

````bash
helm install azvote .
````

After some time, you should be able to access the vote app in your browser. To find out when it is available, use ````kubectl get services````

### 3.8.4. Helm Upgrade

One of the advantages with Helm is that configuration values can be separated from values that are more static. Have a look at the file ````values.yaml```` which contains configurations that we can change dynamically. For example, you can upgrade your current deployment and give it new configuration values from the command line.

To modify the application, use the command ````helm upgrade````, and send some new configuration values to it:

````bash
helm upgrade azvote . --set title="Beer" --set value1="Industry Lager" --set value2="Cask Ale"
````

Much better!

<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/beer4.png">
</p>

### 3.8.5. Cleaning up

To keep things tidy in the cluster, delete the application you just deployed with helm

````bash
helm delete azvote

````

This will remove all the pods and services, and other resources related to the application.









# 4 Create Azure Container Apps

In this step, we will create a Container Apps instance that hosts a pre-made web template for testing purposes. This will allow us to easily set up a test environment and begin experimenting with load testing. Follow the instructions below to create your Container Apps instance.

1) In the Azure Portal, type **Container Apps** in the search field.
2) From the drop down menu choose **Container Apps**. 

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt1.JPG)

<img src="https://raw.githubusercontent.com/pelithne/AKS_secure_baseline_the_hard_way/main/images/aks-baseline-architecture-workshop.jpg" width="600">

3) Click on **Create** button.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt2.JPG)

4) Select your subscription from the drop down menu.
5) Select your existing resource group called **rg-companyname-yourname**.
6)Provide a name for the container apps instance, call it: **ca-yourcompanyname-yourname**.
7) select **Sweden Central** as your region.

8) Press **Next: Container>**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt3.JPG)

9) Press **Next: Bindings >**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt4.JPG)

10) Press **Next: Tags >**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt5.JPG)

11) Press **Next: Review + Create >**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt6.JPG)

12) Press **Create**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt7.JPG)

The deployment is in progress, it may take 1-3 minutes.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt8.JPG)

13) Once the deployment is finished, click on the **Home >** breadcrumb on the top left hand side of the portal.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt9.JPG)

14) Click on **Resource groups**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt10.JPG)

15) Click on your resource group called **rg-yourcompanyname-yourname**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt11.JPG)

16) Within the resource group, you should be able to locate your Container Apps instance. Let’s take a moment to verify that the pre-made web template is up and running, by clicking on your **Container Apps instance**

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt12.JPG)

17) In the overview page of Container Apps, copy the URL and click on the **Application URL**.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt13.JPG)

You should now see a page similar to the one illustrated below. If you can see it, congratulations! You have successfully created your first Container Apps instance and made it accessible from the internet. We now have an Azure Container Apps instance that we can run load tests against. Follow the instructions below to verify the status of your Container Apps instance.

![Screenshot](https://github.com/pelithne/azure-for-testers/blob/main/images/alt14.JPG)



# Challenge: Create container app using the cantainer images from the AKS part of the workshop!
