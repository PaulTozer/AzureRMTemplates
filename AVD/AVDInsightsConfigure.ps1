[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(mandatory = $false)]
	[string]$AADTenantId,
	
	[Parameter(mandatory = $false)]
	[string]$AzureSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(mandatory = $true)]
    [string]$LogAnalyticsResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$LogAnalyticsWorkspaceName,
    
    [Parameter(mandatory = $true)]
    [string]$HostPoolName,

    [Parameter(Mandatory = $true)]
    [string]$HostPoolResourceGroup,

    [Parameter(mandatory = $true)] 
    [string]$WorkspaceName
)


# Get the azure context
$AzContext = Get-AzContext
if (!$AzContext) {
	throw 'No Azure context found. Please authenticate to Azure using Login-AzAccount cmdlet and then run this script'
}

if (!$AADTenantId) {
	$AADTenantId = $AzContext.Tenant.Id
}
if (!$AzureSubscriptionId) {
	$AzureSubscriptionId = $AzContext.Subscription.Id
}

if ($AADTenantId -ne $AzContext.Tenant.Id -or $AzureSubscriptionId -ne $AzContext.Subscription.Id) {
	# Select the subscription
	$AzContext = Set-AzContext -SubscriptionId $AzureSubscriptionId -TenantId $AADTenantId

	if ($AADTenantId -ne $AzContext.Tenant.Id -or $AzureSubscriptionId -ne $AzContext.Subscription.Id) {
		throw "Failed to set Azure context with subscription ID '$AzureSubscriptionId' and tenant ID '$AADTenantId'. Current context: $($AzContext | Format-List -Force | Out-String)"
	}
}

# Connect to Log Analytics Workspace - If it does not exist then create a new one

try {
    $Workspace = Get-AzOperationalInsightsWorkspace -Name $LogAnalyticsWorkspaceName -ResourceGroupName $LogAnalyticsResourceGroup  -ErrorAction Stop
    $WorkspaceLocation = $Workspace.Location
    Write-Output "Connected to workspace named $LogAnalyticsWorkspaceName in region $WorkspaceLocation..."
    } 
catch {
    Write-Output "Creating new workspace named $LogAnalyticsWorkspaceName in region $Location..."
    # Create the new workspace for the given name, region, and resource group
    $Workspace = New-AzOperationalInsightsWorkspace -Location $Location -Name $LogAnalyticsWorkspaceName -Sku pergb2018 -ResourceGroupName $LogAnalyticsResourceGroup
}

# Get the Host Pool details so we can add the diagnostic settings
$HostPool = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $HostPoolResourceGroup

# Check that Microsoft.Insights is registered. If not register

$InsightsRegistered = (Get-AzResourceProvider -ProviderNamespace "microsoft.insights").RegistrationState[0].Equals("Registered")
if (-not $InsightsRegistered)
{
    Register-AzResourceProvider -ProviderNamespace "microsoft.insights"
    # wait a minute whilst it registers 
    Start-Sleep 60
}

# Set the hostpool diagnostics settings to point to the log analytics workspace
Set-AzDiagnosticSetting -ResourceId $HostPool.Id -Enabled $True -Category "Checkpoint","Error","Management","Connection","HostRegistration","AgentHealthStatus" -WorkspaceId $Workspace.ResourceId

# Set the AVD workspace diagnostics settings to point to the log analytics workspace

$AVDWorkspace = Get-AzWvdWorkspace -Name $WorkspaceName -ResourceGroupName $HostPoolResourceGroup
Set-AzDiagnosticSetting -ResourceId $AVDWorkspace.Id -Enabled $True -Category "Checkpoint","Error","Management","Feed" -WorkspaceId $Workspace.ResourceId

# Setup Event Log monitoring

New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "WindowsApplicationEventLog" -EventLogName "Application" -CollectErrors -CollectWarnings -Force
New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "WindowsSystemEventLog" -EventLogName "System" -CollectErrors -CollectWarnings -Force
New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "TerminalServicesRemoteConnectionManagerAdmin" -EventLogName "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin" -CollectErrors -CollectWarnings -CollectInformation -Force
New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "TerminalServicesLocalSessionManagerOperational" -EventLogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" -CollectErrors -CollectWarnings -CollectInformation -Force
New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "FSLogixAppsAdmin" -EventLogName "Microsoft-FSLogix-Apps/Admin" -CollectErrors -CollectWarnings -CollectInformation -Force
New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "FSLogixAppsOperational" -EventLogName "Microsoft-FSLogix-Apps/Operational" -CollectErrors -CollectWarnings -CollectInformation -Force

