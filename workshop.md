# Kubernetes Workshop

This workshop/tutorial contains a number of different sections, each addressing a specific aspect of running workloads (containers) in Kuberntetes, including how to design CI/CD pipelines. 

You will go through the following steps to complete the workshop:
* Use Azure Portal and Azure Cloud Shell
* Setup Azure Container Registry to build and store docker images
* Create Kubernetes Cluster using AKS (Azure Kubernetes Service)
* Deploy application to Kubernetes
* Use Helm to create templated Kubernetes applications
* Use Azure DevOps to setup up build and release pipelines
* and more...
 
## Prerequisites
You need a valid Azure subscription. If you do not have one, you can sign up for a free trial account here: https://azure.microsoft.com/en-us/free/

## Azure Portal
To make sure you are correctly setup with a working subscription, make sure you can log in to the Azure portal. Go to https://portal.azure.com. Once logged in, feel free to browse around a little bit to get to know the surroundings! 

It might be a good idea to keep a tab with the Azure Portal open during the workshop, to keep track of the Azure resources you create. We will almost exlusively use CLI based tools during the workshop, but everything we do will be visible in the portal, and all the resources we create could also be created using the portal.

## Azure Cloud Shell
We will use the Azure Cloud Shell (ACR) throughout the workshop for all our command line needs. This is a web based shell that has all the necessary tools (like kubectl, az cli, helm, etc) pre-installed.

Start cloud shell by typing the address ````shell.azure.com```` into a web browser. If you have not used cloud shell before, you will be asked to create a storage location for cloud shell. Accept that and make sure that you run bash as your shell (not powershell).

#### Protip: You can use ctrl-c to copy text in cloud shell. To paste you have to use shift-insert, or use the right mouse button -> paste. If you are on a Mac, you can use the "normal" Cmd+C/Cmd+V. 

#### Protip II: Cloud Shell will time out after 20 minutes of inactivity. When you log back in, you will end up in your home directory, so be sure to ````cd```` into where you are supposed to be.

## Get the code
The code for this workshop is located in the same respository that you are looking at now. To *clone* the repository to your cloud shell, do this:
````
git clone https://github.com/pelithne/k8s.git
````

Then cd into the repository directory:
````
cd k8s
````


## View the code
Azure Cloud Shell has a built in code editor, which is based on the popular VS Code editor. To view/edit all the files in the repository, run code like this:
````
code .
````

You can navigate the files in the repo in the left hand menu, and edit the files in the right hand window. Use the *right mouse button* to access the various commands (e.g. ````Save```` and ````Quit```` etc).

For instance, you may want to have a look in the ````application/azure-vote-app```` directory. This is where the code for the application is located. Here you can also find the *Dockerfile* which will be used to build your docker image, in a later step.


## Resource Group
All resrouces in Azure exists in a *Resource Group*. The resource group is a "container" for all the resources you create. 

All the resources you create in this workshop will use the same Resource Group. The command below will create a resource group named ````k8s-rg```` in West Europe. 
````
az group create -n k8s-rg -l westeurope
````

## Azure Container Registry
You will use a private Azure Container Registry to *build* and *store* the docker images that you will deploy to Kubernetes. The name of the the ACR needs to be globally unique, and should consist of only lower case letters. You could for instance use your corporate signum.

The reason it needs to be unique, is that your ACR will get a Fully Qualified Domain Name (FQDN), on the form ````<Your unique ACR name>.azurecr.io````

The command below will create the container registry and place it in the Resource Group you created previously (k8s-rg).

````
az acr create --name <your unique ACR name> --resource-group k8s-rg --sku basic
````


### Build images using ACR
Docker images can be built in a number of different ways, for instance by using the docker CLI. Another (and easier!) way is to use *Azure Container Registry Tasks*, which is the approach we will use in this workshop.

The docker image is built using a so called *Dockerfile*. The Dockerfile contains instuctions for how to build the image. Feel free to have a look at the Dockerfile in the repository (once again using *code*):

