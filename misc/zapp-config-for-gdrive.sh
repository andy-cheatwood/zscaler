#!/usr/bin/env bash

# script name: zapp-config-for-gdrive.sh
# description: Appends the Zscaler Root certificate to Google Drive's "built-in" certificate.
# Then updates the TrustedRootCertsFile for Google Drives preferences at: `/Library/Preferences/com.google.drivefs.settings`
# author: @andy-cheatwood
# changelog:
# 20210423 - script created
#
# notes:
# Function names are in PascalCase.
# Variable names are in snake_case.

Main(){

    # tools in /usr/bin, /bin, /usr/sbin, /sbin & /usr/libexec should be SIP protected (and therefore safe to use)
    export PATH=/usr/bin:/bin:/usr/sbin:/usr/libexec:/sbin
    
    # define path to Google Drive "built-in" certificate *and* path to our custom cert.
    gdrive_cert="/Applications/Google Drive.app/Contents/Resources/roots.pem"
    gdrive_settings="/Library/Preferences/com.google.drivefs.settings"
    gdrive_zscaler_cert="/Applications/Google Drive.app/Contents/Resources/custom_roots.pem"
    
    # delete our custom cert if exists (so it can be created *fresh*)
    if [[ -f "${gdrive_zscaler_cert}" ]]; then
        if rm "${gdrive_zscaler_cert}"; then
            echo 'successfully removed old custom cert'
        else
            echo 'failed to remove old custom cert' 1>&2
            exit 1
        fi
    fi
    
    # only if the Google Drive "built-in" cert exists, attempt to create the custom one from it.
    if [[ -f "${gdrive_cert}" ]]; then
        # make copy of the built-in gdrive cert (dont want to modify the og, just in case)
        if cp "${gdrive_cert}" "${gdrive_zscaler_cert}" 2> /dev/null; then
            echo 'successfully copied built-in GDrive cert'
        else
            echo 'failed to copy built-in GDrive cert' 1>&2
            exit 1
        fi
        # export Zscaler cert from Keychain and append to the copy of the gdrive built-in cert.
        if security find-certificate -c 'Zscaler' -p >> "${gdrive_zscaler_cert}" 2> /dev/null; then
            echo 'successfully exported Zscaler cert from Keychain'
        else
            echo 'failed to export Zscaler cert from Keychain' 1>&2
            exit 1
        fi
        # tell gdrive app the location of the custom cert (that now has the Zscaler cert too)
        if defaults write "${gdrive_settings}" TrustedRootCertsFile "${gdrive_zscaler_cert}" 2> /dev/null; then
            echo 'successfully set TrustedRootCertsFile'
            echo "Debug: value of TrustedRootCertsFile: $( defaults read /Library/Preferences/com.google.drivefs.settings TrustedRootCertsFile 2> /dev/null )"
        else
            echo 'failed to set TrustedRootCertsFile' 1>&2
            exit 1
        fi
        # gdrive needs to be quit for changes to take effect. attempt to kill all.
        killall "Google Drive" &> /dev/null || true
    else
        echo 'Google Drive not installed or built-in cert not exist' 1>&2
        exit 1
    fi
    
    echo 'successfully configured Google Drive for Zscaler'
    exit 0
    
}

Main "${@}"
