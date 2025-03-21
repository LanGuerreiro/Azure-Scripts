param (
    [switch]$create,
    [switch]$list,
    [switch]$listLocation,
    [switch]$destroy,
    [switch]$help,
    [string]$resourceGroupName,
    [string]$location,
    [string]$subscriptionId,
    [string]$tenantId,
    [string[]]$tags
)

function Show-Help {
    Write-Output "Azure Resource Group Manager"
    Write-Output ""
    Write-Output "Usage:"
    Write-Output "  .\managerResourceGroup.ps1 -<action> [parameters]"
    Write-Output ""
    Write-Output "Actions:"
    Write-Output "  -create             Create a new Resource Group."
    Write-Output "  -list               List existing Resource Groups (optional: filter by location)."
    Write-Output "  -listLocation       Show available Azure regions."
    Write-Output "  -destroy            Delete a specific Resource Group."
    Write-Output "  -help               Show this help message."
    Write-Output ""
    Write-Output "Parameters:"
    Write-Output "  -resourceGroupName  Name of the Resource Group (required for -create and -destroy)."
    Write-Output "  -location           Azure region (required for -create, optional for -list)."
    Write-Output "  -subscriptionId     Azure Subscription ID (only if not already authenticated)."
    Write-Output "  -tenantId           Azure Tenant ID (only if not already authenticated)."
    Write-Output ""
    Write-Output "Examples:"
    Write-Output "  Create a Resource Group:"
    Write-Output "    .\managerResourceGroup.ps1 -create -resourceGroupName 'DevRG' -location 'eastus'"
    Write-Output ""
    Write-Output "  List all Resource Groups:"
    Write-Output "    .\managerResourceGroup.ps1 -list"
    Write-Output ""
    Write-Output "  List Resource Groups in a specific location:"
    Write-Output "    .\managerResourceGroup.ps1 -list -location 'westeurope'"
    Write-Output ""
    Write-Output "  Show available Azure locations:"
    Write-Output "    .\managerResourceGroup.ps1 -listLocation"
    Write-Output ""
    Write-Output "  Delete a Resource Group:"
    Write-Output "    .\managerResourceGroup.ps1 -destroy -resourceGroupName 'DevRG'"
    Write-Output ""
    exit 0
}

function Ensure-AzLogin {
    $context = Get-AzContext
    if (-not $context) {
        Write-Output "You are not authenticated in Azure. Logging in..."

        if (-not $tenantId) {
            $tenantId = Read-Host "Enter the Azure Tenant ID"
        }
        if (-not $subscriptionId) {
            $subscriptionId = Read-Host "Enter the Azure Subscription ID"
        }

        Connect-AzAccount -TenantId $tenantId -SubscriptionId $subscriptionId | Out-Null
        $context = Get-AzContext

        if (-not $context) {
            Write-Host "Authentication failed. Please check your credentials and try again." -ForegroundColor Red
            exit 1
        }
        Write-Output "Successfully authenticated in Azure."
    }
}

function Show-Locations {
    Write-Output "Fetching available Azure regions..."
    Get-AzLocation | Sort-Object GeographyGroup | Format-Table DisplayName, Location, Type, Longitude, Latitude, PhysicalLocation , RegionType, RegionCategory, GeographyGroup, PairedRegion -AutoSize
}

# Se nenhum parâmetro for passado, exibir o help
if (-not ($create -or $list -or $listLocation -or $destroy -or $help)) {
    Show-Help
}

# Se o usuário solicitou ajuda, exibir e sair
if ($help) {
    Show-Help
}

# Garantir autenticação antes de qualquer ação
Ensure-AzLogin

# Listar Localizações (Regiões Azure)
if ($listLocation) {
    Show-Locations
    exit 0
}

# Listar Resource Groups (sem filtro de tags)
if ($list) {
    Write-Output "Listing existing Resource Groups..."
    $resourceGroups = Get-AzResourceGroup

    if ($location) {
        $resourceGroups = $resourceGroups | Where-Object { $_.Location -eq $location }
    }

    if ($resourceGroups) {
        $resourceGroups | ForEach-Object {
            [PSCustomObject]@{
                Name               = $_.ResourceGroupName
                Location           = $_.Location
                ResourceId         = $_.ResourceId
                ProvisioningState  = $_.ProvisioningState
                Tags               = if ($_.Tags) {
                    ($_.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "
                } else {
                    "None"
                }
            }
        } | Format-Table -AutoSize
    } else {
        Write-Output "No matching Resource Groups found."
    }
    exit 0
}

# Criar Resource Group
if ($create) {
    if (-not $resourceGroupName) {
        $resourceGroupName = Read-Host "Enter the name of the Resource Group"
    }

    if (-not $location) {
        Show-Locations
        $location = Read-Host "Enter the Azure region from the list above (copy the exact location name)"
    }

    Write-Output "Creating Resource Group '$resourceGroupName' in the location '$location'..."

    if ($tags) {
        $tagHash = @{}
        foreach ($tag in $tags) {
            if ($tag -match "^(.*?)=(.*)$") {
                $tagHash[$matches[1]] = $matches[2]
            }
        }
        New-AzResourceGroup -Name $resourceGroupName -Location $location -Tag $tagHash
    } else {
        New-AzResourceGroup -Name $resourceGroupName -Location $location
    }

    exit 0
}

# Deletar Resource Group
if ($destroy) {
    if (-not $resourceGroupName) {
        Write-Host "Enter the name of the Resource Group to delete" -ForegroundColor Red    
        $resourceGroupName = Read-Host "Resource Group Name"
    }

    Write-Host "Are you sure you want to delete the Resource Group '$resourceGroupName'? Type 'YES' to confirm" -ForegroundColor Red
    $confirmation = Read-Host "Please confirm" 
    
    if ($confirmation -eq "YES") {
        Write-Host "Deleting Resource Group '$resourceGroupName'..." -ForegroundColor Red
        Remove-AzResourceGroup -Name $resourceGroupName -Force
        Write-Output "Resource Group '$resourceGroupName' has been successfully deleted."
    } else {
        Write-Output "Deletion cancelled."
    }

    exit 0
}
