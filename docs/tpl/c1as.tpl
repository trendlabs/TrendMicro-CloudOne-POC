
==========================================================================
==============CloudOne Application Security Info for PoC/demo ==========
==========================================================================

- This section is relevant if you specified [ deploy_c1as = true ] in your cloudone-settings section in terraform.tfvars file
- A Group is created in CloudOne AppSec web console with respective:
  . group name: ${GROUP_NAME}
  . group key: ${GROUP_KEY}
  . group secret: ${GROUP_SECRET}
- You can go to https://wiki.jarvis.trendmicro.com/display/SE/POC+Project# for test case reference
- There are 2 resources for Application Security test:
  + TMVWA Lambda funtion: Refer C1AS test case in the said link above
    To access the lambda function:
    . In Windows bastion host, open browser
    . Go to this link: ${TMVWA_URL}

  + TMVWA application: This applicatino is running in admin-vm as a containerized app. to check this
    . ssh go to admin-vm
    . run the following commands:
    $ docker image ls  # you should see the tmvwa is listed
    $ docker ps # you should see tmwva container is running and listening port 80/tcp

  To access TMVWA web console:
    . in Windows bastion host, open browser
    . go to: ${DOCKER_TMVWA_URL}

  if[ deploy_c1as = true ] then this container is already registered to C1AS group above, just follow the test case to see C1-AppSec in action
