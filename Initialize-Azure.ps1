#Install-Module AzureAD
#Import-Module
#Connect-AzureAD
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]
    $Scope = "/subscriptions/00000000-0000-0000-0000-000000000000",
    [Parameter(Mandatory=$false)]
    [string]
    $VaultName = "kvcloudrulerinfra",
    [Parameter(Mandatory=$false)]
    [string]
    $Location = "South Central US"
)
process {

    $rgName = "rg-infrastructure";
    #Initialize the tenant
    Write-Host "Creating Resource Group $rgName"
    New-AzResourceGroup -Name $rgName -Location $Location
    Write-Host "Creating Key Vault $VaultName"
    New-AzKeyVault -Name $VaultName -ResourceGroupName $rgName -Location $Location

    Write-Host "Looking up Enterprise Application"
    $app = Get-AzAdApplication -IdentifierUri "https://azureinfrastructureautomation.cloudruler.io/"
    if($null -eq $app) {
        Write-Host "Creating Enterprise Application"
        $app = New-AzADApplication -DisplayName "Azure Infrastructure Automation" -HomePage "https://azureinfrastructureautomation.cloudruler.io/" -IdentifierUris "https://azureinfrastructureautomation.cloudruler.io/"
    }
    Write-Host "Creating SPN"
    $servicePrincipal = New-AzADServicePrincipal -Role Contributor -Scope $Scope -ApplicationId $app.ApplicationId
    Write-Host "Creating Key Vault Secret"
    
    $secret = $servicePrincipal | New-AzADSpCredential
    $newSecretObj = Set-AzKeyVaultSecret -Name "infrastructure-automation-arm-connector-secret" -VaultName $VaultName -SecretValue $secret.Secret

    Write-Host "Infrastructure Automation ARM Connector:"
    Write-Host "ObjectId: $($servicePrincipal.Id)"
    Write-Host "ApplicationId: $($servicePrincipal.ApplicationId)"
    Write-Host "Secret: $($newSecretObj.Name)"

}


# Get the service principal for Microsoft Graph.
# First result should be AppId 00000003-0000-0000-c000-000000000000
$GraphServicePrincipal = Get-AzADServicePrincipal -DisplayName "Microsoft Graph" | Select-Object -First 1

# Assign permissions to the managed identity service principal.
$AppRole = $GraphServicePrincipal.AppRoles |
Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}

New-AzureAdServiceAppRoleAssignment -ObjectId $spID -PrincipalId $spID `
-ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id