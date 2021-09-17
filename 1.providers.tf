# Dynamically retrieve our public outgoing IP
data "http" "admin_public_ip" {
  url = "http://ipinfo.io/ip"
}

provider "aws" {
  /* NOTE: for demo / poc only, NOT security best practice, consider other authentication methods:
    Static credentials
    Environment variables
    Shared credentials/configuration file
    CodeBuild, ECS, and EKS Roles
    EC2 Instance Metadata Service (IMDS and IMDSv2)
*/
  access_key = var.general-settings.iam_access_id
  secret_key = var.general-settings.iam_access_secret

  region = var.general-settings.lab_region
}

provider "restapi" {
  uri = "https://"
  write_returns_object = true

  headers = {
    api-version    = "v1"
    api-secret-key = var.cloudone-settings.c1_api_key
  }

}

data "aws_eks_cluster" "cluster" {
  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  name  = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  name  = module.eks.cluster_id
}

provider "kubernetes" {

  host                   = element(concat(data.aws_eks_cluster.cluster[*].endpoint, [""]), 0)
  cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.cluster[*].certificate_authority.0.data, [""]), 0))
  token                  = element(concat(data.aws_eks_cluster_auth.cluster[*].token, [""]), 0)

}

provider "helm" {
  kubernetes {
    host                   = element(concat(data.aws_eks_cluster.cluster[*].endpoint, [""]), 0)
    cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.cluster[*].certificate_authority.0.data, [""]), 0))
    token                  = element(concat(data.aws_eks_cluster_auth.cluster[*].token, [""]), 0)
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}
