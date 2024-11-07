#!/bin/bash

echo "Custom container startup"

####################################################################################
#
# Install required packages in container
#
####################################################################################

apt-get update -qq && apt-get install cron sendmail -yqq

####################################################################################
#
# Configure REDCap cronjob to run every minute
#
####################################################################################

# Export environment variables so cron can run cron.php successfully
export APPSETTING_DBUserName=$APPSETTING_DBUserName
export APPSETTING_DBHostName=$APPSETTING_DBHostName
export APPSETTING_DBPassword=$APPSETTING_DBPassword
export APPSETTING_DBName=$APPSETTING_DBName
export APPSETTING_DBSslCa=$APPSETTING_DBSslCa

service cron start
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/php /home/site/wwwroot/cron.php > /dev/null")|crontab 
