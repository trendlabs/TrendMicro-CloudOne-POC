locals {
  // Security Group
  eks-node-sg-id = aws_security_group.eks-node-sg[*].id  //data.aws_security_group.eks-node-sg.id
  admin-sg-id    = aws_security_group.admin-vpc-vm-sg.id //data.aws_security_group.admin-sg.id

  admin-sg-allowed-cidr = (var.cloudone-settings.deploy_c1ns) ? concat(["${local.admin_ip}"], local.attacker-ips, var.admin-vm-settings.allowed_IPs) : concat(["${local.admin_ip}"], var.admin-vm-settings.allowed_IPs)
}

###### Security group cho VM trong admin-VPC ############
resource "aws_security_group" "admin-vpc-vm-sg" {
  name        = "${local.prefix}-admin-vpc-sg"
  description = "${local.prefix}-poc admin-vm access controls"

  //always allow public ip of the computer running this script
  dynamic "ingress" {
    for_each = var.admin-vm-settings.ec2_allowed_inbound
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = var.admin-vm-settings.protocol
      cidr_blocks = local.admin-sg-allowed-cidr
    }
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.admin-vpc.vpc_id

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-sg-admin-vpc"
  }
}

####### Security group for EC2 in public subnets in attacker-vpc ############
resource "aws_security_group" "attacker-public-sg" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  name        = "${local.prefix}-attacker-public-sg"
  description = "${local.prefix}-poc attacker-vpc public access controls"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(["${local.admin_ip}"], var.admin-vm-settings.allowed_IPs)
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.attacker-vpc[0].vpc_id

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-attacker-public-sg"
  }
}

###### Security group cho eksmaster trong eks-vpc ############
resource "aws_security_group" "eks-node-sg" {

  count       = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  name        = "${local.prefix}-eks-node-sg"
  description = "${local.prefix}-poc eks-node access controls"

  // ingress rules to allow ALL incoming from admin-vm
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.eks-vpc[0].vpc_id

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-sg-eks-node"
  }
}
