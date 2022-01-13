
locals {

  //C1FSS
  s3scan                 = (var.cloudone-settings.deploy_c1fss) ? module.lab_s3bucket[0].s3_bucket_id : null
  s3quarantine           = (var.cloudone-settings.deploy_c1fss) ? module.lab_quarantine_s3bucket[0].s3_bucket_id : null
  s3clean                = (var.cloudone-settings.deploy_c1fss) ? module.lab_clean_s3bucket[0].s3_bucket_id : null
  c1fss_scanner_role_arn = (var.cloudone-settings.deploy_c1fss) ? aws_cloudformation_stack.c1fss-scanner-stack[0].outputs["ScannerStackManagementRoleARN"] : null
  c1fss_storage_role_arn = (var.cloudone-settings.deploy_c1fss) ? aws_cloudformation_stack.c1fss-storage-stack[0].outputs["StorageStackManagementRoleARN"] : null
  c1fss_externalID       = (var.cloudone-settings.deploy_c1fss) ? (jsondecode(data.http.get-external-ID[0].body)).externalID : null
  c1fss_scanner_id       = (var.cloudone-settings.deploy_c1fss) ? (jsondecode(restapi_object.c1fss-add-scanner-stack[0].api_response)).stackID : null

  c1fss_scanner_cfn = (var.cloudone-settings.deploy_c1fss) ? data.http.c1fss-get-scanner-cfn-template[0].body : null
  c1fss_storage_cfn = (var.cloudone-settings.deploy_c1fss) ? data.http.c1fss-get-storage-cfn-template[0].body : null
  c1fss_api_url_prefix = "filestorage.${var.cloudone-settings.region}.cloudone.trendmicro.com/api"
}

data "http" "c1fss-get-scanner-cfn-template" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  url = "https://raw.githubusercontent.com/trendmicro/cloudone-filestorage-deployment-templates/master/aws/FSS-Scanner-Stack.template"
}

data "http" "c1fss-get-storage-cfn-template" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  url = "https://raw.githubusercontent.com/trendmicro/cloudone-filestorage-deployment-templates/master/aws/FSS-Storage-Stack.template"
}

// Tao 3 S3bucket de test C1 File Storage Security

module "lab_s3bucket" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  //public bucket to receive uploaded files from users
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = lower("${local.prefix}-${var.s3-settings.lab_s3bucket}-${random_string.suffix.result}")
  acl    = var.s3-settings.lab_s3bucket_acl

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }

}

module "lab_quarantine_s3bucket" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = lower(format("%s%s-%s", local.prefix, var.s3-settings.lab_quarantine_s3bucket, random_string.suffix.result))
  acl    = var.s3-settings.lab_s3bucket_acl

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }

}

module "lab_clean_s3bucket" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = lower(format("%s%s-%s", local.prefix, var.s3-settings.lab_clean_s3bucket, random_string.suffix.result))
  acl    = var.s3-settings.lab_s3bucket_acl

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }
}

// IAM sections
resource "aws_iam_role" "c1fss-role" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  //role for FSS post-scan action
  // https://github.com/trendmicro/cloudone-filestorage-plugins/blob/master/post-scan-actions/aws-python-promote-or-quarantine/other-installation-methods.md#JSON

  name = join("-", ["${local.prefix}-poc-c1fss-role", random_string.suffix.result])
  path = "/"

  assume_role_policy = file("user-data/cloudone/c1fss-lambda-trust.json")

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }
}

resource "aws_iam_policy" "c1fss-trust-policy" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  name        = join("-", ["${local.prefix}-poc-c1fss-trust-policy", random_string.suffix.result])
  path        = "/"
  description = "Trend Micro C1-FSS Trust Policy"

  policy = templatefile("user-data/cloudone/c1fss-trust-policy.json", {
    s3quarantine-bucket = module.lab_quarantine_s3bucket[0].s3_bucket_id,
    s3clean-bucket      = module.lab_clean_s3bucket[0].s3_bucket_id,
    s3scanbucket        = module.lab_s3bucket[0].s3_bucket_id
  })

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }
}

resource "aws_iam_role_policy_attachment" "c1fss-role-custom-policy" {
  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  role       = aws_iam_role.c1fss-role[0].name
  policy_arn = aws_iam_policy.c1fss-trust-policy[0].arn
}

resource "aws_iam_role_policy_attachment" "c1fss-role-managed-policy" {
  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  role       = aws_iam_role.c1fss-role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

//Create ScannerStack and StorageStack cua FSS bang terraform

data "http" "get-external-ID" {
  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  url = "https://${local.c1fss_api_url_prefix}/external-id"

  # Optional request headers
  request_headers = {
    Content-Type   = "application/json"
    api-version    = "v1"
    Authorization = "ApiKey ${var.cloudone-settings.c1_api_key}"
  }
}

resource "aws_cloudformation_stack" "c1fss-scanner-stack" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  // Create C1FSS Scanner Stack to demo Cloud One Application Security

  name         = "${local.prefix}-Scanner-FileStorageSecurity"
  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = local.c1fss_scanner_cfn //file("user-data/cloudone/FSS-Scanner-Stack.template")
  parameters = {
    ExternalID           = local.c1fss_externalID //"112042678300"
    S3BucketPrefix       = "${local.prefix}-"
    LambdaFunctionPrefix = "${local.prefix}-"
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }

}

