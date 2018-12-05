# Azure Kubernetes Service (AKS) Workshop

Welcome to this Azure Kubernetes Workshop instruction. The workshop contains a number of different sections, each addressing a specific aspect of running docker containers locally and in the cloud. 

## Running Docker Containers locally

In this first step in the tutorial, you will prepare a multi-container application for use in your local docker environment. Existing tools such as Git and Docker are used to locally build and test an application. You will learn how to:

 * Clone a sample application source from GitHub
 * Create a container image from the sample application source
 * Test the multi-container application in a local Docker environment

Once completed, the following application runs in your local development environment:

![Image of Kubernetes cluster on Azure](./media/azure-vote.png) 


### Get application code

The sample application used in this tutorial is a basic voting app. The application consists of a front-end web component and a back-end Redis instance. The web component is packaged into a custom container image. The Redis instance uses an unmodified image from Docker Hub.

Use```git``` to clone the sample application to your development environment:

```console
git clone https://github.com/pelithne/azure-voting-app-redis.git
```

Change directories so that you are working from the cloned directory.

```console
cd azure-voting-app-redis
```

Inside the directory is the application source code, a pre-created Docker compose file, and a Kubernetes manifest file. These files are used throughout the tutorial.

### Create a docker network

### Note: if you are using WSL, and if you have not installed docker there, you need to use `docker.exe` on the command line. 

This network will be used by the containers that are started below, to allow them to communicate with each other

```console
 docker network create mynet
```

### Create container images

Build azure-vote-front, using the Dockerfile located in ./azure-vote. This will create two images, one base image and one for the azure-vote-front.
```console
 docker build -t azure-vote-front ./azure-vote
```
Please review ./azure-vote/Dockerfile to get an understanding for container images get created based on this file.

### Run the application locally
First start the redis cache container. The command below will start a container with name "azure-vote-back" using the official redis docker container. If this is the first time the command is executed, the image will be downloaded to your computer (this can take a while). 

Note that in the command below, the container is instructed to use the network ```mynet``` that was created in a previous step.
```console
docker run --name azure-vote-back --net mynet -d redis
```

Now start the frontend container. The command below will start a container with name "azure-vote-front" using the previously built container. Additionally port 8080 will be exposed (so that the application can be accessed locally using a browser) and insert an environment variable ("REDIS") that will be used to connect to the redis cache.
```console
docker run --name azure-vote-front -d -p 8080:80 --net mynet -e "REDIS=azure-vote-back" azure-vote-front
```

When completed, use the ```docker images``` command to see the created images. Three images have been downloaded or created. The *azure-vote-front* image contains the front-end application and uses the `nginx-flask` image as a base. The `redis` image is used to start a Redis instance.

```
$ docker images

REPOSITORY                   TAG        IMAGE ID            CREATED             SIZE
azure-vote-front            latest      e9488bdfb34b        3 minutes ago       708MB
redis                       latest      5958914cc558        6 days ago          94.9MB
jetpac33/azure-vote-front   v2          e2f39950cbf1        13 months ago       708MB
```

To see the running containers, run ```docker ps```:

```
$ docker ps

CONTAINER ID        IMAGE             COMMAND                  CREATED             STATUS              PORTS                           NAMES
82411933e8f9        azure-vote-front  "/usr/bin/supervisord"   57 seconds ago      Up 30 seconds       443/tcp, 0.0.0.0:8080->80/tcp   azure-vote-front
b68fed4b66b6        redis             "docker-entrypoint..."   57 seconds ago      Up 30 seconds       0.0.0.0:6379->6379/tcp          azure-vote-back
```

### Test application locally

To see the running application, enter http://localhost:8080 in a local web browser. The sample application loads, as shown in the following example:

![Image of Kubernetes cluster on Azure](./media/azure-vote.png)

### Clean up resources

Now that the application's functionality has been validated, the running containers can be stopped and removed. Do not delete the container images - in the next step, the *azure-vote-front* image will be uploaded to an Azure Container Registry.

Stop and remove the container instances:

