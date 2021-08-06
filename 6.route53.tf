locals {

  // Route53
  A-records = [
    aws_spot_instance_request.win-rdp.private_ip,
    aws_spot_instance_request.admin-vm.private_ip,
    aws_spot_instance_request.win-rdp.public_ip,
    aws_spot_instance_request.admin-vm.public_ip,
    "${element(concat(aws_spot_instance_request.windows-attacker[*].public_ip, [aws_spot_instance_request.admin-vm.private_ip]), 0)}",
    "${element(concat(aws_spot_instance_request.linux-attacker[*].public_ip, [aws_spot_instance_request.admin-vm.private_ip]), 0)}",
    "${element(concat(aws_spot_instance_request.harbor-vm[*].private_ip, [aws_spot_instance_request.admin-vm.private_ip]), 0)}",
    "${element(concat(aws_spot_instance_request.harbor-vm[*].private_ip, [aws_spot_instance_request.admin-vm.private_ip]), 0)}",
    aws_spot_instance_request.admin-vm.private_ip,
    aws_spot_instance_request.admin-vm.private_ip,
    aws_spot_instance_request.admin-vm.private_ip
  ]

  TXT-records = {
    name = [
      "smartcheck",
      "k8-tmvwa"
    ],
    value = [
      "heritage=external-dns,external-dns/owner=default,external-dns/resource=service/trendmicro/proxy",
      "heritage=external-dns,external-dns/owner=default,external-dns/resource=service/tmvwa/tmvwa"
    ]
  }

}

resource "aws_route53_zone" "private-dns-admin" {
  name = var.dns-settings.lab_private_domain

  vpc {
    vpc_id = local.admin-vpc-id
  }
}

resource "aws_route53_zone_association" "private-dns-eks" {

  count   = (var.cloudone-settings.deploy_c1cs) ? 1 : 0
  zone_id = aws_route53_zone.private-dns-admin.zone_id
  vpc_id  = local.eks-vpc-id
}

resource "aws_route53_zone_association" "private-dns-attacker" {
  count   = (var.cloudone-settings.deploy_c1ns) ? 1 : 0
  zone_id = aws_route53_zone.private-dns-admin.zone_id
  vpc_id  = local.attacker-vpc-id
}

resource "aws_route53_record" "route53-A-records" {

  count = length(local.A-records)

  zone_id = aws_route53_zone.private-dns-admin.zone_id

  name = var.dns-settings.dns-hostnames[count.index]
  type = "A"
  ttl  = 30

  records = [local.A-records[count.index]]

}

resource "aws_route53_record" "route53-TXT-records" {

  count = 2

  zone_id = aws_route53_zone.private-dns-admin.zone_id

  name = local.TXT-records.name[count.index]
  type = "TXT"
  ttl  = 30

  records = [local.TXT-records.value[count.index]]

}
