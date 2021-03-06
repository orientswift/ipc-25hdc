#!/bin/sh

[ -f /var/run/network ] && exit
touch /var/run/network

interfaceMode()
{
    INT=$1
    TYPE=$2

    mode=`nvram_get ${TYPE}_mode`

    # select network mode
    case "$mode" in
        dhcp)
            udhcpc -i $INT -n -p /var/run/udhcpc.$INT.pid
            return 1
            ;;
        static)
            address=`nvram_get ${TYPE}_address`
            mask=`nvram_get ${TYPE}_mask`
            ifconfig $INT $address netmask $mask
            return 0
            ;;
    esac

}

# enable loopback
ifconfig lo 127.0.0.1 up

# wifi config
wifi_enabled=`nvram_get wifi_enabled`

dhcp_enabled=0

if [ "$wifi_enabled" == "y" ] ; then

    # load nvram data
    SSID=`nvram_get SSID`
    WPAPSK=`nvram_get WPAPSK`
    WirelessMode=`nvram_get WirelessMode`
    EncrypType=`nvram_get EncrypType`
    CountryRegion=`nvram_get CountryRegion`
    CountryCode=`nvram_get CountryCode`
    WIFI_INT=ra0

    # create config folder
    mkdir -p "/etc/Wireless/RT2860"

    # create base config
    cat > "/etc/Wireless/RT2860/RT2860.dat" <<EOL
# The word of "Default" must not be removed
Default
NetworkType=Infra
Channel=1
AuthMode=WPA2PSK
CountryRegionABand=7
ChannelGeography=1
BeaconPeriod=100
TxPower=100
RxPower=100
TxBurst=1
HT_BW=1
SSID=$SSID
WPAPSK=$WPAPSK
WirelessMode=$WirelessMode
EncrypType=$EncrypType
CountryRegion=$CountryRegion
CountryCode=$CountryCode
EOL

    # enable wifi interface
    ifconfig $WIFI_INT up

    # config interface
    interfaceMode $WIFI_INT wifi

    # get return var
    dhcp_enabled=$?
fi

LAN_INT=eth2

# enable lan interface
ifconfig $LAN_INT up

# switch config
switch reg w 14 5555      # PFC1: Priority Flow Control –1
switch reg w 40 1001      # PVIDC0: PVID Configuration 0
switch reg w 44 1001      # PVIDC1: PVID Configuration 1
switch reg w 48 1001      # PVIDC2: PVID Configuration 2
switch reg w 4c 1         # PVIDC3: PVID Configuration 3
switch reg w 50 2001      # VLANI0: VLAN Identifier 0
switch reg w 70 ffffffff  # VMSC0: VLAN Member Port Configuration 0
switch reg w 98 7f7f      # POC2: Port Control 2
switch reg w a4 5         # LEDP0: LED Port0
switch clear

# config interface
interfaceMode $LAN_INT lan

# check if dhcp was enabled
if [ $? -eq 0 ] && [ $dhcp_enabled -eq 0 ] ; then

    # get default parameter
    gateway=`nvram_get default_gateway`
    dns=`nvram_get default_dns`
    domain=`nvram_get default_domain`

    # set default gateway
    route add default gw $gateway

    # set dns
    echo search $domain > /etc/resolv.conf
    echo nameserver $dns >> /etc/resolv.conf

fi
