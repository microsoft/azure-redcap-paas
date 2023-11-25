#!/bin/bash

# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License

echo "hello from postbuild.sh"

####################################################################################
#
# Call the install.php file with the option to deploy the database schema
#
####################################################################################

curl -sS https://$WEBSITE_HOSTNAME/install.php?auto=1

####################################################################################
#
# Update additional configuration settings including
# user file uploading settings to Azure Blob Storage
# 
####################################################################################

bash /home/site/repository/scripts/bash/install.sh