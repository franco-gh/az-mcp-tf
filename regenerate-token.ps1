# PowerShell script to regenerate API token for deployed MCP Server
$ErrorActionPreference = "Stop"

Write-Host "🔄 Regenerating API Token for Terraform MCP Server..." -ForegroundColor Green

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

try {
    $null = az version
} catch {
    Write-Host "❌ Azure CLI is required. Download from: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

# Configuration
$RESOURCE_GROUP = "terraform-mcp-rg"
$CONTAINER_APP_NAME = "terraform-mcp-server"

Write-Host "`n🔍 Getting deployment information..." -ForegroundColor Yellow

# Get Container App details
$containerAppJson = az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Container App not found. Please ensure the deployment exists." -ForegroundColor Red
    Write-Host "   Expected: $CONTAINER_APP_NAME in resource group $RESOURCE_GROUP" -ForegroundColor Yellow
    exit 1
}

$containerApp = $containerAppJson | ConvertFrom-Json
$MCP_SERVER_URL = "https://$($containerApp.properties.configuration.ingress.fqdn)"

# Get Key Vault name from tags or find it in the resource group
Write-Host "🔐 Finding Key Vault..." -ForegroundColor Yellow
$keyVaultJson = az keyvault list --resource-group $RESOURCE_GROUP --query "[?contains(name, 'mcp-kv')].[name]" -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($keyVaultJson)) {
    Write-Host "❌ Key Vault not found in resource group $RESOURCE_GROUP" -ForegroundColor Red
    exit 1
}

$KEY_VAULT_NAME = $keyVaultJson.Trim()
Write-Host "   Found Key Vault: $KEY_VAULT_NAME" -ForegroundColor Gray

# Generate new API key (32 characters, alphanumeric with - and _)
Write-Host "`n🔑 Generating new API key..." -ForegroundColor Yellow
$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
$NEW_API_KEY = -join ((1..32) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
Write-Host "   New API key generated" -ForegroundColor Gray

# Update Key Vault secret
Write-Host "`n🔐 Updating Key Vault secret..." -ForegroundColor Yellow
try {
    az keyvault secret set --vault-name $KEY_VAULT_NAME --name "mcp-api-key" --value $NEW_API_KEY --output none
    Write-Host "   Key Vault secret updated" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to update Key Vault secret. Check your permissions." -ForegroundColor Red
    Write-Host "   You need 'Key Vault Secrets Officer' or 'Key Vault Administrator' role" -ForegroundColor Yellow
    exit 1
}

# Update Container App secret
Write-Host "`n🔄 Updating Container App secret..." -ForegroundColor Yellow
try {
    az containerapp secret set `
        --name $CONTAINER_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --secrets "api-key=$NEW_API_KEY" `
        --output none
    Write-Host "   Container App secret updated" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to update Container App secret" -ForegroundColor Red
    exit 1
}

# Restart Container App to pick up new secret
Write-Host "`n♻️  Restarting Container App..." -ForegroundColor Yellow
try {
    # Get the current revision name
    $revisionName = az containerapp revision list `
        --name $CONTAINER_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --query "[0].name" -o tsv

    # Restart by deactivating and reactivating
    az containerapp revision restart `
        --name $CONTAINER_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --revision $revisionName `
        --output none 2>$null

    Write-Host "   Container App restarted" -ForegroundColor Gray
    Write-Host "   Waiting for restart to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
} catch {
    Write-Host "⚠️  Warning: Could not restart Container App automatically" -ForegroundColor Yellow
    Write-Host "   The new token will be used after the next container restart" -ForegroundColor Yellow
}

# Update VS Code configuration
Write-Host "`n⚙️  Updating VS Code configuration..." -ForegroundColor Yellow

if (!(Test-Path ".vscode")) {
    New-Item -ItemType Directory -Path ".vscode" | Out-Null
}

$mcpConfig = @{
    servers = @{
        terraform = @{
            type = "sse"
            url = "${MCP_SERVER_URL}/mcp/v1/sse"
            headers = @{
                "Authorization" = "Bearer $NEW_API_KEY"
            }
        }
    }
}

$mcpConfig | ConvertTo-Json -Depth 10 | Set-Content -Path ".vscode\mcp.json" -Encoding UTF8
Write-Host "   VS Code configuration updated" -ForegroundColor Gray

# Display results
Write-Host "`n✅ API Token regeneration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 MCP Server URL: $MCP_SERVER_URL" -ForegroundColor Cyan
Write-Host "🔑 New API Key: $NEW_API_KEY" -ForegroundColor Cyan
Write-Host "🔐 Key Vault: $KEY_VAULT_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 VS Code configuration updated in .vscode\mcp.json" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  Important:" -ForegroundColor Yellow
Write-Host "   - All existing tokens are now invalid" -ForegroundColor White
Write-Host "   - Share the new token with users who need access" -ForegroundColor White
Write-Host "   - Restart VS Code to use the new token" -ForegroundColor White
