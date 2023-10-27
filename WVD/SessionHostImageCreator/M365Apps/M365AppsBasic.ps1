$ExecutableName = "OfficeDeploy.zip"
$Uri = "https://raw.githubusercontent.com/PaulTozer/AzureRMTemplates/master/WVD/SessionHostImageCreator/M365Apps/OfficeDeploy.zip"
Invoke-WebRequest -Uri $Uri -OutFile "$($PSScriptRoot)\$ExecutableName"
$M365ArchivePath = Join-Path $PSScriptRoot "OfficeDeploy.zip"
Expand-Archive -Path $M365ArchivePath -DestinationPath $PSScriptRoot
$ExecutableName = "OfficeDeploy\setup.exe"
$Switches = "/configure .\OfficeDeploy\Configuration.xml"
$Installer = Start-Process -FilePath $FSLogixExePath -ArgumentList $Switches -Wait -PassThru

