HOME_DIR='/root'

yum -y install dhcp \
    xinetd \
    syslinux \
    syslinux-tftpboot \
    tftp-server \
    wget \
    selinux-policy-devel


if ip a | grep testbridge > /dev/null ; then
    echo "Test bridge already exists, skipping"
else
    # create bridge interface
    nmcli connection add con-name testbridge type bridge ifname testbridge ipv4.method disabled ipv6.method ignore autoconnect yes
    # assign an IP to it
    ip addr add 192.168.0.1/24 dev testbridge
    # enable the interface
    ifconfig testbridge up
fi

# add iptables rule
if iptables --list-rules  INPUT | grep testbridge >/dev/null ; then
    echo 'Iptables rule already exists, skipping'
else
    iptables -I INPUT 1 -s 192.168.0.0/24 -i testbridge -p udp -m udp --dport 69 -m state --state NEW,ESTABLISHED -j ACCEPT
fi

# store node eth0 IP address
node_ip=`/sbin/ifconfig eth0 | grep 'inet ' | cut -d: -f2 | awk '{ print $2}'`

# fill dhcpd.conf addresses
sed -i "s/SLAVE_IP/$node_ip/g" dhcpd.conf

# prepare tftpbood directory structure
mkdir -p /var/lib/tftpboot/pxelinux.cfg
mkdir -p /var/lib/tftpboot/centos7

# copy config files
yes | cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/pxelinux.0
yes | cp dhcpd.conf /etc/dhcp/dhcpd.conf
yes | cp tftp /etc/xinetd.d/tftp
cp default /var/lib/tftpboot/pxelinux.cfg/default

if [ ! -f /var/lib/tftpboot/centos7/initrd.img ]; then
    cd /var/lib/tftpboot/centos7
    wget http://mirror.centos.org/centos/7/os/x86_64/images/pxeboot/initrd.img
    wget http://mirror.centos.org/centos/7/os/x86_64/images/pxeboot/vmlinuz
    cd --
else
    echo "Initrd.img and vmlinuz already present"
fi

# start services
systemctl start xinetd 
systemctl start dhcpd

# prepare directory for local storage
mkdir -p /tmp/mylocalstorage/vol1
chmod --reference=/mnt/local-storage/hdd/disk1 /tmp/mylocalstorage/vol1
