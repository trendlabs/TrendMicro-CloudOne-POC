
==========================================================================
==============CloudOne - Container Security Info for PoC/demo ============
==========================================================================

- This section is relevant if you specified [ deploy_c1cs = true ] in your cloudone-settings section in terraform.tfvars file

- There is an EC2 provisioned in EKS VPC private subnet for serving Harbor and Jenkins
  + As named, this is for Harbor and Jenkins, it is created only if you specify [deploy_c1cs = true] in terraform.tfvars file
  + You can only ssh to it from either windows or linux bastion host: but you will not need to unless there might be some other tasks that need you to change the default setup
    . Private IP: ${HARBOR_PRIVATE_IP}
    . username: ec2-user
    . PEM file is ~/${KEYFILE}
      $ ssh -i ~/${KEYFILE} ec2-user@${HARBOR_PRIVATE_IP}

- An EKS with 2 worker nodes will be provisioned. From admin-vm host you can run kubectl commands to administer EKS cluster, for example to get all the nodes of the cluster:
$ kubectl get no -o wide
You can see private IP addresses of 2 nodes.If you want to ssh to a node you can do it from admin-vm with above pem file.

- An AWS ECR repo also provisioned, it is: ${ECR_URL}
In admin-vm, you can push a container image to this ECR:
$ docker image ls
$ aws ecr get-login-password --region ${LAB_REGION} | docker login --username AWS --password-stdin ${AWS_ACC_ID}.dkr.ecr.${LAB_REGION} .amazonaws.com
$ docker tag tmvwa:1.1 ${AWS_ACC_ID}.dkr.ecr.${LAB_REGION}.amazonaws.com/poc:v1.1
$ docker push ${AWS_ACC_ID}.dkr.ecr.${LAB_REGION}.amazonaws.com/poc:v1.1

- Smartcheck & C1CS Admission Controller are installed in namespace trendmicro with a "default" C1CS policy
$ kubectl get all -n trendmicro
They are also registered to CLoudOne - Container Security, you can check in the CloudOne web console and change policy accordingly.
  + The policy name is: ${C1CS_POLICY}
  + The Cluster:
    . name is: ${C1CS_CLUSTER}
    . APIKey is: ${C1CS_CLUSTER_APIKEY}
  + The Scanner:
    . name is: ${C1CS_SCANNER}
    . APIKey is: ${C1CS_SCANNER_APIKEY}

- From Windows bastion, you can access
  + Harbor: ${HARBOR_URL}
    . username: admin
    . password: ${LABPASSWORD}
  In Harbor, create a username, and create a new project and add the new user to project members
  + Jenkins: ${JENKINS_URL}
    . username: admin
    . password: ${LABPASSWORD}
  In Jenkins you can create a project with a Jenkinsfile to see Smartcheck in action for CI/CD pipeline integration
  + Smartcheck: ${SMARTCHECK_URL}
    . username: administrator
    . password: ${LABPASSWORD}
  Note: for the 1st time, smartcheck will ask you to change password.

- Then you can integrate Harbor with Smartcheck: harbor.${DOMAIN}.
Remember to Skip TLS verification because we use self-signed cert for SSL

- You can also push a docker image to Harbor project repo using the credentials above, for example:
$ docker image ls
$ docker login harbor.${DOMAIN}
$ docker tag tmvwa:1.1 harbor.${DOMAIN}/<new_project>:v1
$ docker push harbor.${DOMAIN}/<new_project>:v1

- Then you can go to SmartCheck to Scan repo and get findings

- CodeCommitRepo URL: $CodeCommitRepoURL
- CodeCommitInstanceRole to add to Jenkins server: $CodeCommitInstanceRole
- AWS IAM Access Key ID: $CodeCommitUserID
- AWS IAM Access Key Secret: (You will need to run below command to decrypt).
And you might be asked for keybase password that you created previously in keybase.io )

echo $CodeCommitEncryptedSecret | base64 --decode | keybase pgp decrypt
