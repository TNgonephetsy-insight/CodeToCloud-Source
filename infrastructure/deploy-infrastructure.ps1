param
(
    [string] $studentprefix = "trn"
)

$resourcegroupName = "fabmedical-rg-" + $studentprefix
$cosmosDBName = "fabmedical-cdb-" + $studentprefix
$webappName = "fabmedical-web-" + $studentprefix
$planName = "fabmedical-plan-" + $studentprefix
$location1 = "eastus"
$location2 = "westus3"
$appInsights = "fabmedical-ai-" + $studentprefix
$ghcrUser = "tngonephetsy-insight"

#create Resource Group
$rg = az group create --name $resourcegroupName --location $location1 | ConvertFrom-Json 

#create CosmosDB
az cosmosdb create --name $cosmosDBName `
--resource-group $resourcegroupName `
--locations regionName=$location1 failoverPriority=0 isZoneRedundant=False `
--locations regionName=$location2 failoverPriority=1 isZoneRedundant=True `
--enable-multiple-write-locations `
--kind MongoDB `
--server-version 4.0

#setup MongoDB connection string (Thanks to ADunn)
$cdbConnectionString = az cosmosdb keys list -n $cosmosDBName -g $resourceGroupName --type connection-strings `
     --query "connectionStrings[?description=='Primary MongoDB Connection String'].connectionString"
$manipulate = $cdbConnectionString[1]
$manipulate = $manipulate.Split("""")[1]
$manipulate = $manipulate.Split("?")
$cdbConnection = $manipulate[0] + "contentdb?" + $manipulate[1]

#create Azure App Service Plan
az appservice plan create --name $planName --resource-group $resourcegroupName --sku S1 --is-linux

#Azure webapp configurations
az webapp config appsettings set --settings MONGODB_CONNECTION="$cdbConnection" --name $($webappName) --resource-group $($resourcegroupName)
az webapp config appsettings set --settings DOCKER_REGISTRY_SERVER_URL="https://ghcr.io" --name $($webappName) --resource-group $($resourcegroupName) 
az webapp config appsettings set --settings DOCKER_REGISTRY_SERVER_USERNAME="notapplicable" --name $($webappName) --resource-group $($resourcegroupName) 
az webapp config appsettings set --settings DOCKER_REGISTRY_SERVER_PASSWORD="$($env:CR_PAT)" --name $($webappName) --resource-group $($resourcegroupName) 

#create Azure WebApp with NGINX container
az webapp create `
--multicontainer-config-file docker-compose.yml `
--multicontainer-config-type COMPOSE `
--name $($webappName) `
--resource-group $($resourcegroupName) `
--plan $($planName)

#configure Azure WebApp container & private ghcr repository
az webapp config container set `
--docker-registry-server-url https://ghcr.io `
--docker-registry-server-user notapplicable `
--docker-registry-server-password $($env:CR_PAT) `
--multicontainer-config-type COMPOSE `
--name $webappName `
--resource-group $resourcegroupName `
--enable-app-service-storage true

#add AZ Application insight
az extension add --name application-insights
az monitor app-insights component create --app $appInsights --location $location1 --kind web -g $resourcegroupName --application-type web --retention-time 120
