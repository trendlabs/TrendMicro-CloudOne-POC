<powershell>

# Creating User Accounts
net accounts /maxpwage:UNLIMITED
net user '${win_username}' '${lab_password}' /ADD /PASSWORDCHG:NO /FULLNAME:'${win_user_fullname}' /Y
net localgroup administrators ${win_username} /add

# create team POC - temporarily
net user thanhnq ${lab_password} /ADD /PASSWORDCHG:NO /FULLNAME:"Thanh Q Nguyen" /Y
net localgroup administrators thanhnq /add

Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name NoAutoUpdate -Value 1 

Remove-WindowsFeature Windows-Defender, Windows-Defender-GUI
Set-NetFirewallProfile -All -Enabled False

Set-TimeZone "SE Asia Standard Time"

New-Item c:\vnlabs -itemtype directory

# Disable firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Enable Remote management via WinRM from any computer
Enable-PSRemoting -Force
Set-Item wsman:\localhost\client\trustedhosts * -Force

# Installing Software
Set-ExecutionPolicy AllSigned; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install googlechrome mobaxterm -y --ignore-checksum

#Set-ExecutionPolicy Unrestricted
Set-ExecutionPolicy Unrestricted -Force

# install AWS CLIv2
$command = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12"
Invoke-Expression $command
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -Outfile C:\AWSCLIV2.msi
$arguments = "/i `"C:\AWSCLIV2.msi`" /quiet"
Start-Process msiexec.exe -ArgumentList $arguments -Wait

# install DSA
${win_deployment_script}

$keycontent=@"
${key}
"@
Set-Content -Path c:\vnlabs\${keyfile} -Value $keycontent
#
# $hostsFile  = "$($env:windir)\system32\Drivers\etc\hosts"
#
# $hostsEntry3 = '$LINUX-VICTIM linux-victim'
# $hostsEntry4 = '$WINDOWS-VICTIM windows-victim'

# Add-Content -Path $hostsFile -Value $hostsEntry3
# Add-Content -Path $hostsFile -Value $hostsEntry4

</powershell>
