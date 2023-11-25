#!/bin/bash

# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License

echo -e "\nHello from install.sh"

####################################################################################
#
# Update additional configuration settings including 
# user file uploading settings to Azure Blob Storage
#
####################################################################################

mysql -u$APPSETTING_DBUserName -h$APPSETTING_DBHostName -p$APPSETTING_DBPassword --ssl=true --ssl-ca=/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem <<EOF
UPDATE $APPSETTING_DBName.redcap_config SET value = 'https://$WEBSITE_HOSTNAME/' WHERE field_name = 'redcap_base_url';
UPDATE $APPSETTING_DBName.redcap_config SET value = '$APPSETTING_StorageAccount' WHERE field_name = 'azure_app_name';
UPDATE $APPSETTING_DBName.redcap_config SET value = '$APPSETTING_StorageKey' WHERE field_name = 'azure_app_secret';
UPDATE $APPSETTING_DBName.redcap_config SET value = '$APPSETTING_StorageContainerName' WHERE field_name = 'azure_container';
UPDATE $APPSETTING_DBName.redcap_config SET value = '4' WHERE field_name = 'edoc_storage_option';
REPLACE INTO $APPSETTING_DBName.redcap_config (field_name, value) VALUES ('azure_quickstart', '1');
EOF
