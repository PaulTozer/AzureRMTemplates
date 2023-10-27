$FolderName = "C:\Packages\M365"
New-Item $FolderName -ItemType Directory -Force
$ExecutableName = "OfficeDeploy.zip"
$path = "$($FolderName)\$ExecutableName"
$Uri = "https://raw.githubusercontent.com/PaulTozer/AzureRMTemplates/master/WVD/SessionHostImageCreator/M365Apps/OfficeDeploy.zip"
Invoke-WebRequest -Uri $Uri -OutFile $path
Expand-Archive -Path $path -DestinationPath $foldername -Force
$InstallExec = "OfficeDeploy\setup.exe"
$Switches = "/configure .\OfficeDeploy\Configuration.xml"
$OfficeExePath = Join-Path $path $InstallExec
$Installer = Start-Process -FilePath $OfficeExePath -ArgumentList $Switches -Wait -PassThru

