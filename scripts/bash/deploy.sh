#!/bin/bash

# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License

# Exit on any error
set -e

####################################################################################
#
# Timestamp for log file
#
####################################################################################

stamp=$(date +%Y-%m-%d-%H-%M)

# Trap to detect if script is killed
trap 'echo "ERROR: deploy.sh was interrupted or killed at $(date)" >> "/home/site/log-${stamp}.txt"; exit 1' INT TERM

####################################################################################
#
# Configure mysqli extension
#
####################################################################################

echo "Configuring mysqli extension" >> /home/site/log-$stamp.txt
mkdir -p /home/site/ini
echo "extension=/usr/local/lib/php/extensions/no-debug-non-zts-20220829/mysqli.so" >> /home/site/ini/extensions.ini

####################################################################################
#
# Wait for Key Vault secrets to be resolved (race condition fix)
# Only applies when using REDCap Community credentials (no redcapZipUrl provided)
# Azure App Service may not have resolved @Microsoft.KeyVault(...) references yet
#
####################################################################################

# Only wait for secrets if redcapZipUrl is not provided
if [ -z "$APPSETTING_redcapAppZip" ]; then
  echo "Checking if Key Vault secrets are resolved..." >> /home/site/log-$stamp.txt

  max_wait=300  # 5 minutes max
  wait_interval=10
  elapsed=0

  while [ $elapsed -lt $max_wait ]; do
    # Check if credentials look like Key Vault references (not yet resolved) or are empty
    if [[ "$APPSETTING_redcapCommunityPassword" == @Microsoft.KeyVault* ]] || [ -z "$APPSETTING_redcapCommunityPassword" ]; then
      echo "Waiting for Key Vault secrets to resolve... ($elapsed seconds elapsed)" >> /home/site/log-$stamp.txt
      sleep $wait_interval
      elapsed=$((elapsed + wait_interval))
    else
      echo "Key Vault secrets resolved after $elapsed seconds" >> /home/site/log-$stamp.txt
      break
    fi
  done

  # Verify secrets were resolved before proceeding
  if [[ "$APPSETTING_redcapCommunityPassword" == @Microsoft.KeyVault* ]] || [ -z "$APPSETTING_redcapCommunityPassword" ]; then
    echo "ERROR: Key Vault secrets not resolved after $max_wait seconds. Exiting." >> /home/site/log-$stamp.txt
    exit 1
  fi
fi

####################################################################################
#
# Install unzip if not present
#
####################################################################################

if ! command -v unzip &> /dev/null; then
  echo "Installing unzip..." >> /home/site/log-$stamp.txt
  apt-get update && apt-get install -y unzip >> /home/site/log-$stamp.txt 2>&1
fi

####################################################################################
#
# Download REDCap zip file and unzip to wwwroot
# If zip file path exists just download it; otherwise
# make a call # to REDCap community site and download it
#
####################################################################################

redcapZipPath="/tmp/redcap.zip"

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

  echo "Using credentials for user: ${APPSETTING_redcapCommunityUsername}" >> "/home/site/log-${stamp}.txt"

  # Try wget first with aggressive retry settings
  echo "Attempting download with wget (timeout: 30s, tries: 5)..." >> "/home/site/log-${stamp}.txt"

  set -o pipefail
  wget --progress=dot:mega --timeout=30 --read-timeout=30 --tries=5 --waitretry=5 --retry-connrefused --method=post -O "${redcapZipPath}" --body-data="username=${APPSETTING_redcapCommunityUsername}&password=${APPSETTING_redcapCommunityPassword}&version=${APPSETTING_zipVersion}&install=1" --header=Content-Type:application/x-www-form-urlencoded https://redcap.vumc.org/plugins/redcap_consortium/versions.php 2>&1 | tee -a "/home/site/log-${stamp}.txt"
  wget_exit_code=$?
  set +o pipefail

  # If wget fails, try curl as fallback
  if [ "${wget_exit_code}" -ne 0 ]; then
    echo "wget failed with exit code ${wget_exit_code}, trying curl as fallback..." >> "/home/site/log-${stamp}.txt"

    # Remove partial download
    rm -f "${redcapZipPath}"

    curl --fail --show-error --location --connect-timeout 30 --max-time 1800 --retry 5 --retry-delay 5 --retry-max-time 3600 -X POST -o "${redcapZipPath}" -d "username=${APPSETTING_redcapCommunityUsername}&password=${APPSETTING_redcapCommunityPassword}&version=${APPSETTING_zipVersion}&install=1" -H "Content-Type: application/x-www-form-urlencoded" https://redcap.vumc.org/plugins/redcap_consortium/versions.php 2>&1 | tee -a "/home/site/log-${stamp}.txt"
    curl_exit_code=$?

    if [ "${curl_exit_code}" -ne 0 ]; then
      echo "ERROR: Both wget and curl failed. curl exit code: ${curl_exit_code}" >> "/home/site/log-${stamp}.txt"
      exit 1
    fi
    echo "curl download succeeded" >> "/home/site/log-${stamp}.txt"
  fi

  if [ ! -f "${redcapZipPath}" ]; then
    echo "ERROR: Download file ${redcapZipPath} does not exist" >> "/home/site/log-${stamp}.txt"
    exit 1
  fi

  if [ ! -s "${redcapZipPath}" ]; then
    echo "ERROR: Download file ${redcapZipPath} is empty" >> "/home/site/log-${stamp}.txt"
    exit 1
  fi

  file_size=$(stat -f%z "${redcapZipPath}" 2>/dev/null || stat -c%s "${redcapZipPath}" 2>/dev/null)
  echo "wget download completed - file size: ${file_size} bytes" >> "/home/site/log-${stamp}.txt"

  # check to see if the redcap.zip file contains the word error
  if grep -qi error "${redcapZipPath}"; then
    echo "ERROR: Downloaded file contains error message:" >> "/home/site/log-${stamp}.txt"
    cat "${redcapZipPath}" >> "/home/site/log-${stamp}.txt"
    exit 1
  fi
  echo "Downloaded REDCap zip file successfully" >> "/home/site/log-${stamp}.txt"

