[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]
    $Scope = "/subscriptions/00000000-0000-0000-0000-000000000000",
    [Parameter(Mandatory=$true)]
    [string]
    $VaultName = "kvcloudrulerinfrastructure",
    [Parameter(Mandatory=$true)]
    [string]
    $Location = "South Central US"
)
process {

    #Initialize the tenant
    $rg = New-AzResourceGroup -Name "rg-infrastructure" -Location $Location
    $keyVault = New-AzKeyVault -Name $VaultName -ResourceGroupName "rg-infrastructure" -Location $Location

    $app = New-AzADApplication -DisplayName "Azure Infrastructure Automation" -HomePage "https://app.terraform.io/" -IdentifierUris "https://app.terraform.io/"
    $servicePrincipal = New-AzADServicePrincipal -Role Contributor -Scope $Scope -DisplayName "Infrastructure Automation ARM Connector" -ApplicationObject $app
    $secret = Set-AzKeyVaultSecret -Name "infrastructure-automation-arm-connector-secret" -VaultName $VaultName -SecretValue $servicePrincipal.Secret

    Write-Host "Infrastructure Automation ARM Connector:"
    Write-Host "ObjectId: $($servicePrincipal.Id)"
    Write-Host "ApplicationId: $($servicePrincipal.ApplicationId)"
    Write-Host "Secret: $($secret.Name)"

}