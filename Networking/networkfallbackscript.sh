timeout="5 seconds"
endpoints="1.1.1.1 8.8.8.8"

get_rfc_now() {
    date -u --rfc-3339=seconds
}

ping_endpoint() {
    endpoint=$1
    ping -c 1 -q -W 2 $endpoint | grep " 0%"
}

switch_to_fallback_dhcp() {
    nmcli connection down BridgeForSecondIP
    nmcli connection up Fallback-DHCP
}

#could be used in future extension?
switch_to_bridge_dualIP() {
    nmcli connection down Fallback-DHCP
    nmcli connection up BridgeForSecondIP
}

wait_for_timeout() {
    endpoint=$1
    timeoutSpan=$2
    successLast=$(get_rfc_now)

    while [ $(date -u +%s) -le $(date -ud "$successLast +$timeoutSpan" +%s) ]; do
        success=0
        for target in $endpoint; do
            result=$(ping_endpoint $target)
            if [ "$result" ]; then
                success=1
                break
            else
                echo "Warning: Endpoint" $target "failed at" $(get_rfc_now)
            fi
        done

       if [ "$success" -eq "1" ]; then
            successLast=$(get_rfc_now)

            # Ping instantly exits because of -c 1, so let's not spam pings please.
            sleep 1
        else
            echo "Warning: Packet dropped at" $(get_rfc_now)
        fi
    done
}

while true; do
    wait_for_timeout "$endpoints" "$timeout"

    echo "Internet unreachable for the last $timeout, switching to emergency fallback DHCP!"
    switch_to_fallback_dhcp
    echo "We are now on emergency networking. Restarting script to check for connectivity" 

#could be used in interactive mode
#    while true; do
#        read -p "Did you reset the interface and want to restart? [y/n]" yn
#        case $yn in
#            [Yy]* ) break;;
#            [Nn]* ) exit;;
#            * ) echo "Please answer [y]es or [n]o.";;
#        esac
#    done
done