````
code application/azure-vote-app/Dockerfile
````

As you can see, this very basic Dockerfile will use a *base image* from ````tiangolo/uwsgi-nginx-flask:python3.6-alpine3.8````. 

On top of that base image, it will install ````redis```` and then take the contents of the directory ````./azure-vote```` and copy it into the container in the path ````/app````.

To build the docker container image, cd into the right directory, and use the ````az acr build```` command:
````
cd application/azure-vote-app
az acr build --image azure-vote-front:v1 --registry <your unique ACR name> --file Dockerfile .
````

### List images in registry

To return a list of images that have been built, use the ```az acr repository list``` command:

```azurecli
az acr repository list --name <your unique ACR name> --output table
```

This image will be deployed from ACR to a Kubernetes cluster in the next step.

## Create Kubernetes Cluster
Create an AKS cluster using ````az aks create````. Lets give the cluster the name  ````k8s````, and run the following command (assuming that you named your resource group as suggested in a previous step, ````k8s-rg````):
 
```azurecli
az aks create --resource-group k8s-rg --name k8s --generate-ssh-keys --attach-acr <your unique ACR name> --load-balancer-sku basic --node-count 3 --node-vm-size Standard_B2s
```

The creation time for the cluster can be up to 10 minutes, so this might be a good time for a leg strecher and/or cup of coffee!



## Run applications in Azure Kubernetes Service (AKS)

Kubernetes provides a distributed platform for containerized applications. You build and deploy your own applications and services into a Kubernetes cluster, and let the cluster manage the availability and connectivity. In this step a sample application is deployed into the Kubernetes cluster you created in a previsous step. You will learn how to:

 * Connect/validate towards the AKS Cluster
 * Update Kubernetes manifest files
 * Run an application in Kubernetes
 * Test the application
 

#### Validate towards Kubernetes Cluster

In order to use `kubectl` you need to connect to the Kubernetes cluster, using the following command (which assumes that you have used the naming propsals above):
```console
az aks get-credentials --resource-group k8s-rg --name k8s
```

#### Update the manifest file

You have built a docker image with the sample application, in the Azure Container Registry (ACR). To deploy the application to Kubernetes, you must update the image name in the Kubernetes manifest file to include the ACR login server name. Currently the manifest "points" to a container located in the microsoft repository in *docker hub*.

The manifest file to modify is the one that was downloaded when cloning the repository in a previous step. The location of the manifest file is in the ./k8s/application/azure-vote-app directory

````
cd application/azure-vote-app
````

The sample manifest file from the git repo cloned in the first tutorial uses the login server name of *microsoft*. Open this manifest file with a text editor, such as `code`:

