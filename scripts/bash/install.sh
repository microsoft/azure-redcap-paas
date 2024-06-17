#!/bin/bash

echo -e "\nHello from install.sh"
which mysql

# Debugging output for environment variables
echo "DB Server: $DB_SERVER"
echo "DB Username: $DB_USERNAME"
echo "DB Password: $DB_PASSWORD"
echo "DB Name: $DB_NAME"

# Test MySQL connection
/usr/bin/mysql -h $DB_SERVER -u $DB_USERNAME -p"$DB_PASSWORD" --ssl=true --ssl-ca=/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem -e "SHOW DATABASES;"

# Use mysql with explicit host, user, and password
/usr/bin/mysql -h $DB_SERVER -u $DB_USERNAME -p"$DB_PASSWORD" --ssl=true --ssl-ca=/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem <<EOF
UPDATE $DB_NAME.redcap_config SET value = 'https://$WEBSITE_HOSTNAME/' WHERE field_name = 'redcap_base_url';
UPDATE $DB_NAME.redcap_config SET value = '$APPSETTING_StorageAccount' WHERE field_name = 'azure_app_name';
UPDATE $DB_NAME.redcap_config SET value = '$APPSETTING_StorageKey' WHERE field_name = 'azure_app_secret';
UPDATE $DB_NAME.redcap_config SET value = '$APPSETTING_StorageContainerName' WHERE field_name = 'azure_container';
UPDATE $DB_NAME.redcap_config SET value = '4' WHERE field_name = 'edoc_storage_option';
REPLACE INTO $DB_NAME.redcap_config (field_name, value) VALUES ('azure_quickstart', '1');
EOF
