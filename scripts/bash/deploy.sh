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
mkdir /home/site/ini
echo "extension=/usr/local/lib/php/extensions/no-debug-non-zts-20220829/mysqli.so" >> /home/site/ini/extensions.ini

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

  if [ -z "$APPSETTING_redcapCommunityUsername" ]; then
    echo "Missing REDCap Community site username." >> /home/site/log-$stamp.txt
    exit 1
  fi

  if [ -z "$APPSETTING_redcapCommunityPassword" ]; then
    echo "Missing REDCap Community site password." >> /home/site/log-$stamp.txt
    exit 1
  fi

  if [ -z "$APPSETTING_zipVersion" ]; then
    echo "zipVersion is null or empty. Setting to latest" >> /home/site/log-$stamp.txt
    export APPSETTING_zipVersion="latest"
  fi
  
  wget --method=post -O /tmp/redcap.zip -q --body-data="username=$APPSETTING_redcapCommunityUsername&password=$APPSETTING_redcapCommunityPassword&version=$APPSETTING_zipVersion&install=1" --header=Content-Type:application/x-www-form-urlencoded https://redcap.vanderbilt.edu/plugins/redcap_consortium/versions.php

  # check to see if the redcap.zip file contains the word error
  if [ -z "$(grep -i error redcap.zip)" ]; then
    echo "Downloaded REDCap zip file" >> /home/site/log-$stamp.txt
  else
    echo $(cat redcap.zip) >> /home/site/log-$stamp.txt
    exit 1
  fi

else
  echo "Downloading REDCap zip file from storage" >> /home/site/log-$stamp.txt
  wget -q -O /tmp/redcap.zip $APPSETTING_redcapAppZip
fi

rm -f /home/site/wwwroot/hostingstart.html
unzip -oq /tmp/redcap.zip -d /tmp/wwwroot 
mv -f /tmp/wwwroot/redcap/* /home/site/wwwroot/
rm -rf /tmp/wwwroot
rm /tmp/redcap.zip

####################################################################################
#
# Update database connection info in database.php
#
####################################################################################

echo "Updating database connection info in database.php" >> /home/site/log-$stamp.txt

cd /home/site/wwwroot

wget --no-check-certificate https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem

sed -i "s|hostname[[:space:]]*= '';|hostname = getenv('APPSETTING_DBHostName');|" database.php
sed -i "s|db[[:space:]]*= '';|db = getenv('APPSETTING_DBName');|" database.php
sed -i "s|username[[:space:]]*= '';|username = getenv('APPSETTING_DBUserName');|" database.php
sed -i "s|password[[:space:]]*= '';|password = getenv('APPSETTING_DBPassword');|" database.php
sed -i "s|db_ssl_ca[[:space:]]*= '';|db_ssl_ca = getenv('APPSETTING_DBSslCa');|" database.php

sed -i "s/db_ssl_verify_server_cert = false;/db_ssl_verify_server_cert = true;/" database.php
sed -i "s/$salt = '';/$salt = '$(echo $RANDOM | md5sum | head -c 20; echo;)';/" database.php

####################################################################################
#
# Configure REDCap recommended settings
#
####################################################################################

echo "Configuring REDCap recommended settings" >> /home/site/log-$stamp.txt

sed -i "s|SMTP[[:space:]]*= ''|SMTP = '$APPSETTING_smtpFQDN'|" /home/site/repository/Files/settings.ini
sed -i "s|smtp_port[[:space:]]*= |smtp_port = $APPSETTING_smtpPort|" /home/site/repository/Files/settings.ini
sed -i "s|sendmail_from[[:space:]]*= ''|sendmail_from = '$APPSETTING_fromEmailAddress'|" /home/site/repository/Files/settings.ini
sed -i "s|sendmail_path[[:space:]]*= ''|sendmail_path = '/usr/sbin/sendmail -t -i'|" /home/site/repository/Files/settings.ini

cp /home/site/repository/Files/settings.ini /home/site/ini/redcap.ini

####################################################################################
#
# For better security, it is recommended that you enable the 
# session.cookie_secure option in your web server's PHP.INI file
#
####################################################################################

echo "For better security, it is recommended that you enable the session.cookie_secure option in your web server's PHP.INI file" >> /home/site/log-$stamp.txt
echo "session.cookie_secure = On" >> /home/site/ini/redcap.ini

####################################################################################
#
# Copy postbuild.sh to PostDeploymentActions for execution after deployment
#
####################################################################################

mkdir -p /home/site/deployments/tools/PostDeploymentActions
cp /home/site/repository/scripts/bash/postbuild.sh /home/site/deployments/tools/PostDeploymentActions/postbuild.sh

####################################################################################
#
# Copy startup.sh /home for a custom startup
#
####################################################################################

cp /home/site/repository/scripts/bash/startup.sh /home/startup.sh