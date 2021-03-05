#Initialize the tenant

New-AzADApplication -DisplayName "Terraform Cloud ARM Connector" -HomePage "https://app.terraform.io/" -IdentifierUris "https://app.terraform.io/"

#New-AzADServicePrincipal -Role Contributor -Scope /subscriptions/$subscriptionId -DisplayName ""

Secret                : System.Security.SecureString
ServicePrincipalNames : {00000000-0000-0000-0000-000000000000, http://azure-powershell-05-22-2018-18-23-43}
ApplicationId         : 00000000-0000-0000-0000-000000000000
DisplayName           : azure-powershell-05-22-2018-18-23-43
Id                    : 00000000-0000-0000-0000-000000000000
Type                  : ServicePrincipal


az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID"
Creating a role assignment under the scope of "/subscriptions/SUBSCRIPTION_ID"
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "azure-cli-2017-06-05-10-41-15",
  "name": "http://azure-cli-2017-06-05-10-41-15",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}

param(
    [Parameter(Mandatory=$true)]
    [string]
    $Scope = "/subscriptions/00000000-0000-0000-0000-000000000000"
)
process {

    az appconfig kv delete -n $AppConfigResourceName --key "*" --label "*" --yes

    #az appconfig kv export -n $AppConfigResourceName -d file  --path "./$Label.yml" --format yaml --label $Label --prefix $Prefix --separator '/' -y

    #az appconfig kv import -n $AppConfigResourceName -s file  --path "./$Label.yml" --format yaml --label $Label --prefix $Prefix --separator '/' -y

}