```console
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

Save and Quit.

### Deploy the application

To deploy your application, use the ```kubectl apply``` command. This command parses the manifest file and creates the needed Kubernetes objects. Specify the sample manifest file, as shown in the following example:

```console
kubectl apply -f azure-vote-all-in-one-redis.yaml
```

### Test the application

A kubernetes-service is created which exposes the application to the internet. This process can take a few minutes, in part because the container image needs to be downloaded from ACR to the Kubernetes Cluster. In order to monitor the progress of the download, you can use ``kubectl get pods`` and ``kubectl describe pod``, like this:

First use ``kubectl get pods`` to find the name of your pod:
```consolse
kubectl get pods
```

Then use ``kubectl describe pod`` with the name of your pod:
```consolse
kubectl describe pod <pod name>
```

You can also use ``kubectl describe`` to trouble shoot any problems you might have with the deployment (for instance, a common problem is **Error: ErrImagePull**, which can be caused by incorrect credentials or incorrect address/path to the container in ACR. It can also happen if the Kubernetes Cluster does not have read permission in the Azure Container Registry.

Once your container has been pulled and started, showing state **READY**, you can instead start monitoring the service to see when a public IP address has been created.

To monitor progress, use the `kubectl get service` command with the `--watch` argument:

```console
kubectl get service azure-vote-front --watch
```

The *EXTERNAL-IP* for the *azure-vote-front* service initially appears as *pending*, as shown in the following example:

```
azure-vote-front   10.0.34.242   <pending>     80:30676/TCP   7s
```

When the *EXTERNAL-IP* address changes from *pending* to an actual public IP address, use `CTRL-C` to stop the kubectl watch process. The following example shows a public IP address is now assigned:

```
azure-vote-front   10.0.34.242   52.179.23.131   80:30676/TCP   2m
```

To see the application in action, open a web browser to the external IP address.

![Image of Kubernetes cluster on Azure](./media/azure-vote.png)


## Update an application in Azure Kubernetes Service (AKS)

After an application has been deployed in Kubernetes, it can be updated by specifying a new container image or image version. When doing so, the update is staged so that only a portion of the deployment is concurrently updated. This staged update enables the application to keep running during the update. It also provides a rollback mechanism if a deployment failure occurs.

In this step the sample Azure Vote app is updated. You learn how to:

 * Update the front-end application code
 * Create an updated container image
 * Deploy the updated container image to AKS


### Update an application

Let's make a change to the sample application, then update the version already deployed to your AKS cluster. The sample application source code can be found inside of the *azure-vote* directory. Open the *config_file.cfg* file with an editor, such as `code`:

```console
code azure-vote/config_file.cfg
```

Change the values for *VOTE1VALUE* and *VOTE2VALUE* to different colors. The following example shows the updated color values:

```
# UI Configurations
TITLE = 'Azure Voting App'
VOTE1VALUE = 'Blue'
VOTE2VALUE = 'Purple'
SHOWHOST = 'false'
```

Save and close the file.

### Update the container image

To re-create the front-end image, use ```az acr build``` the same way as before, but make sure to change the version from ````v1```` to ````v2````

```console
az acr build --image azure-vote-front:v2 --registry <your unique ACR name> --file Dockerfile .
```

This will build a new container image, with the code changes you did in the previous step. The image will be stored in ACR with the same name as before, but with a new version (v2).



### Deploy the updated application

To ensure maximum uptime, multiple instances of the application pod must be running. Verify the number of running front-end instances with the ```kubectl get pods``` command:

```
$ kubectl get pods

NAME                               READY     STATUS    RESTARTS   AGE
azure-vote-back-217588096-5w632    1/1       Running   0          10m
azure-vote-front-233282510-b5pkz   1/1       Running   0          10m
azure-vote-front-233282510-dhrtr   1/1       Running   0          10m
azure-vote-front-233282510-pqbfk   1/1       Running   0          10m
```

To update the application, you can use  ```kubectl set``` and specify the new application version, but the preferred way is to edit the kubernetes manifest to change the version.

Open the sample manifest file `azure-vote-all-in-one-redis.yaml` and change `image:` from `<Your ACR Name>.azurecr.io/<unique name>/azure-vote-front:v1` to `<Your ACR Name>.azurecr.io/<unique name>/azure-vote-front:v2` on line 47.

Change
 ```yaml
    spec:
      containers:
      - name: azure-vote-front
        image: <Your ACR Name>.azurecr.io/<unique name>/azure-vote-front:v1
  ```

To
  ```yaml
    spec:
      containers:
      - name: azure-vote-front
        image: <Your ACR Name>.azurecr.io/<unique name>/azure-vote-front:v2
  ```

And the run:

````
kubectl apply -f azure-vote-all-in-one-redis.yaml
```` 


To monitor the deployment, use the ```kubectl get pods``` command. As the updated application is deployed, your pods are terminated and re-created with the new container image.

```console
kubectl get pods
```

The following example output shows pods terminating and new instances running as the deployment progresses:

```
$ kubectl get pods

