#!/bin/bash

source scripts/rhel-8/spawn.conf

# Check for prerequisites

# Create an SSH key for root if one does not already exist

if [ ! -f /root/.ssh/id_rsa ]; then
	ssh-keygen -t rsa -b 2048 -N "" -f /root/.ssh/id_rsa
fi

# If an SSH key exists for this VM (from a previous deploy) remove it

echo -e "## Cleaning up known_hosts ##\n"

if [ -f /root/.ssh/known_hosts ]; then
	ssh-keygen -R ${NAME}
	ssh-keygen -R ${NETWORK}.${1}
fi

if [ -f /home/${USER}/.ssh/known_hosts ]; then
        ssh-keygen -R ${NAME}
        ssh-keygen -R ${NETWORK}.${1}
fi

echo -e "\n"

# Check for needed packages

if [ ! -f /usr/bin/virt-customize ]; then
	yum -y install libguestfs-tools-c
fi

if [ ! -f /usr/bin/virt-install ]; then
	yum -y install virt-install
fi

echo -n "Checking for template: "

if [ ! -f ${TEMPLATE} ]; then
	echo -e "\E[0;31m${TEMPLATE} not found!\E[0m"
	echo -e "You can change the path and image for the desired template in scripts/rhel-8/spawn.conf.\n"
	exit 1
else
	echo -e "\E[0;32mFound!\E[0m\n"

fi


qemu-img create -f qcow2 ${DISK} ${DISK_SIZE}
virt-resize --expand /dev/sda1 ${TEMPLATE} ${DISK}

cat > /tmp/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
IPADDR="${NETWORK}.${1}"
NETMASK="255.255.255.0"
GATEWAY="${NETWORK}.1"
DNS1="${NETWORK}.1"
EOF

export LIBGUESTFS_BACKEND=direct

virt-customize -a ${DISK} \
--root-password password:redhat \
--hostname ${NAME}.${NETWORK_NAME}.local \
--edit /etc/ssh/sshd_config:s/PasswordAuthentication\ no/PasswordAuthentication\ yes/g \
--copy-in /tmp/ifcfg-eth0:/etc/sysconfig/network-scripts \
--ssh-inject root \
--run-command '/usr/bin/yum -y remove cloud-init' \
--run-command 'echo "UseDNS no" >> /etc/ssh/sshd_config' \
--run-command 'echo "nameserver 8.8.8.8" >> /etc/resolv.conf' \
--selinux-relabel && rm /tmp/ifcfg-eth0

/usr/bin/virt-install \
--disk path=${DISK} \
--import \
--vcpus ${VCPUS} \
--network network=${NETWORK_NAME} \
--name ${NAME} \
--ram ${MEMORY} \
--os-type=linux \
--os-variant=rhel7.5 \
--dry-run --print-xml > /tmp/rhel75.xml

virsh define --file /tmp/rhel75.xml && rm /tmp/rhel75.xml

virsh start ${NAME}

# echo -n "Waiting for ${NAME} to become available."
# for i in {1..30}; do
#   sleep .5 && echo -n "."
# done
# echo ""

# cd ${ANSIBLE_PATH}
# ansible-playbook --ask-vault-pass register-system.yml --limit ${NAME}
