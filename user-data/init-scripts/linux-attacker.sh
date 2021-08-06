#! /bin/bash
hostnamectl set-hostname linux-attacker
yum update -y
amazon-linux-extras enable python3.8
amazon-linux-extras install docker python3.8 -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# install required packages
yum install -y git jq
#
# $hostsFile  = "/etc/hosts"
#
# echo '$LINUX-VICTIM linux-victim' >> $hostsFile
# echo '$WINDOWS-VICTIM windows-victim' >> $hostsFile

curl https://vnlabs-tmvwa.s3.ap-southeast-1.amazonaws.com/dsa-install.sh -o /home/ec2-user/dsa-install.sh
chmod +x /home/ec2-user/dsa-install.sh
sed -i 's/IDENTITY/${identity}/g' /home/ec2-user/dsa-install.sh
/home/ec2-user/dsa-install.sh
