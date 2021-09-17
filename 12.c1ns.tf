locals {

  linux_attacker_public_ip = element(concat(aws_spot_instance_request.linux-attacker[*].public_ip, [""]), 0)

  protected_vpc_igw = module.admin-vpc.igw_id

  policy_name = var.cloudone-settings.c1ns_policy_name

  c1ns_connector               = (var.cloudone-settings.deploy_c1ns) ? jsondecode(data.http.c1ns-get-aws-connectors[0].body) : null
  c1ns_num_aws_connectors      = (var.cloudone-settings.deploy_c1ns) ? local.c1ns_connector.totalCount : null
  existing_connector_accountId = ((local.c1ns_num_aws_connectors == 0) || (local.c1ns_num_aws_connectors == null)) ? "0" : local.c1ns_connector.crossAccountRoles[0].accountId
  c1ns_connector_id            = ((local.c1ns_num_aws_connectors == 0) || (local.c1ns_num_aws_connectors == null)) ? "0" : local.c1ns_connector.crossAccountRoles[0].id

  c1ns_cross_acc_role = (var.cloudone-settings.deploy_c1ns) ? jsondecode(data.http.c1ns-get-cross-account-role[0].body) : null

  c1ns_network_security_role_arn = (var.cloudone-settings.deploy_c1ns) ? aws_cloudformation_stack.c1ns-new-role-stack[0].outputs["NetworkSecurityRoleArn"] : null

  c1ns_account_name       = join("-", ["${local.prefix}-poc-C1NS", random_string.suffix.result])
  c1ns_get_recommeded_cfn = (var.cloudone-settings.deploy_c1ns) ? jsondecode(module.c1ns-recommended-cfn-params.stdout) : null

  c1ns_inspection_subnets = (var.cloudone-settings.deploy_c1ns) ? local.c1ns_get_recommeded_cfn.inspectionSubnets : null
  c1ns_management_subnets = (var.cloudone-settings.deploy_c1ns) ? local.c1ns_get_recommeded_cfn.managementSubnets : null

  c1ns_cfn_template = (var.cloudone-settings.deploy_c1ns) ? (jsondecode(replace(module.c1ns-cfn-template.stdout, "c5n.4xlarge", "${var.cloudone-settings.c1ns_appliance_size}"))).output : null

  c1ns_api_url_prefix = "https://network.${var.cloudone-settings.region}.cloudone.trendmicro.com/api"

  c1ns_cloudwatch_dashboard_instance_id = "NetworkSecurityInstanceId${replace(title(var.general-settings.lab_region), "-", "")}A"
  c1ns_get_cfn_template_payload         = <<EOF
{
          "internetGatewayId": "${local.protected_vpc_igw}",
          "region": "${var.general-settings.lab_region}",
          "sshKeypair": "${var.general-settings.key_name}",
          "inspectionSubnets": ${jsonencode(local.c1ns_inspection_subnets)},
          "managementSubnets": ${jsonencode(local.c1ns_management_subnets)},
          "apiKey": "${var.cloudone-settings.c1_api_key}",
          "accountId": "${var.general-settings.lab_aws_acc}",
          "scriptFormat": "json"
}
EOF

  win-attacker-public-ip = (var.cloudone-settings.deploy_c1ns) ? aws_spot_instance_request.windows-attacker[0].public_ip : null
  lin-attacker-public-ip = (var.cloudone-settings.deploy_c1ns) ? aws_spot_instance_request.linux-attacker[0].public_ip : null
  attacker-ips           = (var.cloudone-settings.deploy_c1ns) ? ["${local.win-attacker-public-ip}/32", "${local.lin-attacker-public-ip}/32"] : [null]

}

# 1. Get IGW ID of eks-vpc (will be protected by C1NS)
# local.protected_vpc_igw

# 2. Get Cross Account Role information (suggested by Cloud One)
data "http" "c1ns-get-cross-account-role" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  url = "${local.c1ns_api_url_prefix}/crossaccountroleiaminfo"

  # Optional request headers
  request_headers = {
    api-version    = "v1"
    api-secret-key = var.cloudone-settings.c1_api_key
  }
}

# 3. Create polciy for Cross Account Role
resource "aws_cloudformation_stack" "c1ns-new-role-stack" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  name         = "${local.prefix}-c1ns-role"
  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = templatefile("user-data/cloudone/c1ns-cross-account-role.template", {
    prefix                   = local.prefix,
    policy_name              = local.policy_name,
    c1ns_network_security_id = local.c1ns_cross_acc_role.networkSecurityAccountId
  })

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-c1ns-iam-role-stack"
  }

}

# 6. Create C1NS AWS Connector
# get current aws connectors

data "http" "c1ns-get-aws-connectors" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0
  url   = "${local.c1ns_api_url_prefix}/awsconnectors"

  # Optional request headers
  request_headers = {
    api-version    = "v1"
    api-secret-key = var.cloudone-settings.c1_api_key
  }
}

# Delete existing connector which has same AccountId

