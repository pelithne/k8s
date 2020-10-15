# 1. Kubernetes Workshop

This workshop/tutorial contains a number of different sections, each addressing a specific aspect of running workloads (containers) in Kubernetes, including how to design CI/CD pipelines.

You will go through the following steps to complete the workshop:

* Use Azure Portal and Azure Cloud Shell
* Setup Azure Container Registry to build and store docker images
* Create Kubernetes Cluster using AKS (Azure Kubernetes Service)
* Deploy application to Kubernetes
* Use Helm to create templated Kubernetes applications
* Use Azure DevOps to setup up build and release pipelines
* and more...

# 2. Prerequisites

You need a valid Azure subscription. If you do not have one, you can sign up for a free trial account here: <https://azure.microsoft.com/en-us/free/>

## 2.1. Azure Portal

To make sure you are correctly setup with a working subscription, make sure you can log in to the Azure portal. Go to <https://portal.azure.com.> Once logged in, feel free to browse around a little bit to get to know the surroundings!

It might be a good idea to keep a tab with the Azure Portal open during the workshop, to keep track of the Azure resources you create. We will almost exclusively use CLI based tools during the workshop, but everything we do will be visible in the portal, and all the resources we create could also be created using the portal.

## 2.2. Azure Cloud Shell

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

All resources in Azure exists in a *Resource Group*. The resource group is a "container" for all the resources you create. 

All the resources you create in this workshop will use the same Resource Group. The command below will create a resource group named ````k8s-rg```` in West Europe. 

````bash
az group create -n k8s-rg -l westeurope
````

## 3.4. ACR - Azure Container Registry

You will use a private Azure Container Registry to *build* and *store* the docker images that you will deploy to Kubernetes. The name of the the ACR needs to be globally unique, and should consist of only lower case letters. You could for instance use your corporate signum.

The reason it needs to be unique, is that your ACR will get a Fully Qualified Domain Name (FQDN), on the form ````<Your unique ACR name>.azurecr.io````

The command below will create the container registry and place it in the Resource Group you created previously (k8s-rg).

````bash
az acr create --name <your unique ACR name> --resource-group k8s-rg --sku basic
````

### 3.4.1. Build images using ACR

Docker images can be built in a number of different ways, for instance by using the docker CLI. Another (and easier!) way is to use *Azure Container Registry Tasks*, which is the approach we will use in this workshop.

The docker image is built using a so called *Dockerfile*. The Dockerfile contains instructions for how to build the image. Feel free to have a look at the Dockerfile in the repository (once again using *code*):

````bash
code application/azure-vote-app/Dockerfile
````

As you can see, this very basic Dockerfile will use a *base image* from ````tiangolo/uwsgi-nginx-flask:python3.6-alpine3.8````.

On top of that base image, it will install ````redis```` and then take the contents of the directory ````./azure-vote```` and copy it into the container in the path ````/app````.

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

Create an AKS cluster using ````az aks create````. Lets give the cluster the name  ````k8s````, and run the following command (assuming that you named your resource group as suggested in a previous step, ````k8s-rg````):

```azurecli
az aks create --resource-group k8s-rg --name k8s --generate-ssh-keys --attach-acr <your unique ACR name> --load-balancer-sku basic --node-count 3 --node-vm-size Standard_B2s
```

### Note: If your subscription does not allow you to create Service Principals, run the command without ````--attach-arc````. You will use a different (more difficult method later...)

The creation time for the cluster can be up to 10 minutes, so this might be a good time for a leg stretcher and/or cup of coffee!

### 3.5.2. Validate towards Kubernetes Cluster

In order to use `kubectl` you need to connect to the Kubernetes cluster, using the following command (which assumes that you have used the naming proposals above):

```azurecli
az aks get-credentials --resource-group k8s-rg --name k8s
```

To verify that your cluster is up and running you can try a kubectl command, like ````kubectl get nodes```` which  will show you the nodes (virtual machines) that are active in your cluster.

````bash
kubectl get nodes
````

### 3.5.3. Update a Kubernetes manifest file

You have built a docker image with the sample application, in the Azure Container Registry (ACR). To deploy the application to Kubernetes, you must update the image name in the Kubernetes manifest file to include the ACR login server name. Currently the manifest "points" to a container located in the microsoft repository in *docker hub*.

