# Deploy management resources, web application, sql, and cosmos db.

The following command will deploy all resources including storageAccounts, vaults, automation, secrets, runbooks, updated automation modules from Azure gallery, sql with database, cosmos db, and a web application. If you wish to deploy or update individual deployments, please see below.

.\deploy.ps1 -UploadArtifacts -DeployStorage

# Deploy individual deployments or resources.

To deploy an individual deployment, after management resources have been deployed. In this example, we will deploy the automation deployment.

.\deploy.ps1 -LinkedResourceGroups @() -TemplateFile .\deployments\automation.json 