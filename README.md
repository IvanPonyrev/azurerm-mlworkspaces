# Deploy storageAccounts and vaults.

The following command will deploy storageAccounts and vaults with secrets. Deployment parameters must be updated with the id of AzureADUser or AzureADUserGroup to which vault access will be given.

.\deploy.ps1 -UploadArtifacts -DeployStorage
