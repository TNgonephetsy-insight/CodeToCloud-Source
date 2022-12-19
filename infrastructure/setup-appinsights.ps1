$studentsuffix = "trn"
$resourcegroupName = "fabmedical-rg-" + $studentsuffix
$location1 = "eastus"
$appInsights = "fabmedical-ai-" + $studentsuffix

az extension add --name application-insights
$ai = az monitor app-insights component create --app $appInsights --location $location1 --kind web -g $resourcegroupName --application-type web --retention-time 120 | ConvertFrom-Json

Write-Host "AI Instrumentation Key=$($ai.instrumentationKey)"