The manifest file to modify is the one that was downloaded when cloning the repository in a previous step. The location of the manifest file is in the ./k8s/application/azure-vote-app directory.

The sample manifest file from the git repo cloned in the first tutorial uses the login server name of *microsoft*. Open this manifest file with a text editor, such as `code`:

```bash
code azure-vote-all-in-one-redis.yaml
```

Replace *microsoft* with your ACR login server name. The following example shows the original content and where you need to replace the **image**.

Original:

```yaml
containers:
- name: azure-vote-front
  image: microsoft/azure-vote-front:v1
```

Provide the ACR login server so that your manifest file looks like the following example:

```yaml
containers:
- name: azure-vote-front
  image: <your unique ACR name>.azurecr.io/azure-vote-front:v1
```

Please also take some time to study the manifest file, to get a better understanding of what it contains.

### Note: If you previously could not connect your ACR to you AKS using ````--attach-acr```` you need to perform an additional step, which is described <a href="https://github.com/pelithne/k8s/blob/master/imagepullsecret.md">here!</a>


Save and Quit.

### 3.5.4. Deploy the application

To deploy your application, use the ```kubectl apply``` command. This command parses the manifest file and creates the needed Kubernetes objects. Specify the sample manifest file, as shown in the following example:

```console
kubectl apply -f azure-vote-all-in-one-redis.yaml
```

### 3.5.5. Test the application

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

Once your container has been pulled and started, showing state **READY**, you can instead start monitoring the service to see when a public IP address has been created.

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

Note in the output of the command, how only the azure-vote-front deployment is *configured* while the others are *unchanged*. This is because the changes made to the manifest only impacts the azure-vote-front deployment. In other words, only the necessary things are changed, while the rest are left untouched.

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

## 3.6. Azure DevOps with AKS

<p align="left">
  <img width="65%" height="65%" hspace="0" src="./media/index-hero.jpg">
</p>

In this step you will create CI/CD pipelines to deploy your application into the AKS cluster. You will learn how to:  

* Automatically build an application on check-in
* Automatically build the docker container for the application
* Automatically deploy the docker container to AKS

### 3.6.1. Register an account at Azure DevOps

You can create a free Azure DevOps account at: <https://azure.microsoft.com/en-us/services/devops/>. Azure DevOps is SaaS service from Microsoft. 

You need a Microsoft account to get started. If you do not have one you can create a free account here: <https://account.microsoft.com/account?lang=en-us>

Once you have logged in to your Azure Devops account, you will create a **project**. Give the project a name, like "k8s".

You should now have project that looks similar to this:

<p align="left">
  <img width="65%" hspace="0" src="./media/devopsproject.JPG">
</p>

The left hand side shows you:

* **Overview** - overview of the Azure DevOps project like wiki, dashboards and more
* **Boards** - supporting a Agile work methodology with sprints and backlog
* **Repos** - git repository for your source code
* **Pipelines** - build and release - the essence of CI/CD
* **TestPlans** - testing overview
* **Artifacts** - your build artifacts that you might share in other projects, like nuget packages and such.

### 3.6.2. Create your Repository

During this step we will import the same repository we have been working with in previous steps, but this time we will import it into Azure Devops instead.

To do this, start by clicking on *Repos*.

Select "import a repository"
<p align="left">
  <img width="40%" height="40%" hspace="0" src="./media/import-repo-1.png">
</p>

Then type in the URL to the repository (this is becoming familiar by now... :-) ): https://github.com/pelithne/k8s and click **Import**
<p align="left">
  <img width="40%" height="40%" hspace="0" src="./media/import-repo-2.png">
</p>

When the import is finished, you will have your own version of the repository in Azure Devops. The code that you will work with in this part of the tutorial is located in the ````application/azure-vote-app```` folder.

In order for for Azure Devops to use the container that you created in previous steps, you need to update the Kubernetes Manifest (once again!). Navigate to the manifest named ````azure-vote-all-in-one-redis.yaml```` in the application folder.

**Note: The repo you imported is the "original" repo, which does not have any of the changes you made before, so you start from "scratch".**

