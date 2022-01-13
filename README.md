# All-in-One POC setup for Trend Micro Cloud One in Amazon AWS
Thank you very much @Renaud Bidou for your excellent resources

## Overview
- This will create the whole aws environment for Demo/PoC purpose and cover 5 components of Cloud One (conformity will be added later). However you can
- The provisoned resources include:
  - On AWS: EKS, Lambda functions, EC2, VPC, ECR, IAM Policies, IAM roles, CloudFormations stacks, CloudWatch log groups,...
  - On Cloud One:
    - C1WS agents will be auto-deployed on all provisioned EC2 (including eks nodes) without assigned policy
    - C1AS: new c1as group will be provisioned. TMVWA lambda function and TMVWA K8s application will be deployed for testing c1as features
    - C1CS: New c1cs policy, cluster and scanner will be provisioned, smartcheck will be deployed in EKS. You will need to add Harbor and ECR later to Smartcheck (see lab-guide)
    - C1FSS: 3 buckets created (Scan bucket for user to upload objects, Clean bucket contains all clean object after scan, Quarantine bucket contains quarantined objects) - *note* before destroy / cleanup the lab, you have to empty all 3 buckets, *otherwise terraform will fail to destroy*
    - C1NS: will be provisoned as described Deployment Option 1 (Edge Protection) https://cloudone.trendmicro.com/docs/network-security/Choose%20a%20deployment%20option/#inspect-inbound-internet-traffic

  - K8s apps: Applications like Harbor Registry, Trend Micro Smart Check, Jenkins, TMVWA (thank you @Renaud Bidou)
  (details can be found in user-data/lab-guide.tpl)
- Please prepare all the requested information *carefully* before running this script. Failure during the execution will cause you lots of time troubleshooting and cleaning up (**those are listed below**)

## How to use

### Requirements
- Prepare a Linux machine (*This terraform tested on Ubuntu 20.04 (but Amazon Linux 2 / Centos should be OK*).If you dont have one, you can create a t2.micro/t3a.micro EC2 Linux Amazon 2 for running this - please keep this EC2 (either running or stop state)  until you successfully destroy/cleanup the lab later.
- Terraform cli (https://www.terraform.io/downloads): below example works with Centos/RHEL, see the provided link for other OS
- AWS cli, git, jq
```
#install terraform
sudo yum install -y yum-utils

#for Centos/RHEL
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

sudo yum -y install terraform

# install required packages
sudo yum install -y git jq

# install aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
```
- an AWS Account
- Cloud One free trial (better to register new one to avoid unexpected things - https://cloudone.trendmicro.com/_workload_iframe/SignIn.screen# )
- a valid Deep Security API Key
- At the time of this document (Aug2021), C1-network security requires a Cross Account Role with a policy name *NetworkSecurityPolicy*. This policy name is kind of "hard-code", we could not change its name. So if you have an existing IAM Policy named *NetworkSecurityPolicy* then you will have to **rename that existing policy prior to execution of this terraform**. Otherwise it will fail to provision properly.

### Let's start
- Review and update values in terraform.tfvars-example to match your environment
- Save as new file, name it: terraform.tfvars  
- Review all others settings in variables.tf and change if neccessary (recommended to leave all as is if possible)
- When you are ready, open terminal and run below commands:
```
  $ git clone https://github.com/trendlabs/TrendMicro-CloudOne-POC.git
  $ cd TrendMicro-CloudOne-POC
  $ terraform init
  $ terraform plan
  $ terraform apply -auto-approve
```
*Note: terraform needs about 20-30mi to provision the lab*

- After infra provisioned,
  - get kubeconfig to connect to eks cluster:
  ```
  aws eks update-kubeconfig --region <aws region-code> --name <cluster-name>
  ```
  - make sure a file ***terraform.tfstate*** generated in the same folder. This file is critical for your to clean up all the labs after the session
  - a lab-guide file will be generated in the c1poc folder, open it for instructions
- To remove / clean-up all the infra, you will need to do the following:
  - Delete all the LoadBalancer created during the usage of EKS (AWS Mgmnt console \ EC2 \ Load Balancers) - those resources are not managed by this terraform and leaving them will cause terraform cannot clean up the environment
  - Once you delete the above, run below command in folder c1poc:
```
  $ cd TrendMicro-CloudOne-POC
  $ terraform destroy -auto-approve
```

## Lab access
- Once terraform finishes the provision, open the *lab-guide.txt* file (in folder *docs*) you will find all the info for lab usage there
-

## Troubleshooting

- Terraform can only manage the resources that it provisions so for other relating resources that you create during demo / PoC (ELB, S3 object in provisioned buckets, Route53 records,...) you will need to delete prior to run destroy command
