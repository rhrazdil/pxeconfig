HOME_DIR='/root'

yum -y install dhcp \
    xinetd \
    syslinux \
    syslinux-tftpboot \
    tftp-server \
    wget \
    selinux-policy-devel

if hash ovs-vsctl 2>/dev/null; then
    echo "Openvswitch installed, skipping"
else
    # Install required packages
    yum -y install  make \
                gcc \
                openssl-devel \
                autoconf automake \
                rpm-build \
                redhat-rpm-config \
                python-devel \
                openssl-devel \
                kernel-devel \
                kernel-debug-devel \
                libtool          
    # build and install openvswitch
    mkdir -p $HOME_DIR/rpmbuild/SOURCES
    wget -P $HOME_DIR/ http://openvswitch.org/releases/openvswitch-2.7.7.tar.gz
    cp $HOME_DIR/openvswitch-2.7.7.tar.gz $HOME_DIR/rpmbuild/SOURCES/
    cd $HOME_DIR/rpmbuild/SOURCES/
    tar xfz openvswitch-2.7.7.tar.gz
    sed 's/openvswitch-kmod, //g' openvswitch-2.7.7/rhel/openvswitch.spec > openvswitch-2.7.7/rhel/openvswitch_no_kmod.spec
    rpmbuild -bb --nocheck openvswitch-2.7.7/rhel/openvswitch_no_kmod.spec
    yum -y localinstall $HOME_DIR/rpmbuild/RPMS/x86_64/openvswitch-2.7.7-1.x86_64.rpm
    cd $HOME_DIR/pxeconfig
fi

if ip a | grep testbridge > /dev/null ; then
    echo "Test bridge already exists, skipping"
else
    # create bridge interface
    ovs-vsctl add-br testbridge
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
# store testbridge interface mac address
testbridge_mac=`cat /sys/class/net/testbridge/address`

# fill dhcpd.conf addresses
sed -i "s/SLAVE_IP/$node_ip/g" dhcpd.conf
sed -i "s/INT_MAC/$testbridge_mac/g" dhcpd.conf

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
