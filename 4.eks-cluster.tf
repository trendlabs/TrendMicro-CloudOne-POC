locals {
  // eks
  cluster_name = "${local.prefix}-eks-cluster"
  kube_config  = module.eks.cluster_certificate_authority_data

  eks_worker_node_init = templatefile("user-data/init-scripts/eks-worker-init.sh", {
    COMMONNAME  = var.dns-settings.lab_private_domain,
    IDENTITY    = local.c1ws_linux_tenant_token,
    public_key  = local.public_key,
    private_key = local.private_key,
    ca_cert     = local.ca_crt,
    HARBOR-IP   = (var.cloudone-settings.deploy_c1cs) ? aws_spot_instance_request.harbor-vm[0].private_ip : ""
  })

}

// Tao ECR de test Smart Check
resource "aws_ecr_repository" "poc" {
  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  name                 = "poc"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "poc"
    Vendor      = "Trend-Micro"
  }

}

data "aws_ecr_authorization_token" "ecr_token" {
  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
}

module "eks" {

  source = "terraform-aws-modules/eks/aws"

  create = var.cloudone-settings.deploy_c1cs

  cluster_name    = local.cluster_name
  cluster_version = "1.19"

  subnet_ids = local.eks-vpc-private-subnets

  enable_irsa = true // create OpenID Connect Provider for EKS to enable IRSA

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = local.cluster_name
  }

  vpc_id = local.eks-vpc-id

  self_managed_node_group_defaults = {
    root_volume_type    = "gp2"
    key_name            = var.general-settings.key_name
    additional_userdata = local.eks_worker_node_init

    additional_security_group_ids = [local.eks-node-sg-id] 
    workers_additional_policies   = [element(concat(aws_iam_policy.c1cs-AllowEKSExternalDNS-policy[*].arn, [null]), 0)]
    suspended_processes           = ["AZRebalance"]

    subnets = "${local.eks-vpc-private-subnets}"
  }

  self_managed_node_groups = [
    # {
    #   name                          = "on-demand-1"
    #   instance_type                 = "m4.xlarge"
    #   asg_max_size                  = 1
    #   kubelet_extra_args            = "--node-labels=node.kubernetes.io/lifecycle=normal"
    # },
    {
      name                 = "spot-1"
      spot_price           = var.general-settings.spot_price
      instance_type        = var.node-settings.spot_instance_type
      asg_desired_capacity = var.node-settings.asg_desired_capacity
      asg_max_size         = var.node-settings.asg_max_size
      kubelet_extra_args   = "--node-labels=node.kubernetes.io/lifecycle=spot"
      launch_template_name   = "spot-1"
    },
  ]

}
