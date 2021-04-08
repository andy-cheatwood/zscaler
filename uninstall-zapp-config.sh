#!/usr/bin/env bash

# script name: uninstall-zapp-config.sh
# description: unconfigure various apps/tools to work with Zscaler (ZIA) enabled.
# author: @andy-cheatwood
# TODO: add sources where applicable
# changelog:
# 20210319 - script created
#
#
# notes:
# Function names are in PascalCase.
# Variable names are in snake_case.

trap Cleanup SIGINT SIGTERM ERR EXIT
DEBUG=true

###################################
### template/built-in functions ###
###################################
Cleanup() { trap - SIGINT SIGTERM ERR EXIT; }
Log(){ printf '%-35s %-10s %-25s %-20s %-50s\n' "[$(date -u)]" "[${1}]" "[$(basename "${0}")]" "[${FUNCNAME[2]}]" "${2}" 1>&2; }
Info(){ Log 'INFO' "${@}"; true; }
Notice(){ Log 'NOTICE' "${@}"; true; }
Debug(){ if "${DEBUG}"; then Log 'DEBUG' "${@}"; true; fi; }
Error(){ Log 'ERROR' "${@}"; exit 1; }
GetLoggedInUser(){ echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }'; }
GetLoggedInUserId(){ id -u "$(GetLoggedInUser)"; }
GetLoggedInUserHome(){ eval echo "~$(GetLoggedInUser)"; }

#################################
### script-specific functions ###
#################################
# desc: any additional functions required for the script to complete its task(s) go here.

Main(){
    
    # declare variables
    local cert_dir="${1:-/var/cacerts}"
    local config_file="${cert_dir}/.zapprc"
    local user_home="$(GetLoggedInUserHome)"
    
    # remove certs directory
    # /bin/mkdir -p "${cert_dir}"
    
    # remove source from common shell configs
    /usr/bin/sed -i .backup "\|${config_file}|d" "${user_home}/.bash_profile" > /dev/null 2>&1 && Info 'removed custom shell config source'
    /usr/bin/sed -i .backup "\|${config_file}|d" "${user_home}/.zshrc" > /dev/null 2>&1 && Info 'removed custom shell config source'
    
    # apps/tools config commands
    # macos app firewall
    # /usr/libexec/ApplicationFirewall/socketfilterfw --remove /Applications/Zscaler/Zscaler.app/Contents/MacOS/Zscaler --remove /Applications/Zscaler/Zscaler.app/Contents/PlugIns/ZscalerTunnel --remove /Applications/Zscaler/Zscaler.app/Contents/PlugIns/ZscalerService --remove /Applications/Zscaler/.Updater/autoupdate-osx.app/Contents/MacOS/ZscalerUpdater > /dev/null 2>&1 && Info 'macos app firewall unconfigured'
    
    # git
    git config --global --unset http.sslcainfo && Info 'git global http.sslcainfo unconfigured'
    git config --global --unset http.proxy && Info 'git global http.proxy unconfigured'
    git config --system --unset http.sslcainfo && Info 'git system http.sslcainfo unconfigured'
    git config --system --unset http.proxy && Info 'git system http.proxy unconfigured'
    
    # npm
    npm config delete cafile > /dev/null 2>&1 && Info 'npm cafile unconfigured'
    npm config delete proxy > /dev/null 2>&1 && Info 'npm proxy unconfigured'
    # npm config set registry http://registry.npmjs.org/ --global > /dev/null 2>&1 && Info 'npm registry configured'
    
    # yarn
    yarn config delete cafile > /dev/null 2>&1 && Info 'yarn cafile unconfigured'
    yarn config delete proxy > /dev/null 2>&1 && Info 'yarn proxy unconfigured'
    
    # sft
    sft config network.tls_use_bundled_cas true > /dev/null 2>&1 && Info 'sft network tls_use_bundled_cas unconfigured'
    sft config network.forward_proxy '' > /dev/null 2>&1 && Info 'sft network forward_proxy unconfigured'
    
    # python | pip
    python -m pip config unset global.cert > /dev/null 2>&1 && Info 'python pip global cert unconfigured'
    python3 -m pip config unset global.cert > /dev/null 2>&1 && Info 'python3 pip global cert unconfigured'
    pip3 config unset global.cert > /dev/null 2>&1 && Info 'pip3 global cert unconfigured'
    # python -m pip config unset global.trusted-host > /dev/null 2>&1 && Info 'python pip global trusted-host unconfigured'
    # python3 -m pip config unset global.trusted-host > /dev/null 2>&1 && Info 'python3 pip global trusted-host unconfigured'
    # pip3 config unset global.trusted-host > /dev/null 2>&1 && Info 'pip3 global trusted-host unconfigured'
    python -m pip config unset global.proxy > /dev/null 2>&1 && Info 'python pip global proxy unconfigured'
    python3 -m pip config unset global.proxy > /dev/null 2>&1 && Info 'python3 pip global proxy unconfigured'
    pip3 config unset global.proxy > /dev/null 2>&1 && Info 'pip3 global proxy unconfigured'
    
    # gcloud
    gcloud config unset custom_ca_certs_file > /dev/null 2>&1 && Info 'gcloud custom_ca_certs_file configured'
    # gcloud config unset proxy/type > /dev/null 2>&1 && Info 'gcloud proxy/type unconfigured'
    # gcloud config unset proxy/address > /dev/null 2>&1 && Info 'gcloud proxy/address unconfigured'
    # gcloud config unset proxy/port > /dev/null 2>&1 && Info 'gcloud proxy/port unconfigured'
    
    # java
    if /usr/libexec/java_home -V &>/dev/null; then
        keytool -delete -alias 'ZappConfig' -noprompt -trustcacerts -cacerts -storepass changeit > /dev/null 2>&1 && Info 'java cacerts unconfigured'
        # keytool -import -alias 'ZappConfig' -noprompt -trustcacerts -keystore "$(/usr/libexec/java_home)/lib/security/cacerts" -storepass changeit -file "${DER_CERT_PATH}"
    fi
    
    # android studio
    if [[ -d /Applications/Android\ Studio.app ]]; then
        if /usr/libexec/java_home -V &>/dev/null; then
            keytool -delete -alias 'ZappConfigAS' -noprompt -trustcacerts -keystore /Applications/Android\ Studio.app/Contents/jre/jdk/Contents/Home/jre/lib/security/cacerts -storepass changeit > /dev/null 2>&1 && Info 'android studio - java cacerts unconfigured'
        fi
    fi
    
}

Main "${@}"
