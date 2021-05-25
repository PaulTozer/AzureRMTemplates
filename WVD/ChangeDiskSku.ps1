
    Param 
        (    
            [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
            [String] 
            $AzureResourceGroup,
            [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
            [String] 
            $AzureNewDiskSku
        )

        $ConnectionAssetName = 'AzureRunAsConnection'
        $EnvironmentName = 'AzureCloud'

	    Write-Output "Get auto connection from asset: '$ConnectionAssetName'"
		$ConnectionAsset = Get-AutomationConnection -Name $ConnectionAssetName
		
		# Azure auth
		$AzContext = $null
		try {
			$AzAuth = Connect-AzAccount -ApplicationId $ConnectionAsset.ApplicationId -CertificateThumbprint $ConnectionAsset.CertificateThumbprint -TenantId $ConnectionAsset.TenantId -SubscriptionId $ConnectionAsset.SubscriptionId -EnvironmentName $EnvironmentName -ServicePrincipal
			if (!$AzAuth -or !$AzAuth.Context) {
				throw $AzAuth
			}
			$AzContext = $AzAuth.Context
		}
		catch {
			throw [System.Exception]::new('Failed to authenticate Azure with application ID, tenant ID, subscription ID', $PSItem.Exception)
		}
		Write-Output "Successfully authenticated with Azure using service principal: $($AzContext | Format-List -Force | Out-String)"

		# Set Azure context with subscription, tenant
		if ($AzContext.Tenant.Id -ine $ConnectionAsset.TenantId -or $AzContext.Subscription.Id -ine $ConnectionAsset.SubscriptionId) {
			if ($PSCmdlet.ShouldProcess((@($ConnectionAsset.TenantId, $ConnectionAsset.SubscriptionId) -join ', '), 'Set Azure context with tenant ID, subscription ID')) {
				try {
					$AzContext = Set-AzContext -TenantId $ConnectionAsset.TenantId -SubscriptionId $ConnectionAsset.SubscriptionId
					if (!$AzContext -or $AzContext.Tenant.Id -ine $ConnectionAsset.TenantId -or $AzContext.Subscription.Id -ine $ConnectionAsset.SubscriptionId) {
						throw $AzContext
					}
				}
				catch {
					throw [System.Exception]::new('Failed to set Azure context with tenant ID, subscription ID', $PSItem.Exception)
				}
				Write-Output "Successfully set the Azure context with the tenant ID, subscription ID: $($AzContext | Format-List -Force | Out-String)"
			}
		}
    
    $vms = Get-AzVM -ResourceGroup $AzureResourceGroup

    foreach ($AzureVM in $vms) 
        { 
            $vmstatus = Get-AzVM -Name $AzureVM.Name -Status 
            $powerstate = $vmstatus.PowerState
            $vmName = $vmstatus.Name

            Write-Output "Name: $vmName Status: $powerstate"

            if ($powerstate -eq "VM deallocated")
            {
                Write-Output "Name: $vmName will be changed to $AzureNewDiskSku"

                $disk = (get-azdisk | Where-Object {$_.ManagedBy -eq $AzureVM.id})
                $diskName = $disk.Name
                $skuName = $disk.sku.name
                Write-Output "Disk Name: $diskName SKU: $skuName"
            
                $disk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($AzureNewDiskSku)
                $disk | Update-AzDisk
            
                $disk = (get-azdisk | Where-Object {$_.ManagedBy -eq $AzureVM.id})
                $diskName = $disk.Name
                $skuName = $disk.sku.name
                
                Write-Output "Disk Name: $diskName New SKU: $skuName"
                Write-Output ""
            }
        }  
