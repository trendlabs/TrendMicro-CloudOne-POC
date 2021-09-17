locals {

  // C1AS
  c1as_group_key    = (var.cloudone-settings.deploy_c1as) ? (jsondecode(restapi_object.c1as-new-group[0].api_response)).credentials.key : "none"
  c1as_group_secret = (var.cloudone-settings.deploy_c1as) ? (jsondecode(restapi_object.c1as-new-group[0].api_response)).credentials.secret : "none"
  c1as_api_url_prefix = "application.${var.cloudone-settings.region}.cloudone.trendmicro.com"
}
# 1. Create a new group

resource "restapi_object" "c1as-new-group" {

  count = (var.cloudone-settings.deploy_c1as) ? 1 : 0

  path          = "${local.c1as_api_url_prefix}/accounts/groups"
  create_method = "POST"
  id_attribute  = "group_id"

  data = "{\"name\": \"${local.prefix}-POC-AppGroup\"}"

}

# 2. Create CFN stack for C1AS - Lambda function test case - CAP-SET- 002
resource "aws_cloudformation_stack" "c1as-tmvwa-function" {

  count = (var.cloudone-settings.deploy_c1as) ? 1 : 0

  name         = "${local.prefix}-c1as-tmvwa-func"
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_AUTO_EXPAND"]

  template_body = file("user-data/cloudone/c1as-cf-tmvwa.json")

  parameters = {
    TrendAPKeyParameter    = local.c1as_group_key
    TrendAPSecretParameter = local.c1as_group_secret
  }
  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor = "Trend Micro"
  }

}
