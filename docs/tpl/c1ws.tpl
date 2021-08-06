
==========================================================================
==============CloudOne Workload Security Info for PoC/demo ===============
==========================================================================

- All instances are deployed without any policy
- You can perform your own test cases for Windows / Linux Bastion hosts
- You can look at all the test cases for Workload Security, Application Security here: https://wiki.jarvis.trendmicro.com/display/SE/POC+Project#
(Thank you very much MR. Renaud Bidou for these brilliant resources)
- In Linux bastion host (admin-vm):
  + docker is already installed
  + For C1WS - Container protection capabilities: you can test with TrendNet/TMVWA (which is already installed and run as container - thank you MR. Renaud Bidou again for this fabulous application)
For more information about trendnet: https://teams.microsoft.com/_#/files/5.3%20%20%F0%9F%98%8E%F0%9F%AA%96%20PoC%20-%20eDemo?threadId=19%3A341e5cbdcfbd46c09570a16a3beff00b%40thread.tacv2&ctx=channel&context=TrendNet&rootfolder=%252Fsites%252FGlobalTechConnect%252FShared%2520Documents%252F33.%2520%25F0%259F%25AA%2596PoC%252FTrendNet

- To access TrendNet: in Windows bastion host, open browser and go to: ${TRENDNET_URL}
  + enable TMVWA (it is a containerized vulnerable web application built by MR. Renaud Bidou )
(for more information on TMVWA, please go here: https://teams.microsoft.com/_#/files/5.3%20%20%F0%9F%98%8E%F0%9F%AA%96%20PoC%20-%20eDemo?threadId=19%3A341e5cbdcfbd46c09570a16a3beff00b%40thread.tacv2&ctx=channel&context=33.%2520%25F0%259F%25AA%2596PoC&rootfolder=%252Fsites%252FGlobalTechConnect%252FShared%2520Documents%252F33.%2520%25F0%259F%25AA%2596PoC)
  + please read the doc in the above link for more information
