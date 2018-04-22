"# GlobalAzureBootcamp" 

.\deploy.ps1 -ResourceGroupLocation eastus -ResourceGroupName storage -UploadArtifacts

.\deploy.ps1 -ResourceGroupLocation eastus -ResourceGroupName storage -TemplateFile .\azuredeploy.json -TemplateParametersFile .\azuredeploy.parameters.json -userObjectId