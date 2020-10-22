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
    systemctl disable SuSEfirewall2
    systemctl stop SuSEfirewall2
    systemctl enable multipathd
    echo '*** Forcing root password change ***'
    passwd -e root

    echo '*** Changing GRUB ***'
    echo '*** Changing Kernel Parameters  ***'
    sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="transparent_hugepage=neverSave /' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg

    echo '*** adjusting cloud.cfg for openstack'
    sed -i -e '/mount_default_fields/{adatasource_list: [ NoCloud, OpenStack, None ]
    }' /etc/cloud/cloud.cfg
    sed -i -e 's/disable_root: true/disable_root: false/' /etc/cloud/cloud.cfg
    sed -i -e 's/- power-state-change/- power-state-change \n - reset_rmc/' /etc/cloud/cloud.cfg
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
    echo 'transparent_hugepage=never' >> /etc/sysctl.conf
    systemctl enable multipathd

    cloudpath="/var/lib/cloud/scripts/per-boot/cloud-script.sh"
    cloudpath_1="/var/lib/cloud/scripts/per-once/cloud-script.sh"
    cloudpath_2="/var/lib/cloud/scripts/per-once/multipath-script.sh"

    mkdir -p "$(dirname ${cloudpath})"
    mkdir -p "$(dirname ${cloudpath_1})"
    mkdir -p "$(dirname ${cloudpath_2})"

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
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin yes/PermitRootLogin without-password/g' /etc/ssh/sshd_config
systemctl restart sshd

EOL
    cat > ${cloudpath_2} << EOL
#!/bin/bash
device=\$(bootlist -o -m normal | grep '^sd')
dm=\$(multipath -ll /dev/\$device | grep sd.| grep -v \$device | head -4 | cut -c 14-16)
if ( test -n "\$dm" )
   then
   bootlist -o -m normal \$device \$dm
fi

EOL
    chmod 755 ${cloudpath_1}
    chmod 755 ${cloudpath_2}
    chmod 755 ${cloudpath}
fi
