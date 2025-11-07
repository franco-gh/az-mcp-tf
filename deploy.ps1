# PowerShell deployment script for Azure MCP Server with Key Vault
$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying Terraform MCP Server to Azure..." -ForegroundColor Green

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

try {
    $null = terraform version
} catch {
    Write-Host "❌ Terraform is required. Download from: https://www.terraform.io/downloads" -ForegroundColor Red
    exit 1
}

try {
    $null = az version
} catch {
    Write-Host "❌ Azure CLI is required. Download from: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

# Check for required files
if (-not (Test-Path "mcp-sse-server.py")) {
    Write-Host "❌ Error: mcp-sse-server.py not found!" -ForegroundColor Red
    Write-Host "   Please ensure you have renamed mcp-http-wrapper.py to mcp-sse-server.py" -ForegroundColor Yellow
    exit 1
}

# Step 1: Clean up any soft-deleted Key Vaults
Write-Host "`n🔐 Checking for soft-deleted Key Vaults..." -ForegroundColor Yellow
$deletedVaults = az keyvault list-deleted --query "[?contains(name, 'mcp-kv')].[name]" -o tsv 2>$null

if ($deletedVaults) {
    foreach ($vault in $deletedVaults) {
        Write-Host "  Purging deleted vault: $vault" -ForegroundColor Gray
        az keyvault purge --name $vault --no-wait
    }
    Write-Host "  Waiting 30 seconds for purge to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
}

# Step 2: Deploy infrastructure with Terraform
Write-Host "`n📦 Deploying Azure infrastructure with Terraform..." -ForegroundColor Green
terraform init
terraform apply -auto-approve

# Step 3: Get outputs
Write-Host "`n📊 Getting deployment outputs..." -ForegroundColor Yellow
$MCP_SERVER_URL = terraform output -raw mcp_server_url
$API_KEY = terraform output -raw api_key
$KEY_VAULT_NAME = terraform output -raw key_vault_name
$ACR_NAME = terraform output -raw acr_name
$ACR_LOGIN_SERVER = terraform output -raw acr_login_server

# Step 4: Build and push Docker image
Write-Host "`n🏗️ Building image using Azure Container Registry..." -ForegroundColor Green
az acr build `
    --registry $ACR_NAME `
    --image "terraform-mcp-server:latest" `
    --file Dockerfile `
    .

# Step 5: Update Container App with custom image
Write-Host "`n🔄 Updating Container App with custom image..." -ForegroundColor Green
az containerapp update `
  --name terraform-mcp-server `
  --resource-group terraform-mcp-rg `
  --image "${ACR_LOGIN_SERVER}/terraform-mcp-server:latest"

# Step 6: Create VS Code configuration
Write-Host "`n⚙️ Creating VS Code configuration..." -ForegroundColor Green

if (!(Test-Path ".vscode")) {
    New-Item -ItemType Directory -Path ".vscode" | Out-Null
}

$mcpConfig = @{
    servers = @{
        terraform = @{
            type = "sse"
            url = "${MCP_SERVER_URL}/mcp/v1/sse"
            headers = @{
                "Authorization" = "Bearer $API_KEY"
            }
        }
    }
}

$mcpConfig | ConvertTo-Json -Depth 10 | Set-Content -Path ".vscode\mcp.json" -Encoding UTF8

# Display results
Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 MCP Server URL: $MCP_SERVER_URL" -ForegroundColor Cyan
Write-Host "🔑 API Key: $API_KEY" -ForegroundColor Cyan
Write-Host "🔐 Key Vault: $KEY_VAULT_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 VS Code configuration created in .vscode\mcp.json" -ForegroundColor Yellow
Write-Host ""
Write-Host "🚀 To use in VS Code:" -ForegroundColor Yellow
Write-Host "   1. Open GitHub Copilot Chat (Ctrl+Alt+I)" -ForegroundColor White
Write-Host "   2. Select 'Agent' mode" -ForegroundColor White
Write-Host "   3. The Terraform tools will be available!" -ForegroundColor White
