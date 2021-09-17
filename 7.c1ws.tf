locals {

  c1ws_api_url_prefix = "workload.${var.cloudone-settings.region}.cloudone.trendmicro.com/api"
  c1ws_linux_tenant_token = substr((jsondecode(module.c1ws-scripts[0].stdout)).scriptBody, -93, -1)

  c1ws_win_deployment_script = trimsuffix(trimprefix((jsondecode(module.c1ws-scripts[1].stdout)).scriptBody, "<powershell>"), "</powershell>")
  c1ws_connector_payload     = <<EOF
{
  "displayName": "${local.prefix}-AWS-Connector",
  "accountId": "${var.general-settings.lab_aws_acc}",
  "accessKey": "${var.general-settings.iam_access_id}",
  "secretKey": "${var.general-settings.iam_access_secret}",
  "seedRegion": "${var.general-settings.lab_region}",
  "useInstanceRole": "false",
  "workspacesEnabled": "false"
}
EOF
  platform                   = ["linux", "windows"]

}

# generate deployment script
# cannot use restapi here because for POST request it requires returned ID for the object (for later destroy) which we dont have with this request
# https://github.com/matti/terraform-shell-resource

module "c1ws-scripts" {
  count   = 2
  source  = "matti/resource/shell"
  command = "curl -X POST https://${local.c1ws_api_url_prefix}/agentdeploymentscripts -H 'Content-Type: application/json' -H 'api-version: v1' -H 'api-secret-key: ${var.cloudone-settings.c1_api_key}' --data-binary '{\"platform\": \"${local.platform[count.index]}\", \"validateCertificateRequired\": \"true\", \"validateDigitalSignatureRequired\": \"true\", \"activationRequired\": \"true\"}'"
}

resource "local_file" "c1ws_generated_win_script" {
  content  = local.c1ws_win_deployment_script
  filename = "user-data/init-scripts/dsa-win.ps1"
}

resource "local_file" "c1ws_generated_linux_script" {
  content  = local.eks_worker_node_init
  filename = "user-data/init-scripts/dsa-linux.sh"
}

# Create new C1WS connector

resource "null_resource" "c1ws-new-connector" {

  provisioner "local-exec" {
    command    = "curl -X POST https://${local.c1ws_api_url_prefix}/awsconnectors -H 'Content-Type: application/json' -H 'api-version: v1' -H 'api-secret-key: ${var.cloudone-settings.c1_api_key}' --data-binary '${local.c1ws_connector_payload}'"
    on_failure = continue
  }
}