You can edit the file in your browser by selecting **edit** in the top toolbar. Scroll down in the file, and change.

````bash
image: microsoft/azure-vote-front:v1
````

to

````bash
image: <your unique ACR name>.azurecr.io/azure-vote-front:v1
````

Don't forget to select "Commit" after the change, to include the change in your repository.


### 3.6.4. Create Pipeline

In this section you will create your pipeline, which will consist of a build stage and a deploy stage. 

We will define the pipeline as **code**, in your repository, which simply means that the steps in the pipeline will be described in text, in a yaml-file.

### 3.6.5. Create a new Pipeline

Go to Pipelines and create a new pipeline:

<p align="left">
  <img width="65%" hspace="0" src="./media/new_pipeline_v2.jpg">
</p>

Choose "Azure Repos Git" as your source code repository, and then select the repository that you previously imported to Azure DevOps.

<p align="left">
  <img width="30%" hspace="0" src="./media/pipeline_1.JPG">
</p>

First select the repository (e.g. "k8s") then choose "Deploy to Azure Kubernetes Service"

<p align="left">
  <img width="60%" hspace="0" src="./media/configure_your_pipeline.JPG">
</p>

You will now be assisted in creating a new pipeline for your Kubernetes deployment.

In the "Pop-up" that appears, you need to add the subscription to use (unless it is already added). Then select your newly created AKS cluster, and the namespace to use in the cluster. Select default, for simplicity.

Then add your Container Registry and the image you pushed previously. 

#### Note: if you cannot add the image, you can fix it in a later step

<p align="left">
  <img width="40%" hspace="0" src="./media/deploy_to_aks.JPG">
</p>


The pipeline that was created should look similar to this:

````yaml
# Deploy to Azure Kubernetes Service
# Build and push image to Azure Container Registry; Deploy to Azure Kubernetes Service
# https://docs.microsoft.com/azure/devops/pipelines/languages/docker

trigger:
- master

resources:
- repo: self

variables:

  # Container registry service connection established during pipeline creation
  dockerRegistryServiceConnection: '3b126235-3a6f-1239-8514-10c9cf630123'
  imageRepository: 'something-perhaps-not-right'
  containerRegistry: 'pelithneacr.azurecr.io'
  dockerfilePath: '**/Dockerfile'
  tag: '$(Build.BuildId)'
  imagePullSecret: 'pelithneacrb820-auth'

  # Agent VM image name
  vmImageName: 'ubuntu-latest'
  

stages:
- stage: Build
  displayName: Build stage
  jobs:  
  - job: Build
    displayName: Build
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: Docker@2
      displayName: Build and push an image to container registry
      inputs:
        command: buildAndPush
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
          
    - upload: manifests
      artifact: manifests

- stage: Deploy
  displayName: Deploy stage
  dependsOn: Build

  jobs:
  - deployment: Deploy
    displayName: Deploy
    pool:
      vmImage: $(vmImageName)
    environment: 'k8s2.default'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@0
            displayName: Create imagePullSecret
            inputs:
              action: createSecret
              secretName: $(imagePullSecret)
              dockerRegistryEndpoint: $(dockerRegistryServiceConnection)
              
          - task: KubernetesManifest@0
            displayName: Deploy to Kubernetes cluster
            inputs:
              action: deploy
              manifests: |
                $(Pipeline.Workspace)/manifests/deployment.yml
                $(Pipeline.Workspace)/manifests/service.yml
              imagePullSecrets: |
                $(imagePullSecret)
              containers: |
                $(containerRegistry)/$(imageRepository):$(tag)

````

Have a look at this, and try to understand what each part is doing.

To break it down a little, these are some of the important things to notice. From the top:


The first lines ensures that when something is added to the master branch of your repository, a new run of the pipeline will be triggered.
````yaml
trigger:
- master

resources:
- repo: self
````

After this, a few variables are added.

* ````dockerRegistryServiceConnection```` is the identity of the connection to your Container Registry.

* ````imageRepository```` should point to "azure-vote-front". If you were not able to add that in the previous step, do that now.

* ````dockerfilePath```` is where the pipeline expects a Dockerfile. Since we will be using the same Dockerfile as before, we need to change the pipeline to use that file. Add ````application/azure-vote-app```` instead of the default path.


