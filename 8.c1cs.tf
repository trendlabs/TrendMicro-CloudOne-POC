locals {

  // C1CS
  c1cs_policy_id      = (var.cloudone-settings.deploy_c1cs) ? (jsondecode(restapi_object.c1cs-new-policy[0].api_response)).id : "none"
  c1cs_cluster_apikey = (var.cloudone-settings.deploy_c1cs) ? (jsondecode(restapi_object.c1cs-new-cluster[0].api_response)).apiKey : "none"
  c1cs_scanner_apikey = (var.cloudone-settings.deploy_c1cs) ? (jsondecode(restapi_object.c1cs-new-scanner[0].api_response)).apiKey : "none"

}


# 1. Create Policy
resource "restapi_object" "c1cs-new-policy" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  path          = "/container/policies"
  create_method = "POST"

  data = <<EOF
{
  "name": "${local.prefix}.POC.Policy",
  "description": "Cloud One Container PoC Policy",
  "default": {
               "rules": [
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "podSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "runAsNonRoot",
                           "value": "false"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "podSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "hostNetwork",
                           "value": "true"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "podSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "hostIPC",
                           "value": "true"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "podSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "hostPID",
                           "value": "true"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "containerSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "runAsNonRoot",
                           "value": "false"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "containerSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "privileged",
                           "value": "true"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "containerSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "allowPrivilegeEscalation",
                           "value": "true"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "containerSecurityContext",
                       "enabled": true,
                       "statement": {
                           "key": "readOnlyRootFilesystem",
                           "value": "false"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "unscannedImage",
                       "enabled": false
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "malware",
                       "enabled": true,
                       "statement": {
                           "key": "count",
                           "value": "0"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "vulnerabilities",
                       "enabled": true,
                       "statement": {
                           "key": "max-severity",
                           "value": "none"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "contents",
                       "enabled": false,
                       "statement": {
                           "key": "max-severity",
                           "value": "high"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "checklists",
                       "enabled": false,
                       "statement": {
                           "key": "max-severity",
                           "value": "high"
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "cvssAttackVector",
                       "enabled": true,
                       "statement": {
                           "properties": [
                               {
                                   "key": "cvss-attack-vector",
                                   "value": "network"
                               },
                               {
                                   "key": "max-severity",
                                   "value": "medium"
                               }
                           ]
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "cvssAttackComplexity",
                       "enabled": true,
                       "statement": {
                           "properties": [
                               {
                                   "key": "cvss-attack-complexity",
                                   "value": "high"
                               },
                               {
                                   "key": "max-severity",
                                   "value": "high"
                               }
                           ]
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "cvssAvailability",
                       "enabled": false,
                       "statement": {
                           "properties": [
                               {
                                   "key": "cvss-availability",
                                   "value": "high"
                               },
                               {
                                   "key": "max-severity",
                                   "value": "high"
                               }
                           ]
                       }
                   },
                   {
                       "action": "log",
                       "mitigation": "log",
                       "type": "checklistProfile",
                       "enabled": false,
                       "statement": {
                           "properties": [
                               {
                                   "key": "checklist-profile",
                                   "value": "hipaa"
                               },
                               {
                                   "key": "max-severity",
                                   "value": "high"
                               }
                           ]
                       }
                   }
               ]
  }

}
EOF
}

# 2. Create Cluster
resource "restapi_object" "c1cs-new-cluster" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  path          = "/container/clusters"
  create_method = "POST"

  data = <<EOF
{
  "name": "${local.prefix}.POC.Cluster",
  "description": "New Cluster for POC",
  "policyID": "${local.c1cs_policy_id}",
  "runtimeEnabled": false
}
EOF

}

# 3. Create Scanner
resource "restapi_object" "c1cs-new-scanner" {

  count = (var.cloudone-settings.deploy_c1cs) ? 1 : 0

  path          = "/container/scanners"
  create_method = "POST"

  data = <<EOF
{
  "name": "${local.prefix}.POC.Scanner",
  "description": "New Scanner for POC"
}
EOF

}