NAME                               READY     STATUS        RESTARTS   AGE
azure-vote-back-2978095810-gq9g0   1/1       Running       0          5m
azure-vote-front-1297194256-tpjlg  1/1       Running       0          1m
azure-vote-front-1297194256-tptnx  1/1       Running       0          5m
azure-vote-front-1297194256-zktw9  1/1       Terminating   0          1m
```

### Test the updated application

To view the updated application, first get the external IP address of the `azure-vote-front` service:

```console
kubectl get service azure-vote-front
```

Now open a local web browser to the IP address.

![Image of Kubernetes cluster on Azure](./media/vote-app-updated-external.png)




## HELM!
Helm is an open-source packaging tool that helps you install and manage the lifecycle of Kubernetes applications. Similar to Linux package managers such as APT and Yum, Helm is used to manage Kubernetes charts, which are packages of preconfigured Kubernetes resources.

In this exercise you will use Helm to deploy the same application you just deployed using ````kubectl````.

### Using Helm
Your development VM already has helm installed, but you need to initialize helm, so that you can use it towards your Kubernetes cluster. 

To deploy a the server side component of **Helm** named **Tiller** into an AKS cluster, use the ````helm init```` command. 
````
helm init
````

If no error are reported, you are good to go. If you want to, you can check if helm works by running the ````helm version````command:
````
helm version
````

Client and server versions should match, and you should get output similar to:

````
Client: &version.Version{SemVer:"v2.11.0", GitCommit:"2e55dbe1fdb5fdb96b75ff144a339489417b146b", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.11.0", GitCommit:"2e55dbe1fdb5fdb96b75ff144a339489417b146b", GitTreeState:"clean"}
````

### Helm and Azure Vote!
The repository that you cloned in the beginning of the tutorial (or during preparations) contains a **helm chart** to deploy the application using **Helm**. 

Start by changing the directory to where the **helm chart** is located.
````
cd application/azvote-helmchart
 ````

Then you need to update your helm chart to point to the container image you created earlier in the **Azure Container Registry**. This is done in the file ````deployments.yaml```` located in ````azvote-helmchart/templates/````. This is essentially the same thing you did earlier in you kubernetes manifest .yaml file.

Change the line:
````
image: microsoft/azure-vote-front:v1
````
to
````
image: <your unique ACR name>.azurecr.io/azure-vote-front:v1
````

### Deploy Azure-vote app using Helm


Deploying the azure-vote app using helm can be done with this command
````
helm install .
````

After some time, you should be able to access the vote app in your browser. To find out when it is available, use ````kubectl get services````

### Helm Upgrade
One of the advantages with Helm is that configuration values can be separated from values that are more static. Have a look at the file ````values.yaml```` which contains configurations that we can change dynamically. For example, you can upgrade your current deployment and give it new configuration values from the command line.

To modify the application, you need to know the *release name*. Use **helm list** to find out:
````
helm list
````


This will, once again, give output similar to this (but with a different **NAME**):
````
NAME            REVISION        UPDATED                         STATUS          CHART                   APP VERSION     NAMESPACE
warped-elk      1               Thu Mar 21 15:14:45 2019        DEPLOYED        azure-vote-0.1.0                        default
````

Now, you can modify the application with the ````helm upgrade````command, and send some new configration values to it:
````
helm upgrade warped-elk . --set title="Beer" --set value1="Industry Lager" --set value2="Cask Ale"
````

Much better!


<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/beer4.png">
</p>

### Install Wordpress
One way to look at helm, is as a packet manager. You can use it to easily search for and install applications. To look for exising applications, use ```` helm search````

````
helm search 
````

This will give you a (long) list of applications available in the default helm repository. 

Now, you could for instance install wordpress in your AKS cluster by running a single command:
````
helm install stable/wordpress
````
It takes a minute or two for the EXTERNAL-IP address of the Wordpress service to be populated and allow you to access it with a web browser. To find the ip address, you can use ````kubectl```` just like before:
````
kubectl get services
````
Now you should be able to browse to your newly created Wordpress instance, by entering the public IP address into your browser.

### Cleaning up
To keep things tidy in the cluster, delete the applications you just deployed with helm

First you need to know the release names that you deployed. To easily find that you can use the ````helm list```` command. You can also find the name at the top of the output from the ````helm install```` command.

````
helm list
````
 The output will look something like:
````
NAME            REVISION        UPDATED                         STATUS          CHART                   APP VERSION     NAMESPACE
dull-seastar    1               Thu Mar 21 14:34:47 2019        DEPLOYED        wordpress-5.1.2         5.0.3           default
warped-elk      1               Thu Mar 21 15:14:45 2019        DEPLOYED        azure-vote-0.1.0                        default
````

Now you can delete the deployments with ````helm delete```` for the *NAME* listed:
````
helm delete dull-seastar
helm delete warped-elk
````

This will remove all the pods and services, and other resources related to the applications.


## Azure DevOps with AKS

<p align="left">
  <img width="65%" height="65%" hspace="0" src="./media/index-hero.jpg">
</p>


In this step you will make a CI/CD pipeline for the AKS cluster. You will learn how to:  

* Automatically build an application on check-in 
* Automatically build the docker container for the application
* Autamtically deploy the docker container to AKS


### Register an account at Azure DevOps

You can create a free Azure DevOps account at: <https://azure.microsoft.com/en-us/services/devops/>. Azure DevOps is SaaS service from Microsoft. You need a Microsoft account to get started. If you do not have one you can create a free account here: <https://account.microsoft.com/account?lang=en-us>

Once you have logged in to your Azure Devops account, you will create a **project**. Give the project a name, like "k8s"

You should now have project like this:

<p align="left">
  <img width="65%" hspace="0" src="./media/devopsproject.JPG">
</p>


The left hand side shows you:

* **Overview** - overview of the Azure DeOps project like wiki, dashboards and more
* **Boards** - supporting a Agile workmethology with sprints and backlog
* **Repos** - your source code
* **Pipelines** - build and release - the essance of CI/CD
* **TestPlans** - testing overview
* **Artifacts** - your build artifacts that you might share in other projects, like nuget packages and such.

### Create your Repository
During this step we will import the same repository we have been working with in previous steps, but this time we will import it into Azure Devops instead.

To do this, start by clicking on *Repos*.

Select "import a repository"
<p align="left">
  <img width="40%" height="40%" hspace="0" src="./media/import-repo-1.png">
</p>

Then type in the URL to the repository (this is becoming familiar by now... :-) ): https://github.com/pelithne/k8s
<p align="left">
  <img width="40%" height="40%" hspace="0" src="./media/import-repo-2.png">
</p>

When the import is finished, you will have your own version of the repository in Azure Devops. The parts that you will work with in this part of the tutorial are located in the ````application/azure-vote-app```` folder.

In order for for Azure Devops to use the container that you created in previous steps, you (once again!) need to update the Kubernetes Manifest. Navigate to the manifest named ````azure-vote-all-in-one-redis.yaml```` in the application folder.

### Note: The repo you imported is the "original" repo, which does not have any of the changes you made before, so you start from "scratch".

You can edit the file in your browser by selecting **edit** in the top toolbar. Scroll down in the file, and change 

````
image: microsoft/azure-vote-front:v1
````
to

````
image: <your unique ACR name>.azurecr.io/azure-vote-front:v1
````

### Connect Azure and Azure DevOps

Make sure you are using the same account in both Azure and Azure DevOps (same email addess).

In Azure DevOps, you need to create two service connections from Azure DevOps to Azure:

1. Docker Service Registry Connection - enables deployment from the pipeline to a docker registry. In our case, the Docker Registry is the Azure Container Registry you created in a previous step.
2. Azure Kubernetes Service

To create the service connections, click on **Project Settings** at the bottom of the left hand navigation panel. Then go to **Service Connections**. 

Select "New service connection" and write "Docker Registry" in the search field. Make sure ````Docker Registry```` is selected and press ````next````.  Now, choose Azure Container Registry as ````registry type```` and select the ACR that you created earlier in the workshop. Finally give the connection a nice name.  This will bind a conneciton from Azure DevOps to your container registry to build and save your images:

<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/serviceconnection_acr.JPG">
</p>

Create a second servcie connection for the AKS cluster using the same method. Hint: write "Kubernetes" in the search field to find the ````kubernetes```` connection type.
 
<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/devops_aks_srv.jpg">
</p>




### Create Build and Release Pipelines

We are going to:

* Create a build pipeline
* Create a release pipeline that is chained to the build pipeline

There are two ways to create pipelines, the "old way" and the "new way". We are going to do it the "new way" since its an improvement and that is the direction Azure DevOps is going in.

The improvement is to have the entire pipeline defined as code, in your repository. The feature is currently in preview and in order to use it you need to enable multistage pipelines, read this: <https://devblogs.microsoft.com/devops/whats-new-with-azure-pipelines>

To enable this preview feature click on your account icon in the top right corner, and select "Preview features":

<p align="left">
  <img width="45%" height="45%" hspace="0" src="./media/devops_preview.JPG">
</p>

Enable "Multi-stage pipelines":

<p align="left">
  <img width="55%" height="55%" hspace="0" src="./media/devops_multi.jpg">
</p>


Creating a new Pipeline:

Go to Pipelines and create a new pipeline:

<p align="left">
  <img width="85%" hspace="0" src="./media/new_pipeline.JPG">
</p>

Choose "Azure Repos Git" and then select the repository that you previously imported to Azure DevOps.


<p align="left">
  <img width="40%" hspace="0" src="./media/pipeline_1.JPG">
</p>

Choose "Existing Azure Pipelines YAML file" and then select the path ````/application/azure-pipelines.yml```` and press **Continue**

<p align="left">
  <img width="50%" height="50%" hspace="0" src="./media/azure-pipelines.png">
</p>

Run the pipeline and see the steps in the build. It will fail since because it is currently not complete.

#### Build Pipeline

To make a build we need to follow the same steps you have done manually:

1. Go to your new Pipeline
2. Clean the file so there is no text inside
3. Look at the exmple yaml below (explaination of multistage: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml). 

We want to have a Build and Release pipeline chained together. The example YAML below explains the relationships between the different actions.

Copy the yaml-sceleton below into the pipeline and notice the structure:

```yaml

