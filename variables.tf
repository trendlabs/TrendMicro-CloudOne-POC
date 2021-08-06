// General setting

variable "general-settings" {
  default = {
    win_username      = "pocuser"
    win_user_fullname = "POC User"
    lab_password      = "1d0ntkn0w!"
    lab_region        = "ap-southeast-1"
    lab_aws_acc       = "YOUR-AWS-ACC-ID"   // AWS Account ID

    /* NOTE: for demo / poc only - make sure to delete IAM user when finish
    For security purpose, consider other authentication methods:
        Static credentials
        Environment variables
        Shared credentials/configuration file
        CodeBuild, ECS, and EKS Roles
        EC2 Instance Metadata Service (IMDS and IMDSv2)
    */
    iam_user_name     = "YOUR IAM USERNAME"
    iam_access_id     = "YOUR-ACCESS-ID" //user 'thanh_trendmicro'
    iam_access_secret = "YOUR-ACCESS_SECRET"
    //------

    key_name    = "YOUR-desired-keypair-name" //keypair name to be created - then be used for ssh to admin-vm
    admin_email = "YOUR-ADMIN-EMAIL"          //email admin for s3 upload notification

    # You'll need to generate your own keys at: https://www.google.com/recaptcha/admin
    RECAPTCHA_PRIV_KEY = "YOUR RECAPTCHA SECRET"
    RECAPTCHA_PUB_KEY  = "YOUR RECAPTCHA KEY"

    spot_price               = "0.1"
    spot_type                = "one-time"
    billing_alarm_threadhold = 50
  }
  type = object({
    win_username             = string
    win_user_fullname        = string
    iam_user_name            = string
    lab_password             = string
    lab_region               = string
    lab_aws_acc              = string
    key_name                 = string
    iam_access_id            = string
    iam_access_secret        = string
    RECAPTCHA_PRIV_KEY       = string
    RECAPTCHA_PUB_KEY        = string
    admin_email              = string
    spot_price               = string
    spot_type                = string
    billing_alarm_threadhold = number
  })
}

variable "cloudone-settings" {
  default = {
    deploy_c1cs  = true
    deploy_c1as  = true
    deploy_c1ns  = true
    deploy_c1fss = true
    // C1WS wil always be deployed at least to bastion hosts - no choice
    //api_secret_key created on C1WS \ Administration \ API key
    c1_api_key          = "YOUR-C1-API-KEY"
    c1ns_appliance_size = "c5.xlarge"                       // default for appliance is c5n.4xlarge, set this to reduce cost for demo
    c1ns_policy_name    = "NetworkSecurityPolicy"           // dont change - currently cannot be changed
  }
  type = object({
    c1_api_key          = string
    c1ns_appliance_size = string
    c1ns_policy_name    = string
    deploy_c1cs         = bool
    deploy_c1as         = bool
    deploy_c1ns         = bool
    deploy_c1fss        = bool
  })
}

// S3 Bucket settings
variable "s3-settings" {
  default = {
    lab_s3bucket            = "vib-poc-s3scan"
    lab_quarantine_s3bucket = "vib-poc-s3quarantine"
    lab_clean_s3bucket      = "vib-poc-s3clean"
    lab_c1as_s3bucket       = "vib-poc-c1as-demo"
    lab_s3bucket_acl        = "private"
    use_uploader            = true
  }
  type = object({
    lab_s3bucket            = string
    lab_s3bucket_acl        = string
    lab_quarantine_s3bucket = string
    lab_clean_s3bucket      = string
    lab_c1as_s3bucket       = string
    use_uploader            = bool
  })
}
// DNS settings
variable "dns-settings" {
  type = object({
    dns-hostnames      = list(string)
    lab_private_domain = string

  })
  default = {
    dns-hostnames = [
      "win",
      "linux",
      "winVictim",
      "linVictim",
      "linAttacker",
      "winAttacker",
      "harbor",
      "jenkins",
      "smartcheck",
      "tmvwa", // tmvwa inside k8s system
      "ext-tmvwa"
    ]
    lab_private_domain = "internal.lab" // test domain - private domain will be registered in Route53
  }
}

// admin-vm sevrer related settings
variable "admin-vm-settings" {
  type = object({
    ec2_allowed_inbound   = list(number)
    allowed_IPs           = list(string)
    ec2_instance_type     = string
    ec2_ami               = string
    ec2_win_ami           = string
    ec2_win_instance_type = string
    protocol              = string
  })
  default = {
    ec2_allowed_inbound   = [22, 3389, 80, 8080, 8000]
    allowed_IPs           = ["1.55.250.147/32", "42.113.119.227/32"]
    protocol              = "tcp"
    ec2_instance_type     = "t3a.medium"
    ec2_ami               = "ami-02f26adf094f51167" //ap-southeast-1 (Singapore) - Amazon Linux 2 AMI
    ec2_win_ami           = "ami-0e0c0f774a3f68bf9" // ap-southeast-1 (Singapore) - Windows 2019 Base (ami-051c081518035d88f - with container)
    ec2_win_instance_type = "t3a.large"
  }
}

// nodegroup VM related settings
variable "node-settings" {
  type = object({
    allowed_inbound      = list(number)
    allowed_IPs          = list(string)
    node_ami             = string
    protocol             = string
    spot_instance_type   = string
    asg_desired_capacity = number
    asg_max_size         = number
  })
  default = {
    allowed_inbound      = [22, 443, 80]
    allowed_IPs          = ["0.0.0.0/0"]
    protocol             = "tcp"
    spot_instance_type   = "t3a.medium"
    asg_max_size         = 5
    asg_desired_capacity = 2
    node_ami             = "ami-02f26adf094f51167" //ap-southeast-1 (Singapore) - Amazon Linux 2 AMI
  }
}

//eks-master related settings
variable "network-settings" {
  type = object({
    eks_vpc_cidr              = string
    eks_vpc_public_subnets    = list(string)
    eks_vpc_private_subnets   = list(string)
    admin_vpc_cidr            = string
    admin_vpc_public_subnets  = list(string)
    admin_vpc_private_subnets = list(string)
    attacker_vpc_cidr            = string
    attacker_vpc_public_subnets  = list(string)
    attacker_vpc_private_subnets = list(string)
  })
  default = {
    eks_vpc_cidr             = "10.0.0.0/20"
    eks_vpc_public_subnets   = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    eks_vpc_private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    admin_vpc_cidr           = "192.168.0.0/20"
    admin_vpc_public_subnets = ["192.168.1.0/25", "192.168.1.128/25", "192.168.0.128/28"]
    admin_vpc_private_subnets    = ["192.168.2.0/24"]
    attacker_vpc_cidr            = "192.168.16.0/20"
    attacker_vpc_public_subnets  = ["192.168.16.0/24"]
    attacker_vpc_private_subnets = ["192.168.17.0/24"]
  }
}
