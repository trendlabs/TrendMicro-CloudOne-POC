output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks[*].cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks[*].cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks[*].cluster_security_group_id
}

output "kubectl_config" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks[*].cluster_certificate_authority_data
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks[*].aws_auth_configmap_yaml
}

output "region" {
  description = "AWS region"
  value       = var.general-settings.lab_region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = local.cluster_name
}

output "private_domain" {
  description = "Lab private domain"
  value       = var.dns-settings.lab_private_domain
}

output "private_zone_id" {
  description = "Route53 private domain - zone id"
  value       = aws_route53_zone.private-dns-admin.zone_id
}

output "lab_password" {
  description = "Lab Default password"
  value       = var.general-settings.lab_password
}

output "c1cs_cluster_apikey" {
  description = "C1CS CLuster API key"
  value       = local.c1cs_cluster_apikey
}

output "c1cs_scanner_apikey" {
  description = "C1CS Scanner API key"
  value       = local.c1cs_scanner_apikey
}

output "harbor-jenkins_private_ip" {
  description = "Private IP of Harbor & Jenkins machine"
  value       = aws_spot_instance_request.harbor-vm[*].private_ip
}
output "S3BucketToScan" {
  description = "S3 bucket to scan"
  value       = (var.cloudone-settings.deploy_c1fss) ? module.lab_s3bucket.*.s3_bucket_id : null
}

output "Quarantine-S3-Bucket" {
  description = "Quarantine S3 bucket"
  value       = (var.cloudone-settings.deploy_c1fss) ? module.lab_quarantine_s3bucket.*.s3_bucket_id : null
}

output "ecr_url" {
  description = "AWS PoC ecr Repo URL"
  value       = local.ecr-url
}

output "ecr_login" {
  description = "AWS ECR Login password"
  sensitive   = true
  value       = local.ecr-password
}

output "admin-vm_public_ip" {
  description = "Admin VM public IP"
  value       = aws_spot_instance_request.admin-vm.public_ip
}

output "win-rdp_public_ip" {
  description = "Windows RDP public IP"
  value       = aws_spot_instance_request.win-rdp.public_ip
}

output "linux-attacker_public_ip" {
  description = "Linux Attacker VM public IP"
  value       = aws_spot_instance_request.linux-attacker.*.public_ip
}

output "linux-attacker_private_ip" {
  description = "Linux Attacker VM private IP"
  value       = aws_spot_instance_request.linux-attacker.*.private_ip
}

output "windows-attacker_public_ip" {
  description = "Windows Attacker VM public IP"
  value       = aws_spot_instance_request.windows-attacker.*.public_ip
}

output "windows-attacker_private_ip" {
  description = "Windows Attacker VM private IP"
  value       = aws_spot_instance_request.windows-attacker.*.private_ip
}
#
# output "CodeCommitUser-Secret" {
#   value = aws_iam_access_key.CodeCommitUserAccessKey[*].encrypted_secret
# }
