<#
  .SYNOPSIS
	Initiate the Windows Update Process
  .DESCRIPTION
  Creates a scheduled task to apply the windows updates.
  Disables WinRM on reboot, so the scheduled task can reboot multiple times
  until all updates are installed. (see packers-windows-update.ps1 for
  further details on the actual update process)

#>

# Initiate the Windows Update operation.

$ErrorActionPreference = 'Stop'

. C:\Packer\Scripts\windows-env.ps1

Write-Output "Setting up Windows Update"

Install-7ZipPackage
if (-not (Test-Path "$PackerLogs\PSWindowsUpdate.installed")) {
  # Download and install PSWindows Update Modules.
  Download-File "https://artifactory.delivery.puppetlabs.net/artifactory/generic/buildsources/windows/pswindowsupdate/PSWindowsUpdate.1.6.1.1.zip" "$Env:TEMP/pswindowsupdate.zip"
  mkdir -Path "$Env:TEMP\PSWindowsUpdate"
  $zproc = Start-Process "$7zip" @SprocParms -ArgumentList "x $Env:TEMP/pswindowsupdate.zip -y -o$PackerPsModules"
  $zproc.WaitForExit()
  Touch-File "$PackerLogs\PSWindowsUpdate.installed"
}

if ($WindowsVersion -like $WindowsServer2016) {
  Write-Output "Disabling some more Windows Update (10) parameters"
  Write-Output "Disable seeding of updates to other computers via Group Policies"
  force-mkdir "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0
}

Write-Output "========== Initiating Windows Update This will take some time                   ========"
Write-Output "========== A log and update report will be given at the end of the update cycle ========"

# Need to pick up Admin Username/Password from Environment for sched task
Write-Output "Create Bootstrap Scheduled Task"
schtasks /create /tn PackerWinUpdate /rl HIGHEST /ru "$ENV:ADMIN_USERNAME" /RP "$ENV:ADMIN_PASSWORD" /IT /F /SC ONSTART /DELAY 0000:20 /TR 'cmd /c c:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe -sta -WindowStyle Normal -ExecutionPolicy Bypass -NonInteractive -NoProfile -File C:\Packer\Scripts\packer-windows-update.ps1 >> C:\Packer\Logs\windows-update.log'

# Disable WinRM until further notice.
Set-Service "WinRM" -StartupType Disabled
