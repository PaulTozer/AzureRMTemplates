[CmdletBinding(SupportsShouldProcess = $true)]
param (
    
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $WVDInstallAgentExecutableName = "Microsoft.RDInfra.RDAgent.Installer-x64-1.0.2195.6400.msi",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $WVDInstallBootloaderExecutableName = "Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi",

    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $HostPoolName,

    [Parameter(Mandatory = $true)]
    [string] $Username,

    [Parameter(Mandatory = $true)]
    [string] $Password

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

Set-Logger "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\executionLog\WVDAgents" # inside "executionCustomScriptExtension_$scriptName_$date.log"

$WVDAgentInstallUri = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
$WVDAgentBootloaderUri = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"

Invoke-WebRequest -Uri $WVDAgentInstallUri -OutFile "$($PSScriptRoot)\$WVDInstallAgentExecutableName"
Invoke-WebRequest -Uri $WVDAgentBootloaderUri -OutFile "$($PSScriptRoot)\$WVDInstallBootloaderExecutableName"

$WVDAgentInstallLocation = "$($PSScriptRoot)\$WVDInstallAgentExecutableName"
$WVDBootloadertInstallLocation = "$($PSScriptRoot)\$WVDInstallBootloaderExecutableName"

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name PowershellGet -MinimumVersion 2.2.4.1 -Force
Install-Module -Name Az -Force -Verbose

Import-Module Az.Accounts -Force -Verbose
Import-Module Az.DesktopVirtualization -Force -Verbose

$Credential = New-Object System.Management.Automation.PsCredential($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))
Connect-AzAccount -Credential $Credential

$RegistrationTokenNew = Get-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $hostpoolname

$RegistrationKey = $RegistrationTokenNew.Token

$bootloader_deploy_statusAgent = { msiexec /i $WVDAgentInstallLocation REGISTRATIONTOKEN=$Registrationkey /quiet /qn /passive }
Invoke-Command $bootloader_deploy_statusAgent -Verbose
LogInfo("The exit code is $($bootloader_deploy_statusAgent.ExitCode)")
$bootloader_deploy_statusBootLoader = { msiexec /i $WVDBootloadertInstallLocation /quiet /qn /passive }
Invoke-Command bootloader_deploy_statusBootLoader -Verbose
LogInfo("The exit code is $($bootloader_deploy_statusBootLoader.ExitCode)")



