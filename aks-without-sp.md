
# Create cluster 

## Create with a Managed Identity

In the default scenario, when you create an AKS cluster, a **Service Principal** will be created for you. If your user does not have permission to create a service principal, you can use an existing one (assuming that one has been created by someone with the necessary permissions).

Alternatively, you can create the AKS cluster with a **Managed Identity**. This removes the need to use a pre-provisioned Service Principal.

To create a cluster with managed identity:
````
az aks create --resource-group k8s-rg --name k8s --generate-ssh-keys --load-balancer-sku basic --node-count 3 --node-vm-size Standard_B2s --enable-managed-identity
````

Azure container registry does not support managed identity yet, so you can not attach it to AKS with a simple flag. You will have to configure your ACR to accept an admin user with password. This is described later in the main workshop instructions.

## Create with an existing Service Principal

If you do not want to use the managed identity, you can create a cluster with an existing service principal, like this:

````
az aks create --resource-group k8s-rg --name k8s --generate-ssh-keys --attach-acr <your unique ACR name> --load-balancer-sku basic --node-count 3 --node-vm-size Standard_B2s --service-principal <a valid SP> --client-secret <SP secret>
````

For reference, a service principal looks similar to this (with fake credentials):

````
{
  "appId": "55456c5e-c338-4211-9a19-f21230ba127c",
  "displayName": "some-sp-name",
  "name": "http://some-sp-name",
  "password": "ZiyPa~VM5J9GdD3Hkc33tN1Nxab0a2JM8E",
  "tenant": "72f988bf-85g1-41af-92db-2d745511db47"
}
````

The appId is what you should use as ````--service-principal```` 

The password should be used as ````--client-secret````
