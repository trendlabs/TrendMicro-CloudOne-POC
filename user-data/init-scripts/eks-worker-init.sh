#!/bin/bash

mkdir -p /etc/docker/certs.d/${COMMONNAME}

cat <<-EOL | tee ca.pem
${ca_cert}
EOL

cat <<-EOL | tee ${COMMONNAME}.key
${private_key}
EOL

cat <<-EOL | tee ${COMMONNAME}.crt
${public_key}
EOL

echo "${HARBOR-IP} harbor.${COMMONNAME} jenkins.${COMMONNAME}" >> /etc/hosts

curl https://vnlabs-tmvwa.s3.ap-southeast-1.amazonaws.com/dsa-install.sh -o /home/ec2-user/dsa-install.sh
chmod +x /home/ec2-user/dsa-install.sh
sed -i "s/IDENTITY/${IDENTITY}/g" /home/ec2-user/dsa-install.sh
/home/ec2-user/dsa-install.sh