trigger:
- master

pool:
  vmImage: 'Ubuntu-16.04'

stages:

- stage: A_stage
  jobs:
   - job: A_job
     steps:
      - bash: echo "A"

- stage: B_stage
  jobs:
   - job: B_job
     steps:
      - bash: echo "B"

```

With this notation we can create both build and release in the same file. Stages could be for example: "build this app", "run these tests", and "deploy to pre-production" are good examples of stages.

* trigger: will automatically trigger on checkin in master branch

* pool: the vm type the build will be conducted on

* stage : this would normally be for example "Build"

* jobs: group of several "job"

* job: group of "steps" to achive the job

* steps: atomic actions

Save the pipeline and watch the "A_stage" and "B_stage" run in sequence below when you save and run the pipeline, click on the stages to see live informaiton:

Notice that you only have to save the pipeline for it to run, this is due to the fact of the "trigger" element, that says you are triggering on changes on master branch:

```yaml
trigger:
- master
```

Running the pipeline:

<p align="left">
  <img width="80%" height="80%" hspace="0" src="./media/devops_stages.jpg">
</p>

Open the pipeline again and edit it. Lets start implementing the "Development stage". Rename the stage to "Build_Development"

On the right hand search for "Docker" and fill in the details. Make sure your cursor is positioned after "steps" then press "Add".

<p align="left">
  <img width="40%" hspace="0" src="./media/devops_docker.jpg">
</p>

In the yaml file you fill find the following:

* task: the actual build task, in this case Docker build, more information about the task can be found: <https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/build/docker?view=azure-devops>

* containerRegistry: your Azure Container Registy Service Connection

* repository: the repository inside Azure Container Registy to store your Docker image

* command: both build and push the image

* Dockerfile: the path and name to the Dockerfile. '**' will start searching in the directory specified

* tags: the Docker build tag to be appended. $(Build.BuildId) is a predefined environment variable in Azure DevOps that is incremented at every build, more information about Azure DeOps built in environment variables can be found here: <https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml>


Make sure you add the "tags: $(Build.BuildId)" otherwise the build will not update the tag of the image. Also, the tags: $(Build.BuildId) is unique for this build and in the releas stage, we need to refer to this tag in order for the right image to be deployed.

The final yaml file should looke similar to this:

```yaml
trigger:
- master