```console
docker stop azure-vote-front azure-vote-back
docker rm azure-vote-front azure-vote-back
```

## Using the Azure Container Registry

We have created a container registry that can be used during the workshop. The name of this registry is `crcollectorworkshop`

### Login to Container Registry

In order to use the registry, you must first login with your credentials.

Use the ```az acr login``` command and provide the name given to the container registry.

```azurecli
az acr login --name crcollectorworkshop
```

The command returns a *Login Succeeded* message once completed.

### Tag a container image

To see a list of your current local images, once again use the ```docker images``` command:

```
$ docker images

REPOSITORY                   TAG                 IMAGE ID            CREATED             SIZE
azure-vote-front             latest              e9488bdfb34b        3 minutes ago       708MB
redis                        latest              5958914cc558        6 days ago          94.9MB
jetpac33/azure-vote-front    v2                  e2f39950cbf1        13 months ago       708MB
```

To use the *azure-vote-front* container image with ACR, the image needs to be tagged with the login server address of your registry. This tag is used for routing when pushing container images to an image registry. The login server will be: `crcollectorworkshop.azurecr.io`

Also, since you are using a shared repository, you need to tag your image with a unique name to distinguish it from other users containers. Select a name that is very likely to be unique amont the workshop participants.

Finally, to indicate the image version, add *:v1* to the end of the image name.

The resulting command:

```console
docker tag azure-vote-front crcollectorworkshop.azurecr.io/<unique name>/azure-vote-front:v1
```

To verify the tags are applied, run ```docker images``` again. An image is tagged with the ACR instance address and a version number.

```
$ docker images
azure-vote-front                                                latest              e9488bdfb34b        3 minutes ago       708MB
crcollectorworkshop.azurecr.io/unique-name/azure-vote-front     latest              e9488bdfb34b        3 minutes ago       708MB
redis                                                           latest              5958914cc558        6 days ago          94.9MB
jetpac33/azure-vote-front                                       v2                  e2f39950cbf1        13 months ago       708MB
```

### Push images to registry

You can now push the *azure-vote-front* image to your ACR instance. Use ```docker push``` as follows:

```console
docker push crcollectorworkshop.azurecr.io/<unique name>/azure-vote-front:v1
```

It may take a few minutes to complete the image push to ACR.

### List images in registry

To return a list of images that have been pushed to your ACR instance, use the ```az acr repository list``` command:

```azurecli
az acr repository list --name crcollectorworkshop --output table
```

The following example output lists the *azure-vote-front* images as available in the registry. The list will (eventually) contain images from all workshop participants: 

```
Result
----------------
unique-name/azure-vote-front
another-unique-name/azure-vote-front
yet-another-unique-name/azure-vote-front
```

To see the tags for a specific image, use the ```az acr repository show-tags``` command as follows:

```azurecli
az acr repository show-tags --name crcollectorworkshop --repository <unique name>/azure-vote-front --output table
```

The following example output shows the *v1* image tagged in a previous step:

```
Result
--------
v1
```

You now have a container image that is stored in a private Azure Container Registry instance. This image is deployed from ACR to a Kubernetes cluster in the next step.

## Run applications in Azure Kubernetes Service (AKS)

Kubernetes provides a distributed platform for containerized applications. You build and deploy your own applications and services into a Kubernetes cluster, and let the cluster manage the availability and connectivity. In this step a sample application is deployed into a Kubernetes cluster. You learn how to:

 * Update a Kubernetes manifest files
 * Run an application in Kubernetes
 * Test the application

### Validate towards Kubernetes Cluster
In order to use `kubectl` you need to connect to the Kubernetes cluster, using the following command:
```console
az aks get-credentials --resource-group CollectorWorkshop --name aks-workshop
```

### Kubernetes Namespaces
### NOTE: It is important that you can create and use your namespace, so make sure this step i successful before continuing!
A namespace is like a tennant in the cluster. Each namespace works like a "virtual cluster" which allows users to interact with the cluster as though it was private to them.

