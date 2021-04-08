#!/usr/bin/env bash

# Description: Jamf Pro extension attribute to report Zscaler Internet Security (ZIA) status.

# EA Result Descriptions
# off = User pressed the 'Turn Off' button for ZIA via the Zapp GUI
# logout = User pressed the 'Logout' button via the Zapp GUI
# exit = User pressed the 'Exit' button via the Zapp tray icon
# on = ZIA is enabled
# killed = ZIA is enabled "according to the logs" but Zscaler launchdaemon(s) are not present/running indicating they may have been forcefully unloaded.
# needed = Zscaler is not installed (or has been moved, uninstalled, renamed, etc)
# error = Zscaler log not found (or path incorrect)

# make sure nothing _weird_ happens
set -Eeo pipefail
trap Cleanup SIGINT SIGTERM ERR
Cleanup() { trap - SIGINT SIGTERM ERR; echo '<result>error</result>'; }
( ((t = 9)); while ((t > 0)); do sleep 1; kill -0 $$ || exit 0; ((t -= 1)); done; kill -s SIGTERM $$ && kill -0 $$ || exit 0; sleep 1; kill -s SIGKILL $$; ) 2> /dev/null &
LOGGED_IN_USER="$(echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }')"

# zapp logs
ZAPP_LOG_PATH='/var/log/zscaler/com.zscaler.ZscalerService.log'
ZTRAY_LOG_PATH="$(/bin/ls -t /Users/"${LOGGED_IN_USER}"/Library/Application\ Support/com.zscaler.Zscaler/ZSATray* | /usr/bin/head -1)"

# zia status functions
ZappExists(){ if [[ -x '/Applications/Zscaler/Zscaler.app/Contents/MacOS/Zscaler' ]]; then true; else false; fi; }
ZappLogExists(){ if [[ -f "${ZAPP_LOG_PATH}" ]] && [[ -f "${ZTRAY_LOG_PATH}" ]]; then true; else false; fi; }
ZiaOffButtonPressed(){ declare result; result="$( /usr/bin/grep 'websecurity' "${ZAPP_LOG_PATH}" 2> /dev/null | /usr/bin/tail -n 1 )"; if [[ "${result}" =~ 'stop' ]]; then true; else false; fi; }
ZiaOffButtonPressedVerify(){ if /usr/bin/grep -E "websecurity = [0-9]{1}" "${ZTRAY_LOG_PATH}" | /usr/bin/tail -n 1 | /usr/bin/grep -q -E "[4|2]"; then false; else true; fi; }
ZappExitButtonPressed(){ declare result; result="$(/usr/bin/tail -n 1 "${ZAPP_LOG_PATH}")"; if [[ "${result}" =~ 'unloadTunnel' ]]; then true; else false; fi }
ZappLoggedOut(){ declare result; result="$(/usr/bin/tail -n 8 "${ZAPP_LOG_PATH}")"; if [[ "${result}" =~ 'logout' ]]; then true; else false; fi; }
ZappTunnelLoaded(){ declare result; result="$( /bin/launchctl list com.zscaler.tunnel 2> /dev/null )"; if [[ -n "${result}" ]]; then true; else false; fi; }

main(){

    if ZappExists; then
        if ZappLogExists; then
            if ZappLoggedOut && ! ZappTunnelLoaded; then
                echo '<result>logout</result>'
            elif ZappExitButtonPressed && ! ZappTunnelLoaded; then
                echo '<result>exit</result>'
            elif ZiaOffButtonPressed && ZiaOffButtonPressedVerify; then
                echo '<result>off</result>'
            elif ZappTunnelLoaded; then
                echo '<result>on</result>'
            else
                echo '<result>killed</result>'
            fi
        else
            echo '<result>error</result>'
        fi
    else
        echo '<result>needed</result>'
    fi
    
}

main "${@}"
