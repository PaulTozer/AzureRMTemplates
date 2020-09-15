[CmdletBinding(SupportsShouldProcess = $true)]
param (
    
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $ExecutableName = "Teams_windows_x64.msi"

)

#####################################

##########
# Helper #
##########
#region Functions
function LogInfo($message) {
    Log "Info" $message
}

function LogError($message) {
    Log "Error" $message
}

function LogSkip($message) {
    Log "Skip" $message
}
function LogWarning($message) {
    Log "Warning" $message
}

function Log {

    <#
    .SYNOPSIS
   Creates a log file and stores logs based on categories with tab seperation
    .PARAMETER category
    Category to put into the trace
    .PARAMETER message
    Message to be loged
    .EXAMPLE
    Log 'Info' 'Message'
    #>

    Param (
        $category = 'Info',
        [Parameter(Mandatory = $true)]
        $message
    )

    $date = get-date
    $content = "[$date]`t$category`t`t$message`n"
    Write-Verbose "$content" -verbose

    if (! $script:Log) {
        $File = Join-Path $env:TEMP "log.log"
        Write-Error "Log file not found, create new $File"
        $script:Log = $File
    }
    else {
        $File = $script:Log
    }
    Add-Content $File $content -ErrorAction Stop
}

function Set-Logger {
    <#
    .SYNOPSIS
    Sets default log file and stores in a script accessible variable $script:Log
    Log File name "executionCustomScriptExtension_$date.log"
    .PARAMETER Path
    Path to the log file
    .EXAMPLE
    Set-Logger
    Create a logger in
    #>

    Param (
        [Parameter(Mandatory = $true)]
        $Path
    )

    # Create central log file with given date

    $date = Get-Date -UFormat "%Y-%m-%d %H-%M-%S"

    $scriptName = (Get-Item $PSCommandPath ).Basename
    $scriptName = $scriptName -replace "-", ""

    Set-Variable logFile -Scope Script
    $script:logFile = "executionCustomScriptExtension_" + $scriptName + "_" + $date + ".log"

    if ((Test-Path $path ) -eq $false) {
        $null = New-Item -Path $path -type directory
    }

    $script:Log = Join-Path $path $logfile

    Add-Content $script:Log "Date`t`t`tCategory`t`tDetails"
}
#endregion

Set-Logger "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\executionLog\Teams" # inside "executionCustomScriptExtension_$scriptName_$date.log"

$Uri = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
$Uri2 = "https://aka.ms/vs/16/release/vc_redist.x64.exe"
$Uri3 = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt"

Invoke-WebRequest -Uri $Uri -OutFile "$($PSScriptRoot)\$ExecutableName"
Invoke-WebRequest -Uri $Uri2 -OutFile "$($PSScriptRoot)\vc_redist.x64.exe"
Invoke-WebRequest -Uri $Uri3 -OutFile "$($PSScriptRoot)\MsRdcWebRTC.msi"

$ExePath = Join-Path $PSScriptRoot $ExecutableName
$Switches = "/install /passive /norestart"
$RTCPath = "$($PSScriptRoot)\MsRdcWebRTC.msi"

LogInfo("Installing VC++")
$Installer = Start-Process -FilePath "$($PSScriptRoot)\vc_redist.x64.exe" -ArgumentList $Switches -Wait -PassThru

LogInfo("Installing Teams Web RTC")
$scriptBlockRTC = { msiexec /i $RTCPath /l*v "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\executionLog\Teams\InstallWebRTCLog.txt" }
Invoke-Command $scriptBlockRTC -Verbose

$MSIPath = "$($PSScriptRoot)\$ExecutableName"
LogInfo("Installing teams from path $MSIPath")

LogInfo("Setting registry key Teams")
if ((Test-Path "HKLM:\Software\Microsoft\Teams") -eq $false) {
    New-Item -Path "HKLM:\Software\Microsoft\Teams" -Force
}
New-ItemProperty "HKLM:\Software\Microsoft\Teams" -Name "IsWVDEnvironment" -Value 1 -PropertyType DWord -Force
LogInfo("Set IsWVDEnvironment DWord to value 1 successfully.")

$scriptBlock = { msiexec /i $MSIPath /l*v "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\executionLog\Teams\InstallLog.txt" ALLUSER=1 ALLUSERS=1 }
LogInfo("Invoking command with the following scriptblock: $scriptBlock")
LogInfo("Install logs can be found in the InstallLog.txt file in this folder.")
Invoke-Command $scriptBlock -Verbose

LogInfo("Teams was successfully installed")