To create a namespace, run the following command, and give it a name that you think will be unique within the cluster.
```console
kubectl create namespace <your unique namespace name>
```
Then set the default namespace for your current session
```console
kubectl config set-context aks-workshop --namespace=<your unique namespace name>
```
This is mainly for convenience. You can skip this step, but then you have to include a ´--namespace´ flag on all kubectl commands.

You can verify that your newly created namespace is the active one:
```console
kubectl config view | grep namespace
```

### Update the manifest file

You have uploaded a docker image with the sample application, to an Azure Container Registry (ACR). To deploy the application, you must update the image name in the Kubernetes manifest file to include the ACR login server name. The manifest file to modify is the one that was downloaded when cloning the repository in a previous step. The location of the manifest file is in the ./azure-vote directory

The sample manifest file from the git repo cloned in the first tutorial uses the login server name of *microsoft*. Open this manifest file with a text editor, such as `vi`:

```console
vi azure-vote-all-in-one-redis.yaml
```

Replace *microsoft* with your ACR login server name and your `<unique name>`. The image name is found on line 47 of the manifest file. The following example shows the default image name:

```yaml
containers:
- name: azure-vote-front
  image: microsoft/azure-vote-front:v1
```

Provide the ACR login server and `<unique name>` name so that your manifest file looks like the following example:

```yaml
containers:
- name: azure-vote-front
  image: crcollectorworkshop.azurecr.io/<unique name>/azure-vote-front:v1
```

Please also take some time to study the manifest file, to get a better understanding of what it contains.

Save and close the file.

## Deploy the application

To deploy your application, use the ```kubectl apply``` command. This command parses the manifest file and creates the defined Kubernetes objects. Specify the sample manifest file, as shown in the following example:

```console
kubectl apply -f azure-vote-all-in-one-redis.yaml
```

The Kubernetes objects are created within the cluster, as shown in the following example:

```
$ kubectl apply -f azure-vote-all-in-one-redis.yaml

deployment "azure-vote-back" created
service "azure-vote-back" created
deployment "azure-vote-front" created
service "azure-vote-front" created
```

### Test the application

A kubernetes-service is created which exposes the application to the internet. This process can take a few minutes. To monitor progress, use the `kubectl get service` command with the `--watch` argument:

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

