locals {
  prefix   = "trendmicro"
  admin_ip = join("/", [data.http.admin_public_ip.body, "32"])
  admin_user_data = templatefile("./user-data/init-scripts/admin-ec2-init.sh", {
    hosted_dns        = var.dns-settings.lab_private_domain,
    aws_acc_id        = var.general-settings.lab_aws_acc,
    access_secret_key = var.general-settings.iam_access_secret,
    access_key_id     = var.general-settings.iam_access_id,
    lab_region        = var.general-settings.lab_region,
    route53_zone_id   = aws_route53_zone.private-dns-admin.zone_id,
    c1as_group_key    = local.c1as_group_key,
    c1as_group_secret = local.c1as_group_secret,
    kube_config       = local.kube_config,
    identity          = local.c1ws_linux_tenant_token,
    deploy_c1cs       = var.cloudone-settings.deploy_c1cs,
    deploy_c1as       = var.cloudone-settings.deploy_c1as,
    # You'll need to generate your own keys at: https://www.google.com/recaptcha/admin
    RECAPTCHA_PRIV_KEY = var.general-settings.RECAPTCHA_PRIV_KEY
    RECAPTCHA_PUB_KEY  = var.general-settings.RECAPTCHA_PUB_KEY
  })

  harbor_user_data = templatefile("user-data/init-scripts/harbor-jenkins.sh", {
    COMMONNAME  = var.dns-settings.lab_private_domain,
    LABPASSWORD = var.general-settings.lab_password,
    identity    = local.c1ws_linux_tenant_token,
    public_key  = local.public_key,
    private_key = local.private_key,
    ca_cert     = local.ca_crt
  })

}

#. create ec2
resource "aws_spot_instance_request" "admin-vm" {

  spot_price           = var.general-settings.spot_price
  wait_for_fulfillment = true
  spot_type            = var.general-settings.spot_type

  ami                    = var.admin-vm-settings.ec2_ami
  instance_type          = var.admin-vm-settings.ec2_instance_type
  key_name               = var.general-settings.key_name
  vpc_security_group_ids = [local.admin-sg-id]
  subnet_id              = local.admin-subnet-0

  user_data = local.admin_user_data

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 20
    volume_type           = "gp2"
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "admin-vm"
  }

}

resource "aws_spot_instance_request" "win-rdp" {

  spot_price           = var.general-settings.spot_price
  wait_for_fulfillment = true
  spot_type            = var.general-settings.spot_type

  ami           = var.admin-vm-settings.ec2_win_ami
  instance_type = var.admin-vm-settings.ec2_win_instance_type

  vpc_security_group_ids = [local.admin-sg-id]
  subnet_id              = (var.cloudone-settings.deploy_c1ns) ? local.admin-subnet-1 : local.admin-subnet-0

  user_data = templatefile("./user-data/init-scripts/win-rdp.ps1", {
    lab_password          = var.general-settings.lab_password,
    win_username          = var.general-settings.win_username,
    win_user_fullname     = var.general-settings.win_user_fullname,
    win_deployment_script = local.c1ws_win_deployment_script,
    key                   = tls_private_key.private-key.private_key_pem,
    keyfile               = local.keyfile
  })

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "win-rdp"
    Vendor      = "Trend Micro"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 60
    volume_type           = "gp2"
  }

}


resource "aws_spot_instance_request" "linux-attacker" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  spot_price           = var.general-settings.spot_price
  wait_for_fulfillment = true
  spot_type            = var.general-settings.spot_type

  ami           = var.admin-vm-settings.ec2_ami
  instance_type = var.admin-vm-settings.ec2_instance_type

  key_name = var.general-settings.key_name

  vpc_security_group_ids = [aws_security_group.attacker-public-sg[0].id]
  subnet_id              = local.attacker-vpc-public-subnets[0]

  user_data = templatefile("user-data/init-scripts/linux-attacker.sh", {
    identity = local.c1ws_linux_tenant_token,
  })

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 30
    volume_type           = "gp2"
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "linux-attacker"
    Vendor      = "Trend Micro"
  }

}

# windows victim in eks-vpc public subnet 1A
resource "aws_spot_instance_request" "windows-attacker" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  spot_price           = var.general-settings.spot_price
  wait_for_fulfillment = true
  spot_type            = var.general-settings.spot_type

  ami           = var.admin-vm-settings.ec2_win_ami
  instance_type = var.admin-vm-settings.ec2_win_instance_type
  // key_name               = var.general-settings.key_name

  vpc_security_group_ids = [aws_security_group.attacker-public-sg[0].id]
  subnet_id              = local.attacker-vpc-public-subnets[0]

  user_data = templatefile("./user-data/init-scripts/windows-attacker.ps1", {
    lab_password          = var.general-settings.lab_password,
    win_username          = var.general-settings.win_username,
    win_user_fullname     = var.general-settings.win_user_fullname,
    win_deployment_script = local.c1ws_win_deployment_script,
    key                   = tls_private_key.private-key.private_key_pem,
    keyfile               = local.keyfile
  })

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "windows-attacker"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 60
    volume_type           = "gp2"
  }

}

resource "aws_spot_instance_request" "harbor-vm" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [ time_sleep.wait-for-eks-vpc ]

  spot_price           = var.general-settings.spot_price
  wait_for_fulfillment = true
  spot_type            = var.general-settings.spot_type

  ami           = var.admin-vm-settings.ec2_ami
  instance_type = var.admin-vm-settings.ec2_instance_type

  key_name = var.general-settings.key_name

  vpc_security_group_ids = local.eks-node-sg-id
  subnet_id              = local.eks-vpc-private-subnets[0]

  //iam_instance_profile = aws_iam_instance_profile.ec2-instance-profile.id

  user_data = local.harbor_user_data

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 100
    volume_type           = "gp2"
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "Harbor-Jenkins"
    Vendor      = "Trend Micro"
  }

}

# resource "null_resource" "upload_ssh_pem_file_admin_vm" {
#   depends_on = [local_file.private-key]
#
#   provisioner "file" {
#     source      = local.keyfile
#     destination = "/home/ec2-user/${local.keyfile}"
#
#     connection {
#       type        = "ssh"
#       user        = "ec2-user"
#       private_key = file("${local.keyfile}")
#       host        = aws_spot_instance_request.admin-vm.public_ip
#       agent       = "false"
#     }
#     on_failure = continue
#   }
#
# }
