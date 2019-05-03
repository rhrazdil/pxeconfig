# pxeconfig
Configure pxe boot on a machine, installs tftp and dhcp server, creates virtual interface 'testbridge', prepares PXE with CentOS remote installation

# Usage
```
sudo su -
git clone https://github.com/rhrazdil/pxeconfig.git
cd pxeconfig
./setup_pxe.sh
```

# Network Attachment Definition example
```
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: ovs-net-1
  namespace: default
spec:
  config: '{ "cniVersion": "0.3.1", "type": "bridge", "bridge": "testbridge", "ipam": {} }'
```