# Add Performance counters

New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "LogicalDiskAvgDiskQueueLengthC" -ObjectName "LogicalDisk" -InstanceName "C:" -CounterName "Avg. Disk Queue Length" -IntervalSeconds 60 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "LogicalDiskAvgDiskSecTransferC" -ObjectName "LogicalDisk" -InstanceName "C:" -CounterName "Avg. Disk sec/Transfer" -IntervalSeconds 60 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "LogicalDiskCurrentDiskQueueLengthC" -ObjectName "LogicalDisk" -InstanceName "C:" -CounterName "Current Disk Queue Length" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "LogicalDiskFreeSpaceC" -ObjectName "LogicalDisk" -InstanceName "C:" -CounterName "% Free Space" -IntervalSeconds 60 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "MemoryAvailableMB" -ObjectName "Memory" -InstanceName "*" -CounterName "Available Mbytes" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "MemoryPageFaultsSec" -ObjectName "Memory" -InstanceName "*" -CounterName "Page Faults/sec" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "MemoryPagesSec" -ObjectName "Memory" -InstanceName "*" -CounterName "Pages/sec" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "MemoryCommited" -ObjectName "Memory" -InstanceName "*" -CounterName "% Committed Bytes In Use" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "PhysicalDiskAvgDiskQueueLength" -ObjectName "PhysicalDisk" -InstanceName "*" -CounterName "Avg. Disk Queue Length" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "PhysicalDiskAvgRead" -ObjectName "PhysicalDisk" -InstanceName "*" -CounterName "Avg. Disk sec/Read" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "PhysicalDiskAvgTransfer" -ObjectName "PhysicalDisk" -InstanceName "*" -CounterName "Avg. Disk sec/Transfer" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "PhysicalDiskAvgWrite" -ObjectName "PhysicalDisk" -InstanceName "*" -CounterName "Avg. Disk sec/Write" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "ProcessorTime" -ObjectName "Processor Information" -InstanceName "_Total" -CounterName "% Processor Time" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "ActiveSessions" -ObjectName "Terminal Services" -InstanceName "*" -CounterName "Active Sessions" -IntervalSeconds 60 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "InactiveSessions" -ObjectName "Terminal Services" -InstanceName "*" -CounterName "Inactive Sessions" -IntervalSeconds 60 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "TotalSessions" -ObjectName "Terminal Services" -InstanceName "*" -CounterName "Total Sessions" -IntervalSeconds 60 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "InputDelayPerProcess" -ObjectName "User Input Delay per Process" -InstanceName "*" -CounterName "Max Input Delay" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "InputDelayPerSession" -ObjectName "User Input Delay per Session" -InstanceName "*" -CounterName "Max Input Delay" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "CurrentTCPRTT" -ObjectName "RemoteFX Network" -InstanceName "*" -CounterName "Current TCP RTT" -IntervalSeconds 30 -Force
New-AzOperationalInsightsWindowsPerformanceCounterDataSource  -ResourceGroupName $LogAnalyticsResourceGroup -WorkspaceName $LogAnalyticsWorkspaceName -Name "CurrentUDPBandwidth" -ObjectName "RemoteFX Network" -InstanceName "*" -CounterName "Current UDP Bandwidth" -IntervalSeconds 30 -Force

$SessionHosts = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $HostPoolResourceGroup

# Get log analytics key and customer ID

$primarykey = (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $LogAnalyticsResourceGroup -Name $LogAnalyticsWorkspaceName).PrimarySharedKey  
$ProtectedSettings = @{"workspaceKey" = $primarykey}

$workspaceId = $Workspace.CustomerId
$PublicSettings = @{"workspaceId" = $workspaceId}

# Get VM name from Session Hosts and add Log Analytics Agent

foreach ($SessionHost in $SessionHosts) {
	
    # Extract the VM name from the Session host as it is FQDN and has additional formatting

    $SessionHostName = $SessionHost.Name.Split('/')[-1]
	[string]$VMName = $SessionHostName.Split('.')[0].ToLower()   

    # Install the Extension

    Set-AzVMExtension -ResourceGroupName  $HostPoolResourceGroup -VMName $VMName -ExtensionName "MicrosoftMonitoringAgent" -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "MicrosoftMonitoringAgent" -TypeHandlerVersion 1.0 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $Location
    
}

