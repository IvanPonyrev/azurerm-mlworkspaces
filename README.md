"# GlobalAzureBootcamp" 

Initial deployment is for storageAccounts, to which all resources, params, and linked deployments will be uploaded.

.\deploy.ps1 -ResourceGroupLocation eastus -ResourceGroupName storage -UploadArtifacts



.\deploy.ps1 -ResourceGroupLocation eastus -ResourceGroupName storage -TemplateFile .\azuredeploy.json -TemplateParametersFile .\azuredeploy.parameters.json -LinkedResourceGroups @()