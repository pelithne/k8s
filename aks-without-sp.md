
# Create cluster with a Managed Identity

In the default scenario, when you create an AKS cluster, a **Service Principal** will be created for you. 

If that is not allowed, you can create the AKS cluster with a **Managed Identity**. This removes the need to use a pre-provisioned Service Principal.

To create a cluster with managed identity:
````
az aks create --resource-group k8s-rg --name k8s --generate-ssh-keys --load-balancer-sku basic --node-count 3 --node-vm-size Standard_B2s --enable-managed-identity
````

Azure container registry does not support managed identity yet, so you can not attach it to AKS with a simple flag. You will have to configure your ACR to accept an admin user with password. This is described later in the workshop instructions.
