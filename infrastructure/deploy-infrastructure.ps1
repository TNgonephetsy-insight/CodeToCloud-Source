$studentprefix = "trn"
$resourcegroupName = "fabmedical-rg-" + $studentprefix
$cosmosDBName = "fabmedical-cdb-" + $studentprefix
$webappName = "fabmedical-web-" + $studentprefix
$planName = "fabmedical-plan-" + $studentprefix
$location1 = "eastus"
$location2 = "centralus"
$ghcrUser = "tngonephetsy-insight"

az group create -l $location1 -n $resourcegroupName

#Then create a CosmosDB
az cosmosdb create --name $cosmosDBName `
--resource-group $resourcegroupName `
--locations regionName=$location1 failoverPriority=0 isZoneRedundant=False `
--locations regionName=$location2 failoverPriority=1 isZoneRedundant=True `
--enable-multiple-write-locations `
--kind MongoDB `
--server-version 4.0

#Create a Azure App Service Plan
az appservice plan create --name $planName --resource-group $resourcegroupName --sku S1 --is-linux

#Create a Azure Web App with NGINX container
az webapp create --resource-group $resourcegroupName --plan $planName --name $webappName -i nginx

$cdbConnectionString = "$(az cosmosdb keys list -n $cosmosDBName -g $resourceGroupName --type connection-strings --query "connectionStrings[?description=='Primary MongoDB Connection String'].connectionString" | tr -d '\n',' ','[',']','\"' | sed s/\?/contentdb\?/)"

#add 'MONGODB_CONNECTION' to web application setting
az webapp config appsettings set -n $webappName -g $resourcegroupName --settings MONGODB_CONNECTION="$cdbConnectionString"

#container & private ghcr settings
az webapp config container set `
--docker-registry-server-password $CR_PAT `
--docker-registry-server-url https://ghcr.io `
--docker-registry-server-user notapplicable `
--multicontainer-config-file ../docker-compose.yml `
--multicontainer-config-type COMPOSE `
--name $webappName `
--resource-group $resourcegroupName `
--enable-app-service-storage true

#MongoDB init step
#run init container from ghcr to fill cosmos DB
docker run -ti --rm -e MONGODB_CONNECTION="$cdbConnectionString" ghcr.io/$ghcrUser/fabrikam-init