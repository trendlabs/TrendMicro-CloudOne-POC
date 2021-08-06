# ! /usr/bin/env bash

url="https://cloudone.trendmicro.com/api/network/appliances"
secret="API-KEY"

echo "Getting list of appliances"
echo "api-secret-key: $secret"
response=$(curl --location --request GET $url \
                  --header "api-secret-key: $secret" \
                  --header "api-version: v1" \
                  --silent)

parsed=$(echo "${response}" | jq '.appliances')
len=$(echo "$parsed" | jq '. | length')
echo "Number of appliances found: $len"

if [[ ${len} == 0 ]]; then
  echo "Try deploying an appliance using CloudFormation Script."
  exit
else
  appliance="$(echo "${parsed[@]}" | jq -r .[].ID)"
  for id in ${appliance}
    do echo "Configuring AWS CloudWatch log settings on the NSVA ID: $id"
    curl --location --request POST "${url}/${id}/cloudwatchlogconfig" \
         --header "api-secret-key: ${secret}" \
         --header "api-version: v1" \
         --header "Content-Type: application/json" \
         --data-raw '{
              "logTypes":[
              {
                "logGroupName": "trendmicro-ns-ipsBlock-events",
                "logName": "ipsBlock",
                "enable": true
              },
              {
                "logGroupName": "trendmicro-ns-ipsAlert-events",
                "logName": "ipsAlert",
                "enable": true
              },
              {
                "logGroupName": "trendmicro-ns-reputation-Block-events",
                "logName": "reputationBlock",
                "enable": true
              },
              {
                "logGroupName": "trendmicro-ns-reputation-Alert-events",
                "logName": "reputationAlert",
                "enable": true
              },
              {
                "logGroupName": "trendmicro-ns-Quarantine-events",
                "logName": "quarantine",
                "enable": true
              }
              ]
              }'
  done
fi
