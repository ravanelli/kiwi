#!/bin/bash
# Copyright (c) 2015 SUSE LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

if [[ "${kiwi_profiles}" == "raw-btrfs-cloud-init" ]]; then
    systemctl mask systemd-firstboot.service
    suseInsertService cloud-init-local
    suseInsertService cloud-init
    suseInsertService cloud-config
    suseInsertService cloud-final

    systemctl disable firewalld
    systemctl stop firewald

    echo '*** adjusting cloud.cfg for openstack'
    sed -i -e '/mount_default_fields/{adatasource_list: [ NoCloud, OpenStack, None ]
    }' /etc/cloud/cloud.cfg
    sed -i -e 's/disable_root: true/disable_root: false/' /etc/cloud/cloud.cfg
    echo "tuning for largesend of /etc/sysctl.conf file"
    path="/etc/sysconfig/network/"
    for file in `ls $path`
        do
        if [[ $file == ifcfg* ]];
            then
            echo "Removing MAC from:" $file
            sed '/^LLADDR/d' $path$file
        fi
    done
    echo "tuning for largesend of /etc/sysctl.conf file"
    cat >>  "/etc/sysctl.conf"  << EOL
net.core.rmem_max = 56623104
net.core.wmem_max = 56623104
net.ipv4.tcp_rmem = 65536 262088 56623104
net.ipv4.tcp_wmem = 65536 262088 56623104
net.ipv4.tcp_mem = 56623104 56623104 56623104
EOL

    cloudpath="/var/lib/cloud/scripts/per-boot/cloud-script.sh"
    cloudpath_1="/var/lib/cloud/scripts/per-once/cloud-script.sh"
    mkdir -p "$(dirname ${cloudpath})"
    mkdir -p "$(dirname ${cloudpath_1})"
    cat > ${cloudpath} << EOL
#!/bin/bash
for ethdev in \$(ip -o link show | awk -F': ' '{print \$2}')
    do
      ethtool -K \${ethdev} tso on
done
EOL
    cat > ${cloudpath_1} << EOL
#!/bin/bash
systemd-machine-id-setup
EOL
    chmod 755 ${cloudpath_1}
    chmod 755 ${cloudpath}

fi

