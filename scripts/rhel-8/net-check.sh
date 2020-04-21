source scripts/rhel-8/spawn.conf

echo -e "\n## Checking for network ##\n"

if virsh net-list --all | grep ${NETWORK_NAME} ; then

	echo "${NETWORK_NAME} exists."

else cat << EOF > /tmp/${NETWORK_NAME}.xml
<network>
  <name>${NETWORK_NAME}</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address='${NETWORK}.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='${NETWORK}.201' end='${NETWORK}.254'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/${NETWORK_NAME}.xml

fi

if virsh net-list | grep ${NETWORK_NAME} ; then
	echo "${NETWORK_NAME} is started."
else
	virsh net-start ${NETWORK_NAME}
	virsh net-autostart ${NETWORK_NAME}
fi

# Clean up

if [ -f /tmp/${NETWORK_NAME}.xml ]; then
rm /tmp/${NETWORK_NAME}.xml
fi

echo -e "\n"
