#!/usr/bin/env bash

# name: install-zscaler.sh
# desc: silently download and install/update Zscaler application for macOS to a defined version. Meant to be used with Jamf Pro (MDM).
# auth: @andy-cheatwood
# changelog:
# 20200702 - script created.

zapp_installer_download(){

  # initialize local variables
  local zapp_version;
  local zapp_zip;
  local zapp_url;
  local zapp_app;

  # define local variables. Verify zapp version is defined.
  zapp_version="${1}"
  if [[ -z "${zapp_version}" ]]; then
    printf '%s\n' 'ERROR: Zapp version to download undefined in Jamf.' 1>&2
    exit 1
  fi
  zapp_zip="Zscaler-osx-"${zapp_version}"-installer.app.zip"
  zapp_url="https://d32a6ru7mhaq0c.cloudfront.net/${zapp_zip}"
  zapp_app="Zscaler-osx-"${zapp_version}"-installer.app"

  # change to /tmp directory
  cd /tmp || exit 1

  # Attempt to download defined version of the Zscaler installer application to the /tmp directory.
  if /usr/bin/curl -sLJO --retry 10 "${zapp_url}"; then
    printf '%s\n' 'SUCCESS: downloaded Zscaler installer application.'
  else
    printf '%s\n' 'ERROR: failed to download Zscaler installer application.' 1>&2
    exit 1
  fi

  # Verify download exists and extract installer application to /tmp directory
  if [[ -e ${zapp_zip} ]]; then
    if unzip ${zapp_zip} &> /dev/null; then
      printf '%s\n' 'SUCCESS: extracted Zscaler installer application.'
    else
      printf '%s\n' 'ERROR: failed to extract Zscaler installer application.' 1>&2
      exit 1
    fi
  else
    printf '%s\n' 'ERROR: could not verify Zscaler installer download exists.' 1>&2
    exit 1
  fi

  # silently install/update Zscaler application using installbuilder script in the Zscaler installer MacOS directory.
  sudo sh "${zapp_app}/Contents/MacOS/installbuilder.sh" --mode unattended --unattendedmodeui none --hideAppUIOnLaunch 1

  # verify installed version of zapp matches desired version
  # todo

}

main(){

  # Zscaler version desired defined in Jamf parameter.
  local zapp_version="${4}"

  zapp_installer_download "${zapp_version}"

}

main "${@}"
