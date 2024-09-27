#!/bin/bash

echo "Custom container startup"

####################################################################################
#
# Install required packages in container
#
####################################################################################

apt-get update -qq && apt-get install sendmail -yqq

####################################################################################
#
# Configure REDCap cronjob to run every minute
#
####################################################################################

# service cron start
# (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/php /home/site/wwwroot/cron.php > /dev/null")|crontab 
