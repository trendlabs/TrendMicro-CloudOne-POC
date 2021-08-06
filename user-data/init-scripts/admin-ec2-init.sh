#! /bin/bash

HOME_PATH="/home/ec2-user"

aws configure set aws_access_key_id ${access_key_id}
aws configure set aws_secret_access_key ${access_secret_key}
aws configure set default.region ${lab_region}

hostnamectl set-hostname admin-vm
mkdir $HOME_PATH/data
mkdir -p $HOME_PATH/bin
export PATH=$PATH:$HOME_PATH/bin

# install git & docker
yum update -y
yum install git -y
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# install aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

# install docker-compose
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

curl -o bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl
chmod +x bin/kubectl

curl -o bin/aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/aws-iam-authenticator
chmod +x bin/aws-iam-authenticator

curl https://vnlabs-tmvwa.s3.ap-southeast-1.amazonaws.com/dsa-install.sh -o $HOME_PATH/dsa-install.sh
chmod +x $HOME_PATH/dsa-install.sh
sed -i 's/IDENTITY/${identity}/g' $HOME_PATH/dsa-install.sh
$HOME_PATH/dsa-install.sh

cd $HOME_PATH/data

if ${deploy_c1as}; then

cat <<EOF | tee trend_app_protect.ini > /dev/null
[trend_app_protect]
key = ${c1as_group_key}
secret = ${c1as_group_secret}
EOF
cat <<EOF | tee Dockerfile > /dev/null
FROM rbidou/tmvwa-base:1.1

COPY trend_app_protect.ini .

CMD [ "python3", "./tmvwa.py" ]
EXPOSE 80/tcp
EOF

docker build -t tmvwa:1.1 .

else
docker pull rbidou/tmvwa:1.1
docker tag rbidou/tmvwa:1.1 tmvwa:1.1
fi

if ${deploy_c1cs}; then

  mkdir $HOME_PATH/.kube
  echo "${kube_config}" > $HOME_PATH/.kube/config
  chmod 400 $HOME_PATH/.kube/config

  aws ecr get-login-password --region ${lab_region} | docker login --username AWS --password-stdin ${aws_acc_id}.dkr.ecr.${lab_region}.amazonaws.com
  docker tag tmvwa:1.1 ${aws_acc_id}.dkr.ecr.${lab_region}.amazonaws.com/poc:v1
  docker push ${aws_acc_id}.dkr.ecr.${lab_region}.amazonaws.com/poc:v1

  cat > patch-coredns.json <<-EOF
data:
 Corefile: |
   ${hosted_dns} {
      route53 ${hosted_dns}.:${route53_zone_id}
      log
    }
   .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
EOF
  kubectl patch cm coredns -n kube-system --type merge -p "$(cat patch-coredns.json)"

fi
chown -R ec2-user:ec2-user $HOME_PATH/
docker run -p80:80/tcp tmvwa:1.1
