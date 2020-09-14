{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "vmName": {
            "type": "string"
        },
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Location for all resources."
            }
        }
    },
    "functions": [],
    "variables": {},
    "resources": [
        {
        
            "type": "Microsoft.Compute/virtualMachines/extensions",
        "apiVersion": "2019-12-01",
  "name": "[concat[(parameters ('vmName'),'/', 'InstallTeams')]",
  "location": "[parameters('location')]",
  "properties": {
      "publisher": "Microsoft.Compute",
      "type": "CustomScriptExtension",
      "typeHandlerVersion": "1.7",
      "autoUpgradeMinorVersion":true,
      "settings": {
        "fileUris": [
          "[uri(deployment().properties.templateLink.uri, concat('/TeamsInstall.ps1'))]"
        ],
        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File TeamsInstall.ps1"
      }
  }
}
    ],
    "outputs": {}
}
