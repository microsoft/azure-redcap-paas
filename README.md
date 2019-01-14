# ARM Template for REDCap automated deployment in Azure


## Quick Start

Description | Link
--- | ---
Deploy with your SMTP Relay | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanderbilt-redcap%2Fredcap-azure%2Fmaster%2Fazuredeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
Deploy using SendGrid | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanderbilt-redcap%2Fredcap-azure%2Fmaster%2Fazuredeploy_with_SendGrid.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>

__Details__

This template automates the deployment of the REDCap solution into Azure using managed PaaS resources. The template assumes you are deploying a version of REDCap that supports direct connection to Azure Blob Storage. If you deploy an older version, deployment will succeed but you will need to manually provision NFS storage in Azure, and delete the new storage account. For NFS, consider:
  * https://docs.microsoft.com/en-us/azure/azure-netapp-files/
  * https://azuremarketplace.microsoft.com/en-us/marketplace/apps/softnas.softnas-cloud
  * https://azure.microsoft.com/en-us/resources/templates/nfs-ha-cluster-ubuntu/

You will need to specify a location for the deployment automation to pull your copy of the REDCap source. This ZIP file will need a __*publicly accessible url*__ while the deployment is running. OneDrive, Azure Blob Storage, DropBox, etc., are all suitable temporary storage locations for deployment.

https://projectredcap.org/wp-content/resources/REDCapTechnicalOverview.pdf

* ARM template deploys the following:
  * Azure Web App
  * Azure DB for MySQL (1)
  * Azure Storage Account
  * (optional) SendGrid 3rd Party Email service (2)

(1) Review https://docs.microsoft.com/en-us/azure/mysql/concepts-pricing-tiers for details on available features, regions, and pricing models for Azure DB for MySQL.

(2) SendGrid is a paid service with a free tier offering 25k messages per month, with additional paid tiers offering more volume, whitelisting, custom domains, etc. There is a limit of two instances per subscription using the free tier. For more information see https://docs.microsoft.com/en-us/azure/store-sendgrid-php-how-to-send-email#create-a-sendgrid-account. The service will be accessed initially using the password you enter in the deployment template. You can click "Manage" on the SendGrid service after deployment to administrate the service in their portal, including options to create an API key that can be used for access instead of the password.

  If after deployment, you would instead like to use a different SMTP relay, edit the values "smtp_fqdn_name", "smtp_port", "smtp_user_name", and "smtp_password" to point to your preferred endpoint. You can then delete the SendGrid service from this resource group.

__Setup__

This template will automatically deploy the resources necessary to run REDCap in Azure using PaaS (Platform as a Service) features. **IMPORTANT**: *The "Site Name" you choose will be re-used as part of the storage, website, and MySql database name. Make sure you don't use characters that will be rejected by MySql.* 

After the template is deployed, deployment automation will download the REDCap ZIP file you specify, and install it in your web app. It will then automatically update the database connection information in the app. It will then update a few settings in the database, and configure Azure file storage if you have that version of REDCap. It will also create the initial storage container.

With the download and unzipping, the entire operation will take between 12-16 minutes.

If you need to connect to the MySQL database using the MySQL client, you will need to open the firewall to your managed MySQL instance and allow connections from the location where you will run the client. Here are the instructions:
https://docs.microsoft.com/en-us/azure/mysql/quickstart-create-mysql-server-database-using-azure-portal#configure-a-server-level-firewall-rule

(Add your current IP address by clicking "+ Add My IP")

Once you've opened the firewall, you will need your database name. The credentials are those you supplied in this template. The name is available from the portal where you updated the firewall rules:

  ![alt text][MySql]

Please also review:
https://docs.microsoft.com/en-us/azure/mysql/concepts-ssl-connection-security

__Post-Setup__

After the deployment and installation of REDCap has completed, everything should be green on the REDCap Configuration Check page. If anything displays on that page in red or yellow, it is recommended that you perform a "Restart" of the Azure "App Service". This needs to be done due to the fact that some necessary server environment settings get changed after the initial deployment, but restarting the App Service will load the service with the intended settings. Everything should be fine after that initial restart though.

__Note about REDCap "Easy Upgade"__

The "Easy Upgrade" feature in REDCap 8.11.0 and later is currently *not* supported when deploying a REDCap instance on Azure. Support for "Easy Upgrade" on Azure is expected to come at a later time in a future REDCap release.

### Resources

 * App Services overview
https://docs.microsoft.com/en-us/azure/app-service/overview
 * Application Settings
https://docs.microsoft.com/en-us/azure/app-service/web-sites-configure
 * Web Jobs (background tasks) overview
https://docs.microsoft.com/en-us/azure/app-service/webjobs-create
 * Project Kudu (App Service back end management and deployment engine)
https://github.com/projectkudu/kudu/wiki
 * Explanation of how isolation occurs in Azure Web Apps
https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox
 * Adding custom domain names
https://docs.microsoft.com/en-us/azure/app-service/manage-custom-dns-migrate-domain
 * SSL Certificates
https://docs.microsoft.com/en-us/azure/app-service/web-sites-purchase-ssl-web-site
 * Updating PHP configurations
https://docs.microsoft.com/en-us/azure/app-service/web-sites-php-configure#how-to-change-the-built-in-php-configurations
 * Managed MySQL overview
https://docs.microsoft.com/en-us/azure/mysql/overview
 * Sendgrid overview
https://docs.microsoft.com/en-us/azure/store-sendgrid-php-how-to-send-email
 * Blob storage overview
https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction
 * Azure Resource Manager (ARM) overview
https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview

### Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

[MySql]: ./images/mysql.png
