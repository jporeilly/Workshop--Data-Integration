#########################################
# This script is used to replace the .installedLicenses.xml
# 09/09/2023
#########################################

#!/bin/bash

# Define required variables
LICENSE=".installedLicenses.xml"
LICENSE_DIR_SERVER="/home/${USER}/.pentaho"
LICENSE_DIR_LICENSES="/home/${USER}/.licenses"
TMP_DIR=/home/${USER}/.pentaho/tmp
GITHUB=github.com
GITHUB_USER=jporeilly
HOST_USER=${USER}
GITHUB_REPO=Pentaho--Licenses
LICENSE_REPO=https://$GITHUB/$GITHUB_USER/$GITHUB_REPO

# Check if the file exists
if [ -f "$LICENSE_DIR_SERVER/$LICENSE" ]; then
    echo "Found $LICENSE exists. Deleting..."
    sudo rm -rf $LICENSE_DIR_SERVER/$LICENSE
        echo "Pentaho License deleted."
fi

# Check if the file exists
if [ -f "$LICENSE_DIR_LICENSES/$LICENSE" ]; then
    echo "Found $LICENSE exists. Deleting..."
    sudo rm -rf $LICENSE_DIR_LICENSES/$LICENSE
        echo "Pentaho License deleted."
fi

# Create a tmp directory to hold license
    echo "Creating $TMP_DIR directory .."
    sudo mkdir $TMP_DIR

# Clone the Git repository into the .pentaho directory
    echo "Cloning license into $LICENSE_DIR_SERVER/$TMP_DIR directory..."
    sudo git clone $LICENSE_REPO  $TMP_DIR
    sudo chown -R $HOST_USER $TMP_DIR
    
# Copy installedLicenses.xml
    echo "Copying over $LICENSE .."
    sudo cp $TMP_DIR/$LICENSE  $LICENSE_DIR_SERVER
    sudo cp $TMP_DIR/$LICENSE  $LICENSE_DIR_LICENSES
    
# Tidy up
    echo "Tidy up .."
    sudo rm -rf $TMP_DIR
    echo "$TMP_DIR deleted .."
    
# Check if the clone was successful
if [ $? -eq 0 ]; then
    echo "License installed successfully."
else
    echo "Error: License failed to install."
fi