#############################################################
######## deploy aws network firewall to protect admin-vpc ec2
#############################################################

locals {
  aws-netfw-subnet-id = (var.cloudone-settings.deploy_c1ns) ? aws_subnet.c1ns-anfw-subnet[0].id : null
  aws-netfw-rt-id     = (var.cloudone-settings.deploy_c1ns) ? aws_route_table.c1ns-anfw-firewall-rtb[0].id : null
  anfw-vpce-id        = (var.cloudone-settings.deploy_c1ns) ? element([for ss in tolist(aws_networkfirewall_firewall.c1ns-aws-firewall[0].firewall_status[0].sync_states) : ss.attachment[0].endpoint_id if ss.attachment[0].subnet_id == local.aws-netfw-subnet-id], 0) : null
}

# create 2nd public subnet for Windows Victim
resource "aws_subnet" "admin-subnet-1" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [module.c1ns-cfn-template]

  vpc_id            = local.admin-vpc-id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.network-settings.admin_vpc_public_subnets[1]

  map_public_ip_on_launch = true

  tags = {
    Name        = "admin-subnet-1"
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }
}

# 1. create route-table for admin-subnet-1
resource "aws_route_table" "admin-subnet-1-rtb" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  vpc_id = local.admin-vpc-id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = local.anfw-vpce-id
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
    Name        = "admin-subnet-1-rtb"
  }
}

resource "aws_route_table_association" "admin-subnet-1-rtb" {
  count          = (var.cloudone-settings.deploy_c1ns) ? 1 : 0
  subnet_id      = aws_subnet.admin-subnet-1[0].id
  route_table_id = aws_route_table.admin-subnet-1-rtb[0].id
}

# 0.Tao public firewall subnet in admin-vpc
resource "aws_subnet" "c1ns-anfw-subnet" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [module.c1ns-cfn-template]

  vpc_id            = local.admin-vpc-id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.network-settings.admin_vpc_public_subnets[2]

  tags = {
    Name        = "aws-netfw-subnet"
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
  }
}

# 1. create route-table for firewall subnet
resource "aws_route_table" "c1ns-anfw-firewall-rtb" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  vpc_id = local.admin-vpc-id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.protected_vpc_igw
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
    Name        = "aws-netfw-rtb"
  }
}

# associate aws-netfw-subnet to aws-netfw-rtb
resource "aws_route_table_association" "aws-netfw-subnet-rtb" {
  count          = (var.cloudone-settings.deploy_c1ns) ? 1 : 0
  subnet_id      = local.aws-netfw-subnet-id
  route_table_id = local.aws-netfw-rt-id
}

# get generated c1ns-eni-1A
data "aws_route_table" "VPCAccessRT" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  depends_on = [time_sleep.c1ns-wait-for-appliance[0]]

  filter {
    name   = "tag:Name"
    values = ["VPC access RT"]
  }
}

# add route to admin-vpc-public-subnet
resource "aws_route" "VPCAccessRT-to-FW" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  route_table_id         = data.aws_route_table.VPCAccessRT[0].id
  destination_cidr_block = var.network-settings.admin_vpc_public_subnets[1]
  vpc_endpoint_id        = local.anfw-vpce-id

}

resource "aws_networkfirewall_rule_group" "c1ns-stateful-rule-group" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  capacity = 10
  name     = "c1ns-stateful-rule-group"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = ["alibaba.com", "vnexpress.net"]
      }
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "trendmicro-c1ns-stateful-rule-group"
    Vendor      = "Trend Micro"
  }
}

resource "aws_networkfirewall_firewall_policy" "c1ns-aws-fw-policy" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  name = "c1ns-aws-fw-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.c1ns-stateful-rule-group[0].arn
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "trendmicro-c1ns-aws-fw-policy"
    Vendor      = "Trend Micro"
  }
}

resource "aws_networkfirewall_firewall" "c1ns-aws-firewall" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  // depends_on = [ time_sleep.c1ns-wait-for-appliance ]

  name                = "c1ns-aws-fw"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.c1ns-aws-fw-policy[0].arn
  vpc_id              = local.admin-vpc-id
  subnet_mapping {
    subnet_id = local.aws-netfw-subnet-id
  }

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "trendmicro-c1ns-aws-firewall"
    Vendor      = "Trend Micro"
  }
}

# resource "time_sleep" "c1ns-wait-for-aws-firewall" {
#
#   count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0
#
#   depends_on = [
#     aws_networkfirewall_firewall.c1ns-aws-firewall[0]
#   ]
#   create_duration = "300s"
#
# }

resource "aws_cloudwatch_log_group" "c1ns-aws-fw-log-group" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  name = "trendmicro-aws-firewall-logs"

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Name        = "trendmicro-aws-firewall-logs"
    Vendor      = "Trend Micro"
  }
}

resource "aws_networkfirewall_logging_configuration" "c1ns-aws-fw-logs" {

  count = (var.cloudone-settings.deploy_c1ns) ? 1 : 0

  firewall_arn = aws_networkfirewall_firewall.c1ns-aws-firewall[0].arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.c1ns-aws-fw-log-group[0].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}
