
==========================================================================
==============CloudOne File Storage Security Info for PoC/demo ==========
==========================================================================

- This section is relevant if you specified [ deploy_c1fss = true ] in your cloudone-settings section in terraform.tfvars file
- On AWS: There are resources:
  + 3 buckets provisioned with this terraform
    . Scan bucket which user uploads files to: ${BUCKET_TO_SCAN}
    . Quarantine bucket contains files detected with threats: ${QUARANTINEBUCKET}
    . Clean bucket contains clean files: ${PROMOTEBUCKET}
  + Cloudformation Scanner Stack
  + Cloudformation Storage Stack

  + Lambda function for Post-Scan Action: once user finishes uploading files, this function will be in charge of moving clean files / quarantined files to respective buckets
  + S3-uploader (only if you specified [ use_uploader = true ] in s3-settings section of your terraform.tfvars file ). This S3-uploader is 3rd-party Lambda app available in Lambda App repo.
  (https://ap-southeast-1.console.aws.amazon.com/lambda/home?region=ap-southeast-1#/create/app?applicationId=arn:aws:serverlessrepo:us-east-1:233054207705:applications/uploader)
  github: https://github.com/evanchiu/serverless-galleria/releases/tag/v1.1.0

- On CloudOne: Scanner & Storage stack will be auto-created by the script. you can go to CloudOne console to verify

- Without S3-uploader: you can test without S3-uploader
  + in admin-vm terminal:
  $ curl -O https://secure.eicar.org/eicar_com.zip
  $ aws s3 cp eicar_com.zip s3://${BUCKET_TO_SCAN}
  $ aws s3 cp dsa-install.sh s3://${BUCKET_TO_SCAN}
  $ aws s3 ls s3://${BUCKET-TO-SCAN}
==> Result: eicar is moved to ${QUARANTINEBUCKET}
            dsa-install is moved to ${PROMOTEBUCKET}

- With S3-Uploader:
  + In Windows bastion hosts: open browser
  + go to: ${S3_UPLOADER_URL}
  + drag a file to drop into the orange area
  + use s3 ls command to verify the post-scan action (same as above)
