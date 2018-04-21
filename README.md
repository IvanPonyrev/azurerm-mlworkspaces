"# GlobalAzureBootcamp" 

.\deploy.ps1 -ResourceGroupLocation eastus -ResourceGroupName storage -UploadArt
ifacts

.\deploy.ps1 -ResourceGroupLocation eastus -ResourceGroupName storage -TemplateF
ile .\azuredeploy.json -TemplateParametersFile .\azuredeploy.parameters.json -userObjectId