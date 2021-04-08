#!/usr/bin/env bash

# script name: simple-zapp-config.sh
# description: configure various apps/tools to work with Zscaler (ZIA) enabled.
# author: @andy-cheatwood
# TODO: add sources where applicable
# changelog:
# 20210318 - script created
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
    local pem_cert="${cert_dir}/ZscalerRootCertificate-2048-SHA256.pem"
    local der_cert="${cert_dir}/ZscalerRootCertificate-2048-SHA256.crt"
    local bundle_cert="${cert_dir}/ZscalerRootCertificate-Bundle.pem"
    local proxy_url='http://gateway.zscaler.net'
    local proxy_port='80'
    local user_home="$(GetLoggedInUserHome)"
    
    # make certs directory
    /bin/mkdir -p "${cert_dir}"
    
    # get certs
    # TODO: maybe add more logic for certifi.
    /usr/bin/security find-certificate -c 'Zscaler' -p >"${pem_cert}"
    /usr/bin/openssl x509 -in "${pem_cert}" -outform der -out "${der_cert}"
    /bin/cat "$(python3 -m certifi)" "${pem_cert}" >"${bundle_cert}"
    
    # create and source _custom_ shell config
    /bin/cat > "${config_file}" <<EOF
    ### Zscaler Config ###
    export ZAPP_PROXY_URL="${proxy_url}:${proxy_port}"
    export HTTP_PROXY=\${ZAPP_PROXY_URL}
    export HTTPS_PROXY=\${ZAPP_PROXY_URL}
    export CERT_PATH="${bundle_cert}"
    export PEM_CERT_PATH="${pem_cert}"
    export DER_CERT_PATH="${der_cert}"
    export SSL_CERT_FILE=\${CERT_PATH}
    export SSL_CERT_DIR=\$(/usr/bin/dirname \${CERT_PATH})/
    export REQUESTS_CA_BUNDLE=\${CERT_PATH}
    export NODE_EXTRA_CA_CERTS=\${CERT_PATH}
EOF
    source "${config_file}"
    
    # add source to common shell configs
    if grep -q "source ${config_file}" "${user_home}/.bash_profile" 2>/dev/null; then
        Debug 'already sourced'
    else
        Info 'sourced custom shell config'
        Debug "Dir: ${config_file}"
        printf '%s\n' '' '### Zscaler Config ###' "source ${config_file}" >> "${user_home}/.bash_profile"
    fi
    if grep -q "source ${config_file}" "${user_home}/.zshrc" 2>/dev/null; then
        Debug 'already sourced'
    else
        Info 'sourced custom shell config'
        Debug "Dir: ${config_file}"
        printf '%s\n' '' '### Zscaler Config ###' "source ${config_file}" >> "${user_home}/.zshrc"
    fi
    
    # apps/tools config commands
    # macos app firewall
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Zscaler/Zscaler.app/Contents/MacOS/Zscaler --add /Applications/Zscaler/Zscaler.app/Contents/PlugIns/ZscalerTunnel --add /Applications/Zscaler/Zscaler.app/Contents/PlugIns/ZscalerService --add /Applications/Zscaler/.Updater/autoupdate-osx.app/Contents/MacOS/ZscalerUpdater > /dev/null 2>&1 && Info 'macos app firewall configured'
    
    # git
    git config --global http.sslcainfo "${CERT_PATH}" && Info 'git global http.sslcainfo configured'
    git config --global http.proxy "${ZAPP_PROXY_URL}" && Info 'git global http.proxy configured'
    git config --system http.sslcainfo "${CERT_PATH}" && Info 'git system http.sslcainfo configured'
    git config --system http.proxy "${ZAPP_PROXY_URL}" && Info 'git system http.proxy configured'
    
    # npm
    npm config set cafile "${CERT_PATH}" > /dev/null 2>&1 && Info 'npm cafile configured'
    npm config set proxy "${ZAPP_PROXY_URL}" > /dev/null 2>&1 && Info 'npm proxy configured'
    npm config set registry http://registry.npmjs.org/ --global > /dev/null 2>&1 && Info 'npm registry configured'
    
    # yarn
    yarn config set cafile "${CERT_PATH}" > /dev/null 2>&1 && Info 'yarn cafile configured'
    yarn config set proxy "${ZAPP_PROXY_URL}" > /dev/null 2>&1 && Info 'yarn proxy configured'
    
    # sft
    sft config network.tls_use_bundled_cas false > /dev/null 2>&1 && Info 'sft network tls_use_bundled_cas configured'
    sft config network.forward_proxy "${ZAPP_PROXY_URL}" > /dev/null 2>&1 && Info 'sft network forward_proxy configured'
    
    # python | pip
    python -m pip config set global.cert "${CERT_PATH}" > /dev/null 2>&1 && Info 'python pip global cert configured'
    python3 -m pip config set global.cert "${CERT_PATH}" > /dev/null 2>&1 && Info 'python3 pip global cert configured'
    pip3 config set global.cert "${CERT_PATH}" > /dev/null 2>&1 && Info 'pip3 global cert configured'
    python -m pip config set global.trusted-host 'pypi.python.org pypi.org files.pythonhosted.org' > /dev/null 2>&1 && Info 'python pip global trusted-host configured'
    python3 -m pip config set global.trusted-host 'pypi.python.org pypi.org files.pythonhosted.org' > /dev/null 2>&1 && Info 'python3 pip global trusted-host configured'
    pip3 config set global.trusted-host 'pypi.python.org pypi.org files.pythonhosted.org' > /dev/null 2>&1 && Info 'pip3 global trusted-host configured'
    python -m pip config set global.proxy "${ZAPP_PROXY_URL}" > /dev/null 2>&1 && Info 'python pip global proxy configured'
    python3 -m pip config set global.proxy "${ZAPP_PROXY_URL}" > /dev/null 2>&1 && Info 'python3 pip global proxy configured'
    pip3 config set global.proxy "${ZAPP_PROXY_URL}" > /dev/null 2>&1 && Info 'pip3 global proxy configured'
    
    # gcloud
    gcloud config set custom_ca_certs_file "${CERT_PATH}" > /dev/null 2>&1 && Info 'gcloud custom_ca_certs_file configured'
    # gcloud config set proxy/type http > /dev/null 2>&1 && Info 'gcloud proxy/type configured'
    # gcloud config set proxy/address "${proxy_url}" > /dev/null 2>&1 && Info 'gcloud proxy/address configured'
    # gcloud config set proxy/port "${proxy_port}" > /dev/null 2>&1 && Info 'gcloud proxy/port configured'
    
    # java
    if /usr/libexec/java_home -V &>/dev/null; then
        keytool -import -alias 'ZappConfig' -noprompt -trustcacerts -cacerts -storepass changeit -file "${DER_CERT_PATH}" > /dev/null 2>&1 && Info 'java cacerts configured'
        # keytool -import -alias 'ZappConfig' -noprompt -trustcacerts -keystore "$(/usr/libexec/java_home)/lib/security/cacerts" -storepass changeit -file "${DER_CERT_PATH}"
    fi
    
    # android studio
    if [[ -d /Applications/Android\ Studio.app ]]; then
        if /usr/libexec/java_home -V &>/dev/null; then
            keytool -import -alias 'ZappConfigAS' -noprompt -trustcacerts -keystore /Applications/Android\ Studio.app/Contents/jre/jdk/Contents/Home/jre/lib/security/cacerts -storepass changeit -file "${DER_CERT_PATH}" > /dev/null 2>&1 && Info 'android studio - java cacerts configured'
        fi
    fi
    
}

Main "${@}"
