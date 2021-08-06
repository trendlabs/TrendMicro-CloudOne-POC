locals {
  //VPC
  eks-vpc-id              = element(concat(module.eks-vpc[*].vpc_id, [""]), 0)
  eks-vpc-private-subnets = (var.cloudone-settings.deploy_c1cs) ? module.eks-vpc[0].private_subnets : null
  eks-vpc-public-subnets  = (var.cloudone-settings.deploy_c1cs) ? module.eks-vpc[0].public_subnets : null

  attacker-vpc-id             = element(concat(module.attacker-vpc[*].vpc_id, [""]), 0)
  attacker-vpc-public-subnets = (var.cloudone-settings.deploy_c1ns) ? module.attacker-vpc[0].public_subnets : null

  admin-vpc-id   = module.admin-vpc.vpc_id
  admin-subnet-0 = module.admin-vpc.public_subnets[0]
  admin-subnet-1 = (var.cloudone-settings.deploy_c1ns) ? aws_subnet.admin-subnet-1[0].id : null
}

data "aws_availability_zones" "available" {}

module "eks-vpc" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  source = "terraform-aws-modules/vpc/aws"

  name            = "${local.prefix}-vpc-eks"
  cidr            = var.network-settings.eks_vpc_cidr
  azs             = data.aws_availability_zones.available.names
  private_subnets = var.network-settings.eks_vpc_private_subnets
  public_subnets  = var.network-settings.eks_vpc_public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  //enable DNS for Route53 private hosted zone
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    Terraform                                     = "true"
    Environment                                   = "poc"
    Name                                          = "${local.prefix}-vpc-eks"
    Vendor                                        = "Trend Micro"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

resource "time_sleep" "wait-for-eks-vpc" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [
    module.eks-vpc
  ]

  create_duration = "30s"

}

module "admin-vpc" {

  source = "terraform-aws-modules/vpc/aws"
  name   = "${local.prefix}-vpc-admin"
  cidr   = var.network-settings.admin_vpc_cidr

  public_subnets = [var.network-settings.admin_vpc_public_subnets[0]]

  private_subnets = var.network-settings.admin_vpc_private_subnets

  azs = [data.aws_availability_zones.available.names[0]]

  //enable DNS for Route53 private hosted zone
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-vpc-admin"
    Vendor      = "Trend Micro"
  }
}


resource "time_sleep" "c1ns-wait-for-admin-vpc" {

  depends_on      = [module.admin-vpc]
  create_duration = "30s"

}

resource "aws_vpc_peering_connection" "vpc-peering" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  vpc_id      = module.admin-vpc.vpc_id
  peer_vpc_id = module.eks-vpc[0].vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-peering-connection"
    Vendor      = "Trend Micro"
  }

}

# Create a route in module.admin-vpc.public_route_table_ids in case need_c1cs
# this route for vpc-peering to eks-vpc
resource "aws_route" "admin-2-eks" {

  count                     = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  route_table_id            = module.admin-vpc.public_route_table_ids[0]
  destination_cidr_block    = module.eks-vpc[0].vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering[0].id

}

# Create a route in module.eks-vpc.private_route_table_ids in case need_c1cs
# this route for vpc-peering to admin-vpc

resource "aws_route" "eks-2-admin" {

  count                     = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  route_table_id            = module.eks-vpc[0].private_route_table_ids[0]
  destination_cidr_block    = module.admin-vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering[0].id

}

################# For C1NS demo ###################

module "attacker-vpc" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  source = "terraform-aws-modules/vpc/aws"
  name   = "${local.prefix}-attacker-vpc"
  cidr   = var.network-settings.attacker_vpc_cidr

  public_subnets = var.network-settings.attacker_vpc_public_subnets

  private_subnets = var.network-settings.attacker_vpc_private_subnets

  azs = [data.aws_availability_zones.available.names[0]]

  //enable DNS for Route53 private hosted zone
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-vpc-attacker"
    Vendor      = "Trend Micro"
  }
}