````yaml
variables:

  # Container registry service connection established during pipeline creation
  dockerRegistryServiceConnection: '3b126235-3a6f-1239-8514-10c9cf630123'
  imageRepository: 'azure-vote-front'
  containerRegistry: 'pelithneacr.azurecr.io'
  dockerfilePath: '**/application/azure-vote-app/Dockerfile'
  tag: '$(Build.BuildId)'
  imagePullSecret: 'pelithneacrb820-auth'

  # Agent VM image name
  vmImageName: 'ubuntu-latest'
````

Next comes the first ````stage```` of the pipeline:
````yaml
stages:
- stage: Build
````

It uses some of the variables declared above, to build and push the container to your container registry.

````yaml
steps:
    - task: Docker@2
      displayName: Build and push an image to container registry
      inputs:
        command: buildAndPush
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
````

The last step of the build stage is to upload the kubernetes manifest, to make it available for later stages. Make sure to change the path to the manifest, so that it uses the one in the repository (rather than using the dummy manifest created by Azure Devops)

````yaml
    - upload: application/azure-vote-app
      artifact: application/azure-vote-app/
````

The following ````deploy```` stage, has two jobs. One for pulling the container from the registry, and one for deploying the application to you AKS cluster.

The steps are reasonable self-explanatory, but you need to change (once again) the path to the manifest, to use the one in the repository, that was added into ````$(Pipeline.Workspace)````  by the build stage.

````yaml
manifests: |
                $(Pipeline.Workspace)/application/azure-vote-app/azure-vote-all-in-one-redis.yaml
````

Also, have a look at the container statement:

````yaml
containers: |
                $(containerRegistry)/$(imageRepository):$(tag)
````
What this will do is to replace the container reference in your kubernetes manifest (called ````azure-vote-all-in-one-redis.yaml````) with the container`that was pushed in the build stage.

For this to work, the name of the repository needs to match the name that we are trying to replace it with.

You need to edit your ````azure-vote-all-in-one-redis.yaml```` and change this:

````
containers:
      - name: azure-vote-front
        image: microsoft/azure-vote-front:v1
````

to:

````
containers:
      - name: azure-vote-front
        image: <your ACR name>/azure-vote-front:v1
````


After all the changes, your pipeline should look very similar to the yaml below, except that ````dockerRegistryServiceConnection````, ````containerRegistry```` and ````imagePullSecret```` will be different.

````yaml
# Deploy to Azure Kubernetes Service
# Build and push image to Azure Container Registry; Deploy to Azure Kubernetes Services
# https://docs.microsoft.com/azure/devops/pipelines/languages/docker

trigger:
- master

resources:
- repo: self

variables:

  # Container registry service connection established during pipeline creation
  dockerRegistryServiceConnection: '3b122345-3b6f-48a9-8514-10c9cf630340'
  imageRepository: 'azure-vote-front'
  containerRegistry: 'pelithneacr.azurecr.io'
  dockerfilePath: '**/application/azure-vote-app/Dockerfile'
  tag: '$(Build.BuildId)'
  imagePullSecret: 'pelithneacrb820-auth'

  # Agent VM image name
  vmImageName: 'ubuntu-latest'
  

stages:
- stage: Build
  displayName: Build stage
  jobs:  
  - job: Build
    displayName: Build
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: Docker@2
      displayName: Build and push an image to container registry
      inputs:
        command: buildAndPush
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
          
    - upload: application/azure-vote-app
      artifact: application/azure-vote-app/

- stage: Deploy
  displayName: Deploy stage
  dependsOn: Build

  jobs:
  - deployment: Deploy
    displayName: Deploy
    pool:
      vmImage: $(vmImageName)
    environment: 'k8s2.default'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@0
            displayName: Create imagePullSecret
            inputs:
              action: createSecret
              secretName: $(imagePullSecret)
              dockerRegistryEndpoint: $(dockerRegistryServiceConnection)
              
          - task: KubernetesManifest@0
            displayName: Deploy to Kubernetes cluster
            inputs:
              action: deploy
              manifests: |
                $(Pipeline.Workspace)/application/azure-vote-app/azure-vote-all-in-one-redis.yaml

              imagePullSecrets: |
                $(imagePullSecret)
              containers: |
                $(containerRegistry)/$(imageRepository):$(tag)

````

### Note: If your subscription does not allow you to create Service Principals, then please complete the additional steps described <a href="https://github.com/pelithne/k8s/blob/master/admin-account-access.md">here!</a>


Once you understand what the pipeline is doing (within reason :-) ), click "Save and Run". This will create a new file azure-pipelines.yaml and commit that to your repository, and then execute the pipeline.

After a few seconds, you should see your pipeline starting, and you can drill down into the pipelines to see more details, by clicking on them

<p align="left">
  <img width="40%" hspace="0" src="./media/stages.JPG">
</p>




 Also make sure the Azure Container Registry is updated with a new tag and check the status of the AKS cluster in Azure Cloud Shell.

To make sure the application is running, you need to find the public IP address of the LoadBalancer. Use ````kubectl get svc```` in Azure Cloud shell:

````bash
kubectl get svc
````

Which should give output similar to

````bash
NAME               TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)        AGE
azure-vote-back    ClusterIP      10.0.97.213   <none>          6379/TCP       6m1s
azure-vote-front   LoadBalancer   10.0.98.192   13.73.137.254   80:30824/TCP   6m1s
kubernetes         ClusterIP      10.0.0.1      <none>          443/TCP        4d6h
````

Copy the **Public IP address** of the azure-vote-front service into the address field of your browser to view the web interface of your application.

### 3.6.7. All-In-One

Let's change some code and watch the whole chain roll from Code commit ->Build->Release.

Open the file: azure-vote-app/azure-vote/config_file.cfg (using the editor in Azure Devops) and change the code:

```py
# UI Configurations
TITLE = 'Azure Voting App'
VOTE1VALUE = 'Yellow'  <-- changed
VOTE2VALUE = 'Pink'    <-- changed
SHOWHOST = 'false'
```

Remember to commit the change when you are done.

Click **Pipelines** in the left hand navigation pane to watch the build automatically triggered in Azure DevOps and see how the Release stage starts when the build is done.

<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/devops_build2.jpg">
</p>

The public endpoint of the application should not change, but feel free to verify the IP address by using ````kubectl```` again:

```bash
>kubectl get services
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
azure-vote-back    ClusterIP      10.0.208.112   <none>           6379/TCP      2d23h
azure-vote-front   LoadBalancer   10.0.243.181   13.73.137.254    80:31448/TCP  2d23h
kubernetes         ClusterIP      10.0.0.1       <none>           443/TCP       5d6h

