locals {

  oidc_id = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  external-dns-role = (var.cloudone-settings.deploy_c1cs) ? aws_iam_role.c1cs-AllowEKSExternalDNS-role[0].arn : ""
  ecr-password = (var.cloudone-settings.deploy_c1cs) ? base64encode("AWS:${data.aws_ecr_authorization_token.ecr_token[0].password}") : ""
  ecr-url = (var.cloudone-settings.deploy_c1cs) ? aws_ecr_repository.poc[0].repository_url : ""
  external-dns-settings = [
    {
      name  = "provider"
      value = "aws"
    },
    {
      name  = "domainFilters[0]"
      value = var.dns-settings.lab_private_domain
    },
    {
      name  = "policy"
      value = "upsert-only"
    },
    {
      name  = "registry"
      value = "txt"
    },
    {
      name  = "aws.region"
      value = var.general-settings.lab_region
    },
    {
      name  = "rbac.create"
      value = "true"
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "external-dns"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = "${local.external-dns-role}"
    }
  ]

  smartcheck-settings = [
    {
      name  = "cloudOne.apiKey"
      value = local.c1cs_scanner_apikey
    },
    {
      name  = "auth.password"
      value = var.general-settings.lab_password
    },
    {
      name  = "auth.secretSeed"
      value = var.general-settings.lab_password
    },
    {
      name  = "certificate.secret.name"
      value = "dssc-tls-secret"
    },
    {
      name  = "registry.enabled"
      value = true
    },
    {
      name  = "registry.auth.username"
      value = "dssc-user"
    },
    {
      name  = "registry.auth.password"
      value = var.general-settings.lab_password
    },
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    },
    {
      name  = "service.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
      value = "smartcheck.${var.dns-settings.lab_private_domain}"
    }
  ]
}

# install external-dns

resource "aws_iam_policy" "c1cs-AllowEKSExternalDNS-policy" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  name        = join("-", ["${local.prefix}-AllowEKSExternalDNS", random_string.suffix.result])
  path        = "/"
  description = "Allow external-dns to access and update Route53 resources"

  policy = <<-EOT
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource": [
          "arn:aws:route53:::hostedzone/${aws_route53_zone.private-dns-admin.zone_id}"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  }
  EOT

  tags = {
    Terraform   = "true"
    Environment = "poc"
    Vendor      = "Trend Micro"
    Name        = join("-", ["${local.prefix}-AllowEKSExternalDNS", random_string.suffix.result])
  }
}

resource "aws_iam_role_policy_attachment" "c1cs-AllowEKSExternalDNS-policy" {
  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  policy_arn = aws_iam_policy.c1cs-AllowEKSExternalDNS-policy[0].arn
  role       = aws_iam_role.c1cs-AllowEKSExternalDNS-role[0].name
}

resource "aws_iam_role_policy_attachment" "c1cs-AmazonEKSCluster-policy" {
  count      = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.c1cs-AllowEKSExternalDNS-role[0].name
}

resource "aws_iam_role" "c1cs-AllowEKSExternalDNS-role" {
  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  name  = "${local.prefix}-AllowEKSExternalDNS-role"

  assume_role_policy = <<-EOT
  {
  "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::${var.general-settings.lab_aws_acc}:oidc-provider/${local.oidc_id}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "${local.oidc_id}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  }
  EOT
}

resource "helm_release" "external_dns" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [aws_route53_record.route53-TXT-records, aws_route53_record.route53-A-records]

  chart            = "external-dns"
  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  create_namespace = true

  dynamic "set" {
    for_each = local.external-dns-settings
    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
}

# Install Smartcheck
resource "time_sleep" "wait-for-external-dns" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on      = [helm_release.external_dns[0]]
  create_duration = "15s"
}

# 1. Install C1CS Admission Controller

resource "kubernetes_namespace" "trendmicro-namespace" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [time_sleep.wait-for-external-dns[0]]

  metadata {
    name = "trendmicro"
  }
}

resource "helm_release" "admission-controller" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [kubernetes_namespace.trendmicro-namespace[0]]

  name      = "container-security"
  namespace = "trendmicro"

  chart = "https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz"

  set {
    name  = "cloudOne.admissionController.apiKey"
    value = local.c1cs_cluster_apikey
  }

}

# 2 Install Deep Security Smart Check

#create tls secret
resource "kubernetes_secret" "dssc-tls-secret" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [kubernetes_namespace.trendmicro-namespace[0]]
  type       = "kubernetes.io/tls"

  metadata {
    name      = "dssc-tls-secret"
    namespace = "trendmicro"
  }

  data = {
    "tls.crt" = "${local.public_key}"
    "tls.key" = "${local.private_key}"
  }
}

resource "helm_release" "ds-smartcheck" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [kubernetes_namespace.trendmicro-namespace[0]]

  name      = "deepsecurity-smartcheck"
  namespace = "trendmicro"

  chart = "https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz"

  dynamic "set" {
    for_each = local.smartcheck-settings
    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-internal"
    value = "true"
    type  = "string"
  }

}

# install tmvwa

resource "kubernetes_namespace" "tmvwa-namespace" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [time_sleep.wait-for-external-dns[0]]

  metadata {
    name = "tmvwa"
  }
}

resource "kubernetes_secret" "ecr-secret" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [kubernetes_namespace.tmvwa-namespace[0]]

  metadata {
    name      = "regcred"
    namespace = "tmvwa"
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${local.ecr-url}": {
      "auth": "${local.ecr-password}"
    }
  }
}
DOCKER
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_deployment" "tmvwa-deployment" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [kubernetes_secret.ecr-secret[0]]

  metadata {
    name = "tmvwa"
    labels = {
      app = "tmvwa"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "tmvwa"
      }
    }

    template {
      metadata {
        labels = {
          app = "tmvwa"
        }
      }

      spec {

        image_pull_secrets {
          name = "regcred"
        }

        container {
          image = "${local.ecr-url}:v1"
          name  = "tmvwa"
          port {
            container_port = "80"
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "tmvwa-service" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  depends_on = [kubernetes_deployment.tmvwa-deployment[0]]

  metadata {
    name      = "tmvwa"
    namespace = "tmvwa"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
      //"service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
      "external-dns.alpha.kubernetes.io/hostname" = "tmvwa.${var.dns-settings.lab_private_domain}"
    }
  }
  spec {
    selector = {
      app = "tmvwa"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
