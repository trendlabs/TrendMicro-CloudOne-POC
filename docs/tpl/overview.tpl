==========================================================================
==============Infrastructure Info for Cloud One PoC/demo ==================
==========================================================================
Note: some resources will have to be manually removed before run "terraform destroy" later to clean up the PoC lab. Those are:
  + EC2 Volumes,
  + EC2 Load Balancer (which might be created by the EKS when you deployed k8s applications)
  + Cloudwatch Log Groups
  + file in Scanbucket, Quarantine bucket, Clean bucket (can find infor below)

After terraform finish:

- There are 2 VPC created:
  + eks-vpc: 3 private & 3 public subnets (by default)
  + admin-vpc: 1 private & 1 public subnets (by default)

- Check the SNS topic below in the AWS Console for email billing alarm (only if you set a value greater than 0 to var.general-settings.monthly_billing_threshold )
  + SNS Topic: ${BILLSNSTOPIC}
- Only registered IP addresses will be allowed to access bastions RDP / SSH. Those are:
  [ ${ALLOWED_IPs} ]
If your public IP is not in this list, please add relevent security groups

- All the test cases for Workload Security, Application Security you can find here: https://wiki.jarvis.trendmicro.com/display/SE/POC+Project#
(Thank you very much MR. Renaud Bidou for these brilliant resources)

- There are some EC2 instances provisioned:
  + C1WS agents are installed on all of them, but without any policy.
  + Only 2 bastion hosts are desribed in this section, the others will be described in ClodOne - Container Security respectively
  1. Windows bastion host: This EC2 is placed in an admin-vpc public subnet
    - Public IP: ${WIN-RDP-IP}
    - RDP username: ${WIN-USER}
    - RDP password: ${LABPASSWORD}

  2. Linux bastion host (admin-vm host): This EC2 is placed in an admin-vpc public subnet. It has AdministrtorAccess role
    - Public IP: ${ADMINVM_PUBLIC_IP}
    - username: ec2-user
    - use PEM file generated by this script at top-level folder (file name: ${KEYFILE})
  There is a pem file placed in /home/ec2-user folder. This file will be used to ssh to other EC2 in the lab.Change its permission to 400
  $ chmod 400 ~/${KEYFILE}

- There are 2 version of TMVWA - see more informationin C1WS section below
  + TMVWA goes with TrendNet --> without C1AS protection: see information in C1CS section
  + TMVWA standalone --> with C1AS protection: see information in C1AS section

- Note for testing (Conditionally):
  + If also [ deploy_c1as = true ] there will be TMVWA application deployed in the EKS cluster
  + If also [ deploy_c1ns = true ] there is TMVWA application deployed in the cluster for testing C1NS