```

Open the public IP-addess, and watch the Yellow and Pink buttons have changed.

<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/devops_final.jpg">
</p>

### 3.6.8. Scale applications in Azure Kubernetes Service (AKS)

In this step you will scale out the pods in the app and try basic pod level scaling.

You can use Azure DevOps to configure the number of pods in the cluster for one service. This is a very easy task since all of your infrastructure of Kubernetes resides within the "azure-vote-all-in-one-redis.yaml" file.

Open the "azure-vote-all-in-one-redis.yaml" file.

Change "replicas" from 1 to 4 and the commit the file. The commit will trigger an automatic build and deploy by running the DevOps pipeline you just defined earlier.

```yaml

apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 4

```

Once you have committed the file, open Azure DevOps and watch the automatic build been triggered.

Once the build is finished you can open **Azure Cloud Shell** now run ````kubectl```` and watch the number of pods. You should now have 4 "azure-vote-front-*" pods.

```bash

>kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
azure-vote-back-5b84769c69-z4r7j    1/1     Running   0          2d16h
azure-vote-front-55fb564887-fgl5t   1/1     Running   0          2m15s
azure-vote-front-55fb564887-s7vgv   1/1     Running   0          2m15s
azure-vote-front-55fb564887-tvjxd   1/1     Running   0          2m15s
azure-vote-front-55fb564887-xwd9t   1/1     Running   0          2d16h
>

```

### 3.6.9. Clean up

The easiest way to clean up your environment, and avoid unnecessary cost, is to remove the entire *Resource Group*.

To do this, go back to Azure Cloud Shell.

Assuming that the Resource Group name is k8s-rg, type the following command:

````azurecli
az group delete -n k8s-rg
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