pool:
  vmImage: 'Ubuntu-16.04'


stages:
- stage: 'Build_Development'
  jobs:
  - job:
    steps:
    - task: Docker@2
      inputs:
        containerRegistry: 'Azure Container Registry'
        repository: 'azure-vote-front'
        command: 'buildAndPush'
        Dockerfile: '**/Dockerfile'
        tags: $(Build.BuildId)

- stage: B_stage
  jobs:
   - job: B_job
     steps:
      - bash: echo "B"
```

Save and run the pipeline. Make sure it build successfully.

<p align="left">
  <img width="65%" hspace="0" src="./media/devops_build.jpg">
</p>

Notice the change of the first stage and also make sure the build was ok by looking into the details of the stage.

After doing the build, we have our image and build tag set. The only thing we need now is to deploy the aaplication to AKS. Do this by adding a release stage to the pipeline yaml. Make sure to use the specific image name and especially the tag just like we did manually earlier.

Open the pipeline and edit the stage B to including the release. The release is done by manipulating the applicaiton yaml and deployed to AKS. To achive this search for "Manifest" and add the task:

<p align="left">
  <img width="40%" hspace="0" src="./media/devops_manifest2.jpg">
</p>

Make sure the alignment of the task comes under "steps". Also we are adding condition: succeeded('Build_Development') which indicates that the stage is **only** run if and only if the "Build_Development" stage was successfull. You can read more about the conditions here: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml#conditions

**Also note the "containers" part** which will update the actual image and tag and append the **$(Build.BuildId)** to the end of the image tag to be deployed.

The Kubernetes manifest task can be read here: https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/kubernetes-manifest?view=azure-devops

The final pipeline should look similar to this:

```yaml
trigger:
- master

