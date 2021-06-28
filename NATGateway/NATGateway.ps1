[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(mandatory = $false)]
	[string]$AADTenantId,
	
	[Parameter(mandatory = $false)]
	[string]$AzureSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(mandatory = $true)]
    [string]$VNetResourceGroup,

    [Parameter(mandatory = $true)]
    [string]$VNetName,

    [Parameter(Mandatory = $true)]
    [string]$AVDSubnet,
    
    [Parameter(mandatory = $true)]
    [string]$NATGatewayName
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

# Get VNET details

$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $VNetResourceGroup

# Create new public IP address

$NATGatewayPIP = New-AzPublicIpAddress -Name $NATGatewayName -Location $Location -Sku Standard -AllocationMethod Static -ResourceGroupName $VNetResourceGroup -Force

# Create NAT Gateway

$NATGateway = New-AzNatGateway -Name $NATGatewayName -Location $Location -IdleTimeoutInMinutes 10 -PublicIpAddress $NATGatewayPIP -ResourceGroupName $VNetResourceGroup -Sku Standard -Force

# Set NAT Gateway on AVD Subnet

$subnet = Get-AzVirtualNetworkSubnetConfig -Name $AVDSubnet -VirtualNetwork $vnet
Set-AzVirtualNetworkSubnetConfig -Name $subnet.Name -VirtualNetwork $vnet -AddressPrefix $subnet.AddressPrefix -Natgateway $NATGateway

$vnet | Set-AzVirtualNetwork
