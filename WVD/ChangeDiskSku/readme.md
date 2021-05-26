<h1>Change Managed Disk SKU for Deallocated VMs</h1>

Automation Runbook for changing the disk type. Copy contents of ChangeDiskSku.ps1 into new PowerShell runbook. 

Create a schedule for changing the sku when machines are deallocated (typically in the evening) and then another just before machines come back on for peak times.

Uses two parameters at the moment. 

AzureResourceGroup - Used to tell the runbook which Resource Group the machines are located to target.
AzureNewDiskSku - Tells the runbook what SKU to use. 

For best saving use Standard_LRS (Standard HDD) for the first schedule and then preferred disk type Premium_LRS (Premium SSD) or StandardSSD_LRS (Standard SSD) for the second.