pool:
  vmImage: 'Ubuntu-16.04'


stages:
- stage: 'Build_Development'
  jobs:
  - job:
    steps:
    - task: Docker@2
      inputs:
        containerRegistry: 'Azure Container Registry'
        repository: k8s/azure-vote-front
        command: 'buildAndPush'
        Dockerfile: '**/Dockerfile'
        tags: $(Build.BuildId)

# stage 'Release to Development' runs if 'Build Development' succeeds
- stage: 'Release_to_Development'
  condition: succeeded('Build_Development')
  jobs:
  - job:
    steps:
    - task: KubernetesManifest@0
      inputs:
        action: 'deploy'
        kubernetesServiceConnection: 'AKS'
        namespace: 'default'
        manifests: 'application/azure-vote-app/azure-vote-all-in-one-redis.yaml'
        containers: 'arraacrcicd.azurecr.io/azure-vote-front:$(Build.BuildId)'
```

Make sure the pipeline is building and releasing successfully and make sure the Azure Container Registry is updated with a new tag. Also check the status of the AKS cluster.

### All-In-One

Let's change some code and watch the whole chain roll from Code commit ->Build->Release. 

Open the file: azure-vote-app/azure-vote/config_file.cfg and change the code:

```py
# UI Configurations
TITLE = 'Azure Voting App'
VOTE1VALUE = 'Yellow'  <-- changed
VOTE2VALUE = 'Pink'    <-- changed
SHOWHOST = 'false'
```

Watch the Build and Release pipeline finalize.

<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/devops_build2.jpg">
</p>

Watch the build automatically triggered in Azure DevOps. 


To see the change in the application we need the public endpoint of the application. Run the kubectl command to get the service endpoint:

```console
>kubectl get services
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
azure-vote-back    ClusterIP      10.0.208.112   <none>           6379/TCP      2d23h
azure-vote-front   LoadBalancer   10.0.243.181   52.233.236.177   80:31448/TCP  2d23h
kubernetes         ClusterIP      10.0.0.1       <none>           443/TCP       5d6h

