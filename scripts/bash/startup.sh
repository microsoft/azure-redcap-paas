#!/bin/bash
	

####################################################################################
#
# Configure REDCap cronjob to run every minute
#
####################################################################################

echo "* * * * * /usr/local/bin/php /home/site/wwwroot/cron.php > /dev/null" >> /etc/crontab
service cron start
