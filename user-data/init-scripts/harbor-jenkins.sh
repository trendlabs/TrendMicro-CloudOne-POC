#! /bin/bash
hostnamectl set-hostname harbor-jenkins
yum update -y
amazon-linux-extras install docker java-openjdk11 -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# install required packages
yum install -y git jq

# install docker-compose
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

mkdir -p /harbor /jenkins/jenkins-data /jenkins/jenkins-certs /etc/docker/certs.d/harbor.${COMMONNAME} /jenkins/jenkins-certs /etc/docker/certs.d/smartcheck.${COMMONNAME}:5000
chown -R 1000:1000 /jenkins/jenkins-data
cd /jenkins/jenkins-certs

cat <<-EOL | tee ca.crt
${ca_cert}
EOL

cat <<-EOL | tee ${COMMONNAME}.key
${private_key}
EOL

cat <<-EOL | tee ${COMMONNAME}.crt
${public_key}
EOL

cp ${COMMONNAME}.crt /etc/docker/certs.d/harbor.${COMMONNAME}/${COMMONNAME}.cert
cp ${COMMONNAME}.key /etc/docker/certs.d/harbor.${COMMONNAME}/
cp ca.crt /etc/docker/certs.d/harbor.${COMMONNAME}/

cp ${COMMONNAME}.crt /etc/docker/certs.d/smartcheck.${COMMONNAME}:5000/${COMMONNAME}.cert
cp ${COMMONNAME}.key /etc/docker/certs.d/smartcheck.${COMMONNAME}:5000/
cp ca.crt /etc/docker/certs.d/smartcheck.${COMMONNAME}:5000/

systemctl restart docker
chmod 666 /var/run/docker.sock

cd /jenkins

curl -O https://vnlabs-tmvwa.s3.ap-southeast-1.amazonaws.com/custom-jenkins/Dockerfile
sed -i 's/COMMONNAME/${COMMONNAME}/g' Dockerfile

curl https://vnlabs-tmvwa.s3.ap-southeast-1.amazonaws.com/custom-jenkins/casc.yaml -o jenkins-data/casc.yaml
sed -i 's/LABPASSWORD/${LABPASSWORD}/g' jenkins-data/casc.yaml
chown ec2-user:ec2-user casc.yaml

curl -O https://vnlabs-tmvwa.s3.ap-southeast-1.amazonaws.com/custom-jenkins/plugins.txt

docker build -t custom-jenkins:v1 .

cat <<EOL | tee docker-compose.yaml
version: '3.2'

networks:
  docker:

services:

  jenkins:
    image: custom-jenkins:v1
    restart: always
    networks:
      - docker
    ports:
      - 8443:8443
      - 50000:50000
    tty: true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - type: bind
        source: /jenkins/jenkins-data
        target: /var/jenkins_home
      - type: bind
        source: /jenkins/jenkins-certs
        target: /var/lib/jenkins
        read_only: true
      - type: bind
        source: /home/ec2-user
        target: /home
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock
      - DOCKER_CERT_PATH=/var/lib/jenkins
EOL

docker-compose up -d

cd /harbor
cert_path="/etc/docker/certs.d/harbor.${COMMONNAME}/${COMMONNAME}.cert"
key_path="/etc/docker/certs.d/harbor.${COMMONNAME}/${COMMONNAME}.key"
curl -sLO https://github.com/goharbor/harbor/releases/download/v2.1.0/harbor-offline-installer-v2.1.0.tgz
tar xvf harbor-offline-installer-v2.1.0.tgz --strip-components=1
cp harbor.yml.tmpl harbor.yml
sed -i 's/reg.mydomain.com/harbor.${COMMONNAME}/' harbor.yml
sed -i 's/Harbor12345/${LABPASSWORD}/' harbor.yml
sed -i "s+/your/certificate/path+$cert_path+" harbor.yml
sed -i "s+/your/private/key/path+$key_path+" harbor.yml
./install.sh --with-notary --with-chartmuseum

cat > /etc/systemd/system/harbor.service <<-EOF
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=https://goharbor.io/docs/

[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/bin/docker-compose -f /harbor/docker-compose.yml up
ExecStop=/usr/bin/docker-compose -f /harbor/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/jenkins.service <<-EOF
[Unit]
Description=Jenkins
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=https://jenkins.io/docs/

[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/bin/docker-compose -f /jenkins/docker-compose.yml up
ExecStop=/usr/bin/docker-compose -f /jenkins/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF

systemctl enable harbor.service
systemctl enable jenkins.service

curl https://vnlabs-tmvwa.s3.ap-southeast-1.amazonaws.com/dsa-install.sh -o /home/ec2-user/dsa-install.sh
chmod +x /home/ec2-user/dsa-install.sh
sed -i "s/IDENTITY/${identity}/g" /home/ec2-user/dsa-install.sh
/home/ec2-user/dsa-install.sh