resource "aws_cloudformation_stack" "c1fss-storage-stack" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  // Create C1FSS Storage Stack to demo Cloud One Application Security

  name         = "${local.prefix}-Storage-FileStorageSecurity"
  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = local.c1fss_storage_cfn //file("user-data/cloudone/FSS-Storage-Stack.template")

  parameters = {
    S3BucketToScan                = module.lab_s3bucket[0].s3_bucket_id
    ScannerAWSAccount             = var.general-settings.lab_aws_acc
    ScannerSQSURL                 = aws_cloudformation_stack.c1fss-scanner-stack[0].outputs["ScannerQueueURL"]
    ExternalID                    = local.c1fss_externalID
    TriggerWithObjectCreatedEvent = "true"
    S3BucketPrefix                = "${local.prefix}-"
    LambdaFunctionPrefix          = "${local.prefix}-"
    SNSTopicPrefix                = "${local.prefix}-"
    IAMPolicyPrefix               = "${local.prefix}-"
    IAMRolePrefix                 = "${local.prefix}-"
    // FSSKeyPrefix = "${local.prefix}-"
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }

}

# Add Scanner & Storage stack to C1FSS

resource "restapi_object" "c1fss-add-scanner-stack" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0
  
  path          = "${local.c1fss_api_url_prefix}/stacks"
  create_method = "POST"
  id_attribute  = "stackID"

  data = <<-EOT
  {
    "type": "scanner",
    "provider": "aws",
    "details": {
      "managementRole": "${local.c1fss_scanner_role_arn}"
    }
  }
  EOT

}

resource "time_sleep" "c1fsss-wait-for-scanner" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  depends_on      = [restapi_object.c1fss-add-scanner-stack[0]]
  create_duration = "60s"

}

resource "restapi_object" "c1fss-add-storage-stack" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  depends_on = [time_sleep.c1fsss-wait-for-scanner[0]]
  
  path          = "${local.c1fss_api_url_prefix}/stacks"
  create_method = "POST"
  id_attribute  = "stackID"

  data = <<-EOT
  {
    "type": "storage",
    "provider": "aws",
    "scannerStack": "${local.c1fss_scanner_id}",
    "details": {
      "managementRole": "${local.c1fss_storage_role_arn}"
    }
  }
  EOT
}

//C1FSS lambda related section - POST-ACTION
resource "aws_lambda_function" "poc-C1FSS-action" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  //Post-Scan Lambda function for C1FSS
  filename      = "user-data/cloudone/handler.zip"
  function_name = "${local.prefix}-C1FSS-post-action"
  role          = aws_iam_role.c1fss-role[0].arn
  handler       = "handler.lambda_handler"

  memory_size = "512"
  timeout     = "30"

  runtime = "python3.8"

  environment {
    variables = {
      PROMOTEBUCKET    = module.lab_clean_s3bucket[0].s3_bucket_id,
      QUARANTINEBUCKET = module.lab_quarantine_s3bucket[0].s3_bucket_id
    }
  }

}

resource "aws_lambda_permission" "allow_c1fss_action_trigger" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  statement_id  = aws_lambda_function.poc-C1FSS-action[0].function_name
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.poc-C1FSS-action[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_cloudformation_stack.c1fss-storage-stack[0].outputs["ScanResultTopicARN"]
}

resource "aws_sns_topic_subscription" "subcribe_c1fss_func_sns_topic" {

  count = (var.cloudone-settings.deploy_c1fss) ? 1 : 0

  topic_arn              = aws_cloudformation_stack.c1fss-storage-stack[0].outputs["ScanResultTopicARN"]
  protocol               = "lambda"
  endpoint               = aws_lambda_function.poc-C1FSS-action[0].arn
  endpoint_auto_confirms = true
}

// S3 Uploader - Lambda application from Lambda Repo
resource "aws_serverlessapplicationrepository_cloudformation_stack" "c1fss-s3-uploader" {

  count = (var.cloudone-settings.deploy_c1fss) ? ((var.s3-settings.use_uploader) ? 1 : 0) : 0

  depends_on     = [module.lab_s3bucket[0]]
  name           = "${local.prefix}-s3-uploader"
  application_id = "arn:aws:serverlessrepo:us-east-1:233054207705:applications/uploader"

  parameters = {
    destBucket = module.lab_s3bucket[0].s3_bucket_id
  }

  capabilities = ["CAPABILITY_IAM"]

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }

}