resource "null_resource" "c1ns-delete-connector" {

  count = (var.cloudone-settings.deploy_c1ns) ? ((local.existing_connector_accountId == var.general-settings.lab_aws_acc) ? 1 : 0) : 0

  provisioner "local-exec" {
    command    = "curl -X DELETE ${local.c1ns_api_url_prefix}/awsconnectors -H 'Content-Type: application/json' -H 'api-version: v1' -H 'api-secret-key: ${var.cloudone-settings.c1_api_key}' --data-binary '{\"id\": \"${local.c1ns_connector_id}\"}'"
    on_failure = continue
  }
}

# New connector


# on destroy need to manually delete connector
resource "null_resource" "c1ns-new-connector" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [
    time_sleep.c1ns-wait-for-admin-vpc
  ]

  //Create new connector
  provisioner "local-exec" {
    command    = "curl -X POST ${local.c1ns_api_url_prefix}/awsconnectors -H 'Content-Type: application/json' -H 'api-version: v1' -H 'api-secret-key: ${var.cloudone-settings.c1_api_key}' --data-binary '{\"accountName\": \"${local.c1ns_account_name}\",\"crossAccountRole\": \"${local.c1ns_network_security_role_arn}\",\"externalId\": \"${local.c1ns_cross_acc_role.externalId}\"}'"
    on_failure = continue
  }

}

resource "time_sleep" "c1ns-wait-for-connector" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [
    null_resource.c1ns-new-connector[0]
  ]

  create_duration = "15s"

}

# 7. Get recommended CFN parameters
module "c1ns-recommended-cfn-params" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [
    time_sleep.c1ns-wait-for-connector[0]
  ]
  source  = "matti/resource/shell"
  command = "curl -X POST ${local.c1ns_api_url_prefix}/recommendedcftparams -H 'Content-Type: application/json' -H 'api-version: v1' -H 'api-secret-key: ${var.cloudone-settings.c1_api_key}' --data-binary '{\"accountId\": \"${var.general-settings.lab_aws_acc}\",\"internetGatewayId\": \"${local.protected_vpc_igw}\",\"region\": \"${var.general-settings.lab_region}\"}'"
}

# 8. Generate CFN template

module "c1ns-cfn-template" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [
    module.c1ns-recommended-cfn-params[0]
  ]

  source  = "matti/resource/shell"
  command = "curl -X POST ${local.c1ns_api_url_prefix}/protectigwcfts -H 'Content-Type: application/json' -H 'api-version: v1' -H 'api-secret-key: ${var.cloudone-settings.c1_api_key}' --data-binary '${local.c1ns_get_cfn_template_payload}'"

}

# 9. Create C1NS Appliance stack (by generated CFN template)
resource "local_file" "c1ns_cfn_json_template" {
  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  content  = local.c1ns_cfn_template
  filename = "user-data/samples/c1ns_cfn_template.json"
}


resource "aws_cloudformation_stack" "c1ns-new-appliance-stack" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  name         = "${local.prefix}-c1ns-appliance"
  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = local.c1ns_cfn_template

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-c1ns-appliance"
  }

}

resource "time_sleep" "c1ns-wait-for-appliance" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [aws_cloudformation_stack.c1ns-new-appliance-stack[0]]

  create_duration = "120s"
}

# 10. Set cloudwatch logs for C1NS appliances

resource "null_resource" "c1ns_upload_loggroups_script" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [time_sleep.c1ns-wait-for-appliance[0]]

  provisioner "file" {
    source      = "user-data/init-scripts/c1ns-config-loggroups.sh"
    destination = "/home/ec2-user/c1ns-config-loggroups.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${local.keyfile}")
      host        = aws_spot_instance_request.admin-vm.public_ip
      agent       = "false"
    }

  }

}

resource "null_resource" "c1ns_create_log_groups" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [null_resource.c1ns_upload_loggroups_script]

  provisioner "remote-exec" {
    inline = [
      "sed  -i 's^API-KEY^${var.cloudone-settings.c1_api_key}^' /home/ec2-user/c1ns-config-loggroups.sh",
      "chmod +x /home/ec2-user/c1ns-config-loggroups.sh",
      "/home/ec2-user/c1ns-config-loggroups.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${local.keyfile}")
      host        = aws_spot_instance_request.admin-vm.public_ip
      agent       = "false"
    }

  }

}

#11 Create CloudWatch dashboard
resource "aws_cloudformation_stack" "c1ns-cloudwatch-dashboard" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  name         = "${local.prefix}-c1ns-cloudwatch-dashboard"
  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = file("user-data/cloudone/C1NS_SingleAppliance_CloudWatch_Panel_C1NS_v6.yml")

  parameters = {
    DashboardName   = "TrendMicro-NetworkSecurity-Dashboard"
    AlarmInstanceID = aws_cloudformation_stack.c1ns-new-appliance-stack[0].outputs[local.c1ns_cloudwatch_dashboard_instance_id]
    C1NSRegion      = var.general-settings.lab_region
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "${local.prefix}-c1ns-cloudwatch-dashboard"
  }

}
