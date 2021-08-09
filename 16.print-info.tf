locals {

  lab-guide-overview = templatefile("docs/tpl/overview.tpl", {
    BILLSNSTOPIC      = element(concat(module.billing_alert[*].sns_topic_arn, [""]), 0),
    ALLOWED_IPs       = join(", ", (concat(["${local.admin_ip}"], var.admin-vm-settings.allowed_IPs))),
    WIN-RDP-IP        = aws_spot_instance_request.win-rdp.public_ip,
    WIN-USER          = var.general-settings.win_username,
    LABPASSWORD       = var.general-settings.lab_password,
    KEYFILE           = local.keyfile,
    ADMINVM_PUBLIC_IP = aws_spot_instance_request.admin-vm.public_ip
  })

  lab-guide-c1ws = templatefile("docs/tpl/c1ws.tpl", {
    TRENDNET_URL = "http://${var.dns-settings.dns-hostnames[0]}.${var.dns-settings.lab_private_domain}:8080"
  })

  lab-guide-c1fss = (var.cloudone-settings.deploy_c1fss) ? templatefile("docs/tpl/c1fss.tpl", {
    S3_UPLOADER_URL  = "",
    BUCKET_TO_SCAN   = local.s3scan,
    QUARANTINEBUCKET = local.s3quarantine,
    PROMOTEBUCKET    = local.s3clean,
  }) : ""

  lab-guide-c1cs = (var.cloudone-settings.deploy_c1cs) ? templatefile("docs/tpl/c1cs.tpl", {
    HARBOR_PRIVATE_IP         = element(concat(aws_spot_instance_request.harbor-vm[*].private_ip, [""]), 0),
    HARBOR_URL                = "https://harbor.${var.dns-settings.lab_private_domain}",
    JENKINS_URL               = "https://jenkins.${var.dns-settings.lab_private_domain}:8443",
    SMARTCHECK_URL            = "https://smartcheck.${var.dns-settings.lab_private_domain}",
    ECR_URL                   = element(concat(aws_ecr_repository.poc[*].repository_url, [""]), 0),
    KEYFILE                   = local.keyfile,
    LABPASSWORD               = var.general-settings.lab_password,
    DOMAIN                    = var.dns-settings.lab_private_domain,
    LAB_REGION                = var.general-settings.lab_region,
    AWS_ACC_ID                = var.general-settings.lab_aws_acc,
    C1CS_CLUSTER_APIKEY       = local.c1cs_cluster_apikey,
    C1CS_SCANNER_APIKEY       = local.c1cs_scanner_apikey,
    C1CS_CLUSTER              = "${local.prefix}.POC.Cluster"
    C1CS_SCANNER              = "${local.prefix}.POC.Scanner"
    C1CS_POLICY               = "${local.prefix}.POC.Policy",
    # CodeCommitUserID          = element(concat(aws_iam_access_key.CodeCommitUserAccessKey[*].id, [""]), 0),
    # CodeCommitEncryptedSecret = element(concat(aws_iam_access_key.CodeCommitUserAccessKey[*].encrypted_secret, [""]), 0),
    # CodeCommitRepoURL         = element(concat(aws_codecommit_repository.CodeCommitRepo[*].clone_url_http, [""]), 0),
    # CodeCommitInstanceRole    = element(concat(aws_iam_role.CodeCommitInstanceRole[*].name, [""]), 0),
  }) : ""

  lab-guide-c1as = (var.cloudone-settings.deploy_c1as) ? templatefile("docs/tpl/c1as.tpl", {
    GROUP_NAME       = "${local.prefix}-POC-AppGroup",
    GROUP_KEY        = local.c1as_group_key,
    GROUP_SECRET     = local.c1as_group_secret,
    TMVWA_URL        = element(concat(aws_cloudformation_stack.c1as-tmvwa-function[*].outputs["TmvwaUrl"], [""]), 0),
    DOCKER_TMVWA_URL = "http://${var.dns-settings.dns-hostnames[2]}.${var.dns-settings.lab_private_domain}"
  }) : ""

  lab-guide-c1ns = (var.cloudone-settings.deploy_c1ns) ? templatefile("docs/tpl/c1ns.tpl", {
    WIN-VICTIM-PUBIP      = aws_spot_instance_request.win-rdp.public_ip,
    WIN-VICTIM-PRIVIP     = aws_spot_instance_request.win-rdp.private_ip,
    LINUX-VICTIM_PUBIP    = aws_spot_instance_request.admin-vm.public_ip,
    LINUX-VICTIM-PRIVIP   = aws_spot_instance_request.admin-vm.private_ip,
    WIN-ATTACKER-PUBIP    = local.win-attacker-public-ip,
    WIN-ATTACKER-PRIVIP   = aws_spot_instance_request.windows-attacker[0].private_ip,
    LINUX-ATTACKER-PUBIP  = local.lin-attacker-public-ip,
    LINUX-ATTACKER-PRIVIP = aws_spot_instance_request.linux-attacker[0].private_ip,
    KEYFILE               = local.keyfile,
    WIN-USER              = var.general-settings.win_username,
    LABPASSWORD           = var.general-settings.lab_password,
    WIN_VICTIM_HOSTNAME   = "${var.dns-settings.dns-hostnames[2]}.${var.dns-settings.lab_private_domain}",
    LIN_VICTIM_HOSTNAME   = "${var.dns-settings.dns-hostnames[3]}.${var.dns-settings.lab_private_domain}",
    WIN_ATTACKER_HOSTNAME = "${var.dns-settings.dns-hostnames[5]}.${var.dns-settings.lab_private_domain}",
    LIN_ATTACKER_HOSTNAME = "${var.dns-settings.dns-hostnames[4]}.${var.dns-settings.lab_private_domain}"
  }) : ""

  lab_guide = join("", [
    local.lab-guide-overview,
    local.lab-guide-c1ws,
    local.lab-guide-c1fss,
    local.lab-guide-c1as,
    local.lab-guide-c1ns,
    local.lab-guide-c1cs
  ])
}
resource "local_file" "lab-guide" {

  content = local.lab_guide

  filename = "docs/lab-guide.txt"

  provisioner "local-exec" {
    when       = destroy
    command    = "rm docs/lab-guide.txt"
    on_failure = continue
  }
}