```

Open the public IP-addess, in this case 52.233.236.177 and watch the Yellow and Pink buttons have changed.


<p align="left">
  <img width="75%" height="75%" hspace="0" src="./media/devops_final.jpg">
</p>


## Scale applications in Azure Kubernetes Service (AKS)

In this step you will scale out the pods in the app and try pod autoscaling.

* Use Azure DeOps to scale number of pods
* Manually scale Kubernetes pods that run your application
* Configure autoscaling pods that run the app front-end

### Azure DevOps to scale pods

You can use Azure DeOps to configure the number of pods in the cluster for one service. This is a very easy task since all of your infrastructure of Kubernetes resides within the "azure-vote-all-in-one-redis.yaml" file.

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

<p align="left">
  <img width="85%" hspace="0" src="./media/devops_cd.jpg">
</p>


Once the build is finished you can now run kubectle and watch the number of pods, you should now have 4 "azure-vote-front-*" pods.

```console

>kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
azure-vote-back-5b84769c69-z4r7j    1/1     Running   0          2d16h
azure-vote-front-55fb564887-fgl5t   1/1     Running   0          2m15s
azure-vote-front-55fb564887-s7vgv   1/1     Running   0          2m15s
azure-vote-front-55fb564887-tvjxd   1/1     Running   0          2m15s
azure-vote-front-55fb564887-xwd9t   1/1     Running   0          2d16h
>

```


### Autoscale pods

Kubernetes supports horizontal pod autoscaling to adjust the number of pods in a deployment depending on CPU utilization or other select metrics. The metrics-server is used to provide resource utilization to Kubernetes, and is automatically deployed in AKS clusters versions 1.10 and higher. 

To use the autoscaler, your pods must have CPU requests and limits defined. In the `azure-vote-front` deployment, the front-end container requests 0.25 CPU, with a limit of 0.5 CPU. The settings look like:

```yaml
resources:
  requests:
     cpu: 250m
  limits:
     cpu: 500m
```

The following example uses the ```kubectl autoscale``` command to autoscale the number of pods in the *azure-vote-front* deployment. If CPU utilization exceeds 50%, the autoscaler increases the pods up to a maximum of 10 instances. In this case however, with almost no load on your application, it will instead scale down to the minimum number of pods (1).

```console
kubectl autoscale deployment azure-vote-front --cpu-percent=50 --min=1 --max=10
```

To see the status of the autoscaler, use the ```kubectl get hpa``` command as follows:

```
$ kubectl get hpa

NAME               REFERENCE                     TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
azure-vote-front   Deployment/azure-vote-front   0% / 50%   3         10        3          2m
```


After a few minutes, with minimal load on the Azure Vote app, the number of pod replicas will decrease automatically. You can use `kubectl get pods` again to see the unneeded pods being removed.


### Cleaning up
Before moving on to the next step, it is a good idea to delete the resources you created. One way of doing that is to manualy delete the deployments. First find out what deployments you have:
````
kubectl get deployments
````
Find the deployment names, and then do ````kubectl delete deployment```` like this:
````
kubectl delete deployment azure-vote-front azure-vote-back

````
Then find the services:

```` 
kubectl get services

````

And delete those as well:
````
kubectl delete services azure-vote-front azure-vote-back
````