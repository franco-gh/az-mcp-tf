# Azure Container Registry
resource "azurerm_container_registry" "mcp_acr" {
  name                = "mcpacr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.mcp_rg.name
  location            = azurerm_resource_group.mcp_rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Build Docker image and get digest
resource "null_resource" "docker_build" {
  triggers = {
    # Re-build the image if the source files change
    dockerfile  = filemd5("dockerfile")
    source_code = filemd5("mcp-sse-server.py")
  }

  provisioner "local-exec" {
    command = <<EOT
      az acr build --registry ${azurerm_container_registry.mcp_acr.name} --image terraform-mcp-server:latest .
      DIGEST=$(az acr repository show-manifests --name ${azurerm_container_registry.mcp_acr.name} --repository terraform-mcp-server --query "[0].digest" -o tsv)
      echo $DIGEST > image_digest.txt
    EOT
  }
}

# Read the image digest from the file
data "local_file" "image_digest" {
  filename   = "${path.module}/image_digest.txt"
  depends_on = [null_resource.docker_build]
}