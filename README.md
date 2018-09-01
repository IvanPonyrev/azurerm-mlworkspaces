# Deploy storageAccounts and vaults.

The following command will deploy storageAccounts and vaults with secrets. Deployment parameters must be updated with the id of AzureADUser or AzureADUserGroup to which vault access will be given.

.\deploy.ps1 -UploadArtifacts -DeployStorage

# Deploy virtualNetwork

Deployment of virtual network has been broken out to separate deployment to keep parameters files from becoming gigantic.

.\deploy.ps1 -TemplateFile .\deployments\network.json -TemplateParametersFile .\params\network.parameters.json -LinkedResourceGroups @()
