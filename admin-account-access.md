# Create pipeline from existing file

In order to access Azure Container Registry (for pushing docker images) without a service principal, you need to create a **Service Connection** for a basic docker registry. Then you need to use that service connection in your pipelines.

Also, for AKS to be able to retrieve images from ACR, you need to create another service connection.

Furthermore, you will not be able to "automatically" generate a pipeline as is described in steps 3.6.4 and 3.6.5. Instead you will start from an existing pipeline definition from the repository.

## Create Service Connections

You need to create one service connection for ACR, and one for AKS.

### Service Connection for ACR

Start by navigating to *Project Settings* at the bottom of the left-hand navigation bar.

From the Project Settings screen, click on *Service connections* in the left-hand navigation bar (in the **Pipelines** section).

Now select **New Service Connection** in the top right corner. 

In the search field write "docker"

<p align="left">
  <img width="40%" hspace="0" src="./media/new-service-connection-docker-registry.PNG">
</p>

Select "Docker Registry" and click **Next**

In the following screen, first select Registry type - Others.

 Then use the credentials from you Azure Container Registry (Access Keys), like this:

<p align="left">
  <img width="40%" hspace="0" src="./media/docker-registry-service-connection.PNG">
</p>

* Docker Registry - Your "Login Server" prepended by https://
* Docker ID - Your "Username"
* Docker Password - One of the generated passwords

Then click **Save** at the bottom of the screen.

### Service Connection for AKS
Create another "New Service Connection". In the search field, type "Kubernetes" and select kubernetes from the search results, then click **Next**.

<p align="left">
  <img width="40%" hspace="0" src="./media/aks-service-connection.PNG">
</p>

In the next screen select **KubeConfig** as Authentication method.

Next, you need to paste your kubeconfig into the KubeConfig-field. To get your kubeconfig, you can run the following command in your cloud shell:

````bash
az aks get-credentials --resource-group <RG name> --name <Cluster name> --file kubeconfig.txt
````

Then copy all the contents of the file kubeconfig.txt and paste that into the Kubeconfig field in Azure Devops.

For example you can use **code** to view the file and copy the content.

````bash
code kubeconfig.txt
````

Finally give a name (like "aks-kubeconfig") to the service connection. You should end up with something looking similar to this:

aks-service-connection-kubeconfig.PNG
<p align="left">
  <img width="40%" hspace="0" src="./media/aks-service-connection-kubeconfig.PNG">
</p>

Finally, click **Verify and Save** to create your Kubernetes service connection.


## Use Service Connections in pipeline

If you can not create service principals, you can not generate a pipeline automatically for deployment to AKS. 

Instead, select to create a new pipeline, and then choose **Existing Azure Pipelines YAML file**

You can reference the Service Connection from your pipeline, simply using their names. For instance, you can create a variable called $aks_sc that references your Kubernetes Service Connection by including this in your yaml pipeline

````yaml
aks_sc: "aks-kubeconfig"
````

Then you can use that variable later in the pipeline by referencing the variable. Like so:

````yaml
kubernetesServiceConnection: $(aks_sc)
````

In order to use the service connections you created, you need to put them into the file azure-pipelines.yaml, which was created automatically for you in a previous step, and which you have already modified a bit.

You should have an azure-pipelines.yaml that looks something like this:

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

In this file you need to replace the dockerServiceConnection, and you need to add your kubernetes service connection

First, change this:
````yaml
  dockerRegistryServiceConnection: '3b122345-3b6f-48a9-8514-10c9cf630340'
````

to
````yaml
dockerRegistryServiceConnection: "the name of your ACR Service Connection
````

Then add this, just below ````dockerRegistryServiceConnection````

````yaml
kubernetesServiceConnection: "the name of your AKS Service Connection"
````

Then add a reference to the kubernetes service connection in both of the two KubernetesManifest tasks, at the end of each task. 

````yaml
task: KubernetesManifest@0
displayName: Create imagePullSecret
inputs:
  action: createSecret
  secretName: $(imagePullSecret)
  dockerRegistryEndpoint: $(dockerRegistryServiceConnection)
  kubernetesServiceConnection: $(kubernetesServiceConnection)  <--- add this!
````

and

````yaml
task: KubernetesManifest@0
displayName: Deploy to Kubernetes cluster
inputs:
  action: deploy
  manifests: |
    $(Pipeline.Workspace)/application/azure-vote-app/azure-vote-all-in-one-redis.yaml
  imagePullSecrets: |
    $(imagePullSecret)
  containers: |
    $(containerRegistry)/$(imageRepository):$(tag)
  kubernetesServiceConnection: $(kubernetesServiceConnection)  <--- add this!

````

You should end up with a pipeline that looks similar to this:

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
  # dockerRegistryServiceConnection: '3b126235-3a6f-48a9-8514-10c9cf630680'
  dockerRegistryServiceConnection: "acr-adminuser-connection"
  kubernetesServiceConnection: "aks-kubeconfig"
  imageRepository: 'azure-vote-front'
  containerRegistry: 'pelithneacr.azurecr.io'
  dockerfilePath: '**/application/azure-vote-app/Dockerfile'
  tag: '$(Build.BuildId)'
  imagePullSecret: 'acr-secret'

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
    environment: 'k8s3'
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
              kubernetesServiceConnection: $(kubernetesServiceConnection)

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
              kubernetesServiceConnection: $(kubernetesServiceConnection)
````

<!-- 

## Access from AKS (Kubernetes)
In order to allow your Kubernetes cluster to access your container registry, you need to create an "Image Pull Secret".

In your cloud shell, perform the following steps.

````bash
ACR=<Your ACR name>.azurecr.io

USER=$(az acr credential show -n $ACR --query="username" -o tsv)

PASSWORD=$(az acr credential show -n $ACR --query="passwords[0].value" -o tsv)

kubectl create secret docker-registry acr-secret \
  --docker-server=$ACR \
  --docker-username=$USER \
  --docker-password=$PASSWORD \
  --docker-email=anything@abc123.net
  ````

This will create a kubernetes secret, named acr-secret, that you will have to include into your deployment manifests.

-->
