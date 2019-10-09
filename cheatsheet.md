## Cheatsheet

This file lists some commands that are used in the workshop, that you can use a reference during your work.

### Kubernetes (kubectl) commands

Show all running pods in the default namespace
````
kubectl get pods
````

Show details about a specific pod
```consolse
kubectl describe pod <pod name>
```

Show all running pods in a give namespace
````
kubectl get pods --namepace <name of namespace>
````

Watch a service for changes
```console
kubectl get service <service name> --watch
```



Create a resource from a yaml file
```console
kubectl apply -f some-file.yaml
```

Delete resources using a file
````
kubectl delete -f some-file.yaml
````


See status of autoscaler
```console 
kubectl get hpa
```

### Docker Commands

List docker images (on your system)
````
docker images
````

List running docker containers
````
docker ps
````

List running *and stopped* containers
````
docker ps -a
````

Build docker image, using Dockerfile in same directory
```console
docker build -t <name of your image> .
```

Start a container using a docker image
```console
docker run -d --name <image name> 
```

Create a docker network (for containers to communicate over)
```console
docker network create <network name>
```

Stop and remove the containers:

```console
docker stop azure-vote-front <container name>
docker rm azure-vote-front <container name>
```

### Azure CLI (az cli) commands

```console
az aks get-credentials --resource-group <Your RG name> --name <AKS cluster name>
```




### Bash commands