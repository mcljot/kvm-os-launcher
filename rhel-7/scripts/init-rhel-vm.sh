#!/bin/bash

source rhel-7/scripts/spawn.conf

qemu-img create -f qcow2 /var/lib/libvirt/images/rhel-${1}.qcow2 ${DISK_SIZE}
virt-resize --expand /dev/sda1 ${TEMPLATE} ${DISK}

cat > /tmp/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
IPADDR="${NETWORK}.${1}"
NETMASK="255.255.255.0"
GATEWAY="${NETWORK}.254"
DNS1="${NETWORK}.254"
EOF

export LIBGUESTFS_BACKEND=direct

virt-customize -a ${DISK} \
--root-password password:redhat \
--hostname rhel-${1}.default.local \
--edit /etc/ssh/sshd_config:s/PasswordAuthentication\ no/PasswordAuthentication\ yes/g \
--copy-in /tmp/ifcfg-eth0:/etc/sysconfig/network-scripts \
--ssh-inject root \
--run-command '/usr/bin/yum -y remove cloud-init' \
--run-command 'echo "UseDNS no" >> /etc/ssh/sshd_config' \
--run-command 'systemctl disable NetworkManager' \
--run-command 'systemctl mask NetworkManager' \
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

echo -n "Waiting for ${NAME} to become available."
for i in {1..30}; do
  sleep .5 && echo -n "."
done
echo ""

if [ -f /root/.ssh/known_hosts ]; then 
	ssh-keygen -R ${NAME}
	ssh-keygen -R 192.168.122.${1}
fi

# cd ${ANSIBLE_PATH}
# ansible-playbook --ask-vault-pass register-system.yml --limit ${NAME}
