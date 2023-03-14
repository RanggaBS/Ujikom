# Ganti nilai x di bawah ini menjadi nomor absen kalian
:local x 14


# Add gateway to the internet
/ip dhcp-client
if ([/ip dhcp-client find interface=ether1]={}) do={
	add interface=ether1 disabled=no
}

/ip firewall nat
if ([/ip firewall nat find chain=srcnat out-interface=ether1 action=masquerade]={}) do={
	add chain=srcnat out-interface=ether1 action=masquerade
}


# Centang "Enable Remote Request" pada menu IP > DNS 
#   *Digunakan agar klien wireless bisa mengakses situs web server
/ip dns set allow-remote-requests=yes


# Enable the wireless interface
/interface set wlan1 disabled=no


# Assign IP address to interfaces
/ip address
if ([/ip address find address=10.10.14.1/25 interface=wlan1]={}) do={
	add address=("10.10." . $x . ".1/25") interface=wlan1
}
if ([/ip address find address=10.10.14.129/26 interface=ether4]={}) do={
	add address=("10.10." . $x. ".129/26") interface=ether4
}


# Add IP pool
/ip pool
if ([/ip pool find name=wlan1_pool]={}) do={
	add name=wlan1_pool ranges=("10.10." . $x . ".2-10.10." . $x. ".101")
}
if ([/ip pool find name=ether4_pool]={}) do={
	add name=ether4_pool ranges=("10.10." . $x . ".130-10.10." . $x . ".179")
}


# Add DHCP server
/ip dhcp-server
if ([/ip dhcp-server find interface=wlan1]={}) do={
	add name=dhcp-wlan1 interface=wlan1 address-pool=wlan1_pool disabled=no
}
/ip dhcp-server
if ([/ip dhcp-server find interface=ether4]={}) do={
	add name=dhcp-ether4 interface=ether4 address-pool=ether4_pool disabled=no
}

/ip dhcp-server network
if ([/ip dhcp-server network find address=("10.10." . $x . ".0/25") gateway=("10.10." . $x . ".1")]={}) do={
	add address=("10.10." . $x . ".0/25") gateway=("10.10." . $x . ".1")
}
if ([/ip dhcp-server network find address=("10.10." . $x . ".128/26") gateway=("10.10." . $x . ".129")]={}) do={
	add address=("10.10." . $x . ".128/26") gateway=("10.10." . $x . ".129")
}


# Limit bandwidth
/queue simple
if ([/queue simple find target=wlan1]={}) do={
	add name=queue-limit-wlan1 target=wlan1 max-limit=128k/128k
}
if ([/queue simple find target=ether4]={}) do={
	add name=queue-limit-ether4 target=ether4 max-limit=256k/256k
}
