#!/bin/bash
	
a2enmod headers
echo "Header set MyHeader \"%D %t"\" >> /etc/apache2/apache2.conf
echo "Header always unset \"X-Powered-By\"" >> /etc/apache2/apache2.conf
echo "Header unset \"X-Powered-By\"" >> /etc/apache2/apache2.conf

####################################################################################
#
# Install some utilities for REDCap to work properly
#
####################################################################################

apt-get update
apt-get install -y sendmail cron

####################################################################################
#
# Configure REDCap cronjob to run every minute
#
####################################################################################

echo "* * * * * /usr/local/bin/php /var/www/html/redcap/cron.php > /dev/null" >> /etc/crontab
service cron start

####################################################################################
#
# Start Apache
#
####################################################################################

/usr/sbin/apache2ctl -D FOREGROUND