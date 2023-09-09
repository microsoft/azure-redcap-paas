#!/bin/bash

# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License

####################################################################################
#
# Timestamp for log file
#
####################################################################################

stamp=$(date +%Y-%m-%d-%H-%M)

####################################################################################
#
# Configure mysqli extension
#
####################################################################################

echo "Configuring mysqli extension" >> /home/site/log-$stamp.txt
cd /home/site
echo "extension=/usr/local/lib/php/extensions/no-debug-non-zts-20190902/mysqlnd_azure.so
extension=/usr/local/lib/php/extensions/no-debug-non-zts-20190902/mysqli.so" >> extensions.ini

####################################################################################
#
# Download REDCap zip file and unzip to wwwroot
# If zip file path exists just download it; otherwise 
# make a call # to REDCap community site and download it
#
####################################################################################

cd /tmp
if [ -z "$APPSETTING_redcapAppZip" ]; then
  echo "Downloading REDCap zip file from REDCap Community site" >> /home/site/log-$stamp.txt

  if [ -z "$APPSETTING_zipUsername" ]; then
    echo "Missing REDCap Community site username." >> /home/site/log-$stamp.txt
    exit 1
  fi

  if [ -z "$APPSETTING_zipPassword" ]; then
    echo "Missing REDCap Community site password." >> /home/site/log-$stamp.txt
    exit 1
  fi

  if [ -z "$APPSETTING_zipVersion" ]; then
    echo "zipVersion is null or empty. Setting to latest" >> /home/site/log-$stamp.txt
    export APPSETTING_zipVersion="latest"
  fi
  
  wget --method=post -O redcap.zip -q --body-data="username=$APPSETTING_zipUsername&password=$APPSETTING_zipPassword&version=$APPSETTING_zipVersion&install=1" --header=Content-Type:application/x-www-form-urlencoded https://redcap.vanderbilt.edu/plugins/redcap_consortium/versions.php

  # check to see if the redcap.zip file contains the word error
  if [ -z "$(grep -i error redcap.zip)" ]; then
    echo "Downloaded REDCap zip file" >> /home/site/log-$stamp.txt
  else
    echo $(cat redcap.zip) >> /home/site/log-$stamp.txt
    exit 1
  fi

else
  echo "Downloading REDCap zip file from storage" >> /home/site/log-$stamp.txt
  wget -q -O redcap.zip $APPSETTING_redcapAppZip
fi

rm /home/site/wwwroot/hostingstart.html
unzip -oq redcap.zip -d /home/site/wwwroot
mv /home/site/wwwroot/redcap/* /home/site/wwwroot/
rm -Rf /home/site/wwwroot/redcap

####################################################################################
#
# Update database connection info in database.php
#
####################################################################################

echo "Updating database connection info in database.php" >> /home/site/log-$stamp.txt

cd /home/site/wwwroot

wget --no-check-certificate https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem

# TODO: Update because the defaults are now empty instead of 'your_mysql_...'
sed -i "s/'your_mysql_host_name'/'$APPSETTING_DBHostName'/" database.php
sed -i "s/'your_mysql_db_name'/'$APPSETTING_DBName'/" database.php
sed -i "s/'your_mysql_db_username'/'$APPSETTING_DBUserName'/" database.php
sed -i "s/'your_mysql_db_password'/'$APPSETTING_DBPassword'/" database.php
# END TODO
sed -i "s|db_ssl_ca[[:space:]]*= '';|db_ssl_ca = '$APPSETTING_DBSslCa';|" database.php

sed -i "s/db_ssl_verify_server_cert = false;/db_ssl_verify_server_cert = true;/" database.php
sed -i "s/$salt = '';/$salt = '$(echo $RANDOM | md5sum | head -c 20; echo;)';/" database.php

####################################################################################
#
# Configure REDCap recommended settings
#
####################################################################################

echo "Configuring REDCap recommended settings" >> /home/site/log-$stamp.txt
sed -i "s/replace_smtp_server_name/$APPSETTING_smtpFQDN/" /home/site/repository/Files/settings.ini
sed -i "s/replace_smtp_port/$APPSETTING_smtpPort/" /home/site/repository/Files/settings.ini
sed -i "s/replace_sendmail_from/$APPSETTING_fromEmailAddress/" /home/site/repository/Files/settings.ini
sed -i "s:replace_sendmail_path:/usr/sbin/sendmail -t -i:" /home/site/repository/Files/settings.ini
cp /home/site/repository/Files/settings.ini /home/site/redcap.ini

####################################################################################
#
# For better security, it is recommended that you enable the 
# session.cookie_secure option in your web server's PHP.INI file
#
####################################################################################

echo "For better security, it is recommended that you enable the session.cookie_secure option in your web server's PHP.INI file" >> /home/site/log-$stamp.txt
echo "session.cookie_secure = On" >> /home/site/redcap.ini

####################################################################################
#
# Move postbuild.sh to PostDeploymentActions for execution after deployment
#
####################################################################################

mkdir -p /home/site/deployments/tools/PostDeploymentActions
cp /home/site/repository/postbuild.sh /home/site/deployments/tools/PostDeploymentActions/postbuild.sh

####################################################################################
#
# Move startup.sh /home for a custom startup
#
####################################################################################

cp /home/site/repository/startup.sh /home/startup.sh
