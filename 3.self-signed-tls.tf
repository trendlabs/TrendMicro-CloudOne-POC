locals {
  //keypair
  keyfile     = "${var.general-settings.key_name}.pem"
  pub_keyfile = "${var.general-settings.key_name}.pub"
  org_name    = "Trendlabs VN"

  private_key = tls_private_key.private-key.private_key_pem
  ca_crt      = tls_self_signed_cert.ca.cert_pem
  public_key  = tls_locally_signed_cert.cert.cert_pem

}

resource "tls_private_key" "private-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "poc-keypair" { # Create a "myKey" to AWS
  key_name   = var.general-settings.key_name
  public_key = tls_private_key.private-key.public_key_openssh

}

resource "local_file" "public-key" {

  content = tls_private_key.private-key.public_key_openssh

  filename = local.pub_keyfile

  provisioner "local-exec" {
    when       = destroy
    command    = "ssh-add -d ${self.filename}"
    on_failure = continue
  }
}

resource "local_file" "private-key" {
  content = tls_private_key.private-key.private_key_pem

  filename = local.keyfile

  provisioner "local-exec" {
    command    = <<-EOT
      chmod 400 ${self.filename}
      ssh-add ${self.filename}
    EOT
    on_failure = continue
  }

}

# create a self-signed certificate for lab private domain (should be wildcard supported)
# will be used for all ssl usages

resource "tls_self_signed_cert" "ca" {
  key_algorithm     = tls_private_key.private-key.algorithm
  private_key_pem   = tls_private_key.private-key.private_key_pem
  is_ca_certificate = true

  validity_period_hours = "3650"

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature"
  ]

  dns_names = ["*.${var.dns-settings.lab_private_domain}"]

  subject {
    common_name  = var.dns-settings.lab_private_domain
    organization = local.org_name
  }

}

resource "tls_cert_request" "cert" {
  key_algorithm   = tls_private_key.private-key.algorithm
  private_key_pem = tls_private_key.private-key.private_key_pem

  dns_names = [
    "*.${var.dns-settings.lab_private_domain}"
  ]

  subject {
    common_name  = var.dns-settings.lab_private_domain
    organization = local.org_name
  }
}

resource "tls_locally_signed_cert" "cert" {
  cert_request_pem = tls_cert_request.cert.cert_request_pem

  ca_key_algorithm   = tls_private_key.private-key.algorithm
  ca_private_key_pem = tls_private_key.private-key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = "3650"
  allowed_uses = [
    "key_encipherment",
    "server-auth",
    "digital_signature"
  ]

}