If the application did not load, it might be due to an authorization problem with your image registry. To view the status of your containers, use the `kubectl get pods` command. If the container images cannot be pulled, see [allow access to Container Registry with a Kubernetes secret](https://docs.microsoft.com/azure/container-registry/container-registry-auth-aks#access-with-kubernetes-secret).

In the next step you will learn how to use Kubernetes scaling features.


## Scale applications in Azure Kubernetes Service (AKS)

In this step you will scale out the pods in the app and try pod autoscaling. 

 * Scale the Kubernetes nodes
 * Manually scale Kubernetes pods that run your application
 * Configure autoscaling pods that run the app front-end


### Manually scale pods

When the Azure Vote front-end and Redis instance were deployed in previous steps, a single replica was created. To see the number and state of pods in your cluster, use the `kubectl get` command as follows:

```console
kubectl get pods
```

The following example output shows one front-end pod and one back-end pod:

```
NAME                               READY     STATUS    RESTARTS   AGE
azure-vote-back-2549686872-4d2r5   1/1       Running   0          31m
azure-vote-front-848767080-tf34m   1/1       Running   0          31m
```

It is possible to use the ```kubectl scale``` command to scale the number of pods. However, the preferred way is to edit the kubernetes manifest to increase the number of replicas.

Open the sample manifest file `azure-vote-all-in-one-redis.yaml` from the previously cloned git repo and change `replicas` from 1 to 3, on line 34.
 ````
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 1
  ````

To

  ````
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 3
  ````
And the run:

````
kubectl apply -f azure-vote-all-in-one-redis.yaml
````

Run `kubectl get` again to verify that Kubernetes creates the additional pods. After a minute or so, the additional pods are available in your cluster:

```console
$ kubectl get pods

                                    READY     STATUS    RESTARTS   AGE
azure-vote-back-2606967446-nmpcf    1/1       Running   0          15m
azure-vote-front-3309479140-2hfh0   1/1       Running   0          3m
azure-vote-front-3309479140-bzt05   1/1       Running   0          3m
azure-vote-front-3309479140-hrbf2   1/1       Running   0          15m
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

The following example uses the ```kubectl autoscale``` command to autoscale the number of pods in the *azure-vote-front* deployment. If CPU utilization exceeds 50%, the autoscaler increases the pods up to a maximum of 10 instances:

```console
kubectl autoscale deployment azure-vote-front --cpu-percent=50 --min=3 --max=10
```

To see the status of the autoscaler, use the ```kubectl get hpa``` command as follows:

```
$ kubectl get hpa

NAME               REFERENCE                     TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
azure-vote-front   Deployment/azure-vote-front   0% / 50%   3         10        3          2m
```

After a few minutes, with minimal load on the Azure Vote app, the number of pod replicas decreases automatically to three. You can use `kubectl get pods` again to see the unneeded pods being removed.




## Update an application in Azure Kubernetes Service (AKS)

After an application has been deployed in Kubernetes, it can be updated by specifying a new container image or image version. When doing so, the update is staged so that only a portion of the deployment is concurrently updated. This staged update enables the application to keep running during the update. It also provides a rollback mechanism if a deployment failure occurs.

In this step the sample Azure Vote app is updated. You learn how to:

 * Update the front-end application code
 * Create an updated container image
 * Push the container image to Azure Container Registry
 * Deploy the updated container image


### Update an application

Let's make a change to the sample application, then update the version already deployed to your AKS cluster. The sample application source code can be found inside of the *azure-vote* directory. Open the *config_file.cfg* file with an editor, such as `vi`:

```console
vi azure-vote/azure-vote/config_file.cfg
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

To re-create the front-end image and test the updated application, use ```docker build``` the same way as in a previous step. 

```console
docker build -t azure-vote-front ./azure-vote
```

### Test the application locally

To verify that the updated container image shows your changes, open a local web browser to http://localhost:8080.

![Image of Kubernetes cluster on Azure](./media/vote-app-updated.png)

The updated color values provided in the *config_file.cfg* file are displayed on your running application.

### Tag and push the image

To correctly use the updated image, tag the *azure-vote-front* image with the login server name of your ACR registry, and your `<unique name>`.

Use ```docker tag``` to tag the image and update the image version to *:v2* as below. 

```console
docker tag azure-vote-front crcollectorworkshop.azurecr.io/<unique name>/azure-vote-front:v2
```

Now use ```docker push``` to upload the image to your registry. If you experience issues pushing to your ACR registry, ensure that you have run the ```az acr login``` command.

```console
docker push crcollectorworkshop.azurecr.io/<unique name>/azure-vote-front:v2
```

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

If you do not have multiple front-end pods, scale the *azure-vote-front* deployment as per the instructions in the previous section (by changing `replicas` in `azure-vote-all-in-one-redis.yaml`)


To update the application, you can use  ```kubectl set``` and specify the new application version, but the preferred way is to edit the kubernetes manifest to change the version .

Open the sample manifest file `azure-vote-all-in-one-redis.yaml` and change `image:` from `crcollectorworkshop.azurecr.io/<unique name>/azure-vote-front:v1` to `crcollectorworkshop.azurecr.io/<unique name>/azure-vote-front:v2` on line 47.
 ````
    spec:
      containers:
      - name: azure-vote-front
        image: crcollectorworkshop.azurecr.io/pelithne/azure-vote-front:v1
  ````

To

  ````
    spec:
      containers:
      - name: azure-vote-front
        image: crcollectorworkshop.azurecr.io/pelithne/azure-vote-front:v2
  ````
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


## Cleaning up
To stop your running containers, you can run the following command:

```console
kubectl delete -f azure-vote-all-in-one-redis.yaml
```

After this, you can remove the namespace you created previously:
```console
kubectl delete namespace <your unique namespace name>
```

Finally, remove the docker image from the container registry:
```console
az acr repository delete --name crcollectorworkshop --repository <unique name>/azure-vote-front
```
