<h1>Configure Azure Virtual Desktop Insights</h1>

Powershell script to configure the Azure Virtual Desktop Insights Dashboard 

Configures the diagnostic settings for the AVD workspace and the hostpool into log analytics. Adds the missing performance and event logs into the log analytics agents configuration.
Installs the Enterprise Cloud Monitoring agent onto the session hosts.

Uses the following parameters 

AADTenantId - Optional - Specifies the Azure AD tenant </br>
AzureSubscriptionId - Optional - Specifies the Azure Subscription </br>
Location - Region to deploy to </br>
LogAnalyticsResourceGroup - Location of the Log Analytics Workspace </br>
LogAnalyticsWorkspaceName - Name of the Log Analytics Workspace </br>
HostPoolName - Name of the Host Pool </br>
HostPoolResourceGroup - Location of the Hostpool </br>
WorkspaceName - Azure Virtual Desktop Workspace name