else
  echo "Downloading REDCap zip file from storage" >> "/home/site/log-${stamp}.txt"
  echo "Attempting download from: ${APPSETTING_redcapAppZip}" >> "/home/site/log-${stamp}.txt"

  # Try wget first
  set -o pipefail
  wget --progress=dot:mega --timeout=30 --read-timeout=30 --tries=5 --waitretry=5 -O "${redcapZipPath}" "${APPSETTING_redcapAppZip}" 2>&1 | tee -a "/home/site/log-${stamp}.txt"
  wget_exit_code=$?
  set +o pipefail

  # If wget fails, try curl as fallback
  if [ "${wget_exit_code}" -ne 0 ]; then
    echo "wget failed with exit code ${wget_exit_code}, trying curl as fallback..." >> "/home/site/log-${stamp}.txt"

    rm -f "${redcapZipPath}"

    curl --fail --show-error --location --connect-timeout 30 --max-time 1800 --retry 5 --retry-delay 5 -o "${redcapZipPath}" "${APPSETTING_redcapAppZip}" 2>&1 | tee -a "/home/site/log-${stamp}.txt"
    curl_exit_code=$?

    if [ "${curl_exit_code}" -ne 0 ]; then
      echo "ERROR: Both wget and curl failed. curl exit code: ${curl_exit_code}" >> "/home/site/log-${stamp}.txt"
      exit 1
    fi
    echo "curl download succeeded" >> "/home/site/log-${stamp}.txt"
  fi

  if [ ! -f "${redcapZipPath}" ]; then
    echo "ERROR: Download file ${redcapZipPath} does not exist" >> "/home/site/log-${stamp}.txt"
    exit 1
  fi

  if [ ! -s "${redcapZipPath}" ]; then
    echo "ERROR: Download file ${redcapZipPath} is empty" >> "/home/site/log-${stamp}.txt"
    exit 1
  fi

  file_size=$(stat -f%z "${redcapZipPath}" 2>/dev/null || stat -c%s "${redcapZipPath}" 2>/dev/null)
  echo "wget download completed - file size: ${file_size} bytes" >> "/home/site/log-${stamp}.txt"
fi

echo "Unzipping redcap.zip" >> /home/site/log-$stamp.txt

rm -rf /home/site/wwwroot/*
unzip -oq $redcapZipPath -d /tmp/wwwroot

echo "Moving REDCap files to wwwroot" >> /home/site/log-$stamp.txt

mv -f /tmp/wwwroot/redcap/* /home/site/wwwroot/
rm -rf /tmp/wwwroot
rm -f $redcapZipPath

####################################################################################
#
# Update database connection info in database.php
#
####################################################################################

echo "Updating database connection info in database.php" >> /home/site/log-$stamp.txt

cd /home/site/wwwroot

# Download Mozilla CA bundle (includes Microsoft, DigiCert, and all major CAs)
# Azure MySQL Flexible Server now uses Microsoft's own CA, not DigiCert
curl -sL https://curl.se/ca/cacert.pem -o /home/site/wwwroot/DigiCertGlobalRootCA.crt.pem

echo "Downloaded Mozilla CA bundle for SSL verification" >> /home/site/log-$stamp.txt

sed -i "s|hostname[[:space:]]*= '';|hostname = getenv('DBHostName');|" database.php
sed -i "s|db[[:space:]]*= '';|db = getenv('DBName');|" database.php
sed -i "s|username[[:space:]]*= '';|username = getenv('DBUserName');|" database.php
sed -i "s|password[[:space:]]*= '';|password = getenv('DBPassword');|" database.php
sed -i "s|db_ssl_ca[[:space:]]*= '';|db_ssl_ca = getenv('DBSslCa');|" database.php

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
