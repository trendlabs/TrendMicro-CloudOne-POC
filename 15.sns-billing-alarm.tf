locals {
  set_billing_alarm = (var.general-settings.billing_alarm_threadhold == 0) ? false : true
}

module "billing_alert" {
  source = "binbashar/cost-billing-alarm/aws"

  aws_env                   = "poc"
  aws_account_id            = var.general-settings.lab_aws_acc
  monthly_billing_threshold = var.general-settings.billing_alarm_threadhold
  currency                  = "USD"

  count = (local.set_billing_alarm) ? 1 : 0
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn              = module.billing_alert[count.index].sns_topic_arn
  protocol               = "email"
  endpoint               = var.general-settings.admin_email
  endpoint_auto_confirms = true

  count = (local.set_billing_alarm) ? 1 : 0
}
