<#
.SYNOPSIS
    Sincronizador oficial de cards do Trello para o projeto Monetis.
.DESCRIPTION
    Le com seguranca o arquivo .env e o cards-definition.json em UTF-8 estrito
    e cadastra os cards formatados com checklists no Trello.
.PARAMETER Phase
    Fase especifica para criar os cards: 'Fase 0', 'Fase 1', 'Fase 2', 'Fase 3', 'Fase 4' ou 'All'.
.PARAMETER TargetList
    Nome da lista alvo ('Backlog', 'A Fazer', etc.). Padrao: 'A Fazer' para Fase 0 e 'Backlog' para as demais.
#>
[CmdletBinding()]
param(
    [ValidateSet('Fase 0', 'Fase 1', 'Fase 2', 'Fase 3', 'Fase 4', 'All')]
    [string]$Phase = 'All',

    [string]$TargetList = '',

    [string]$DefinitionFile = 'cards-definition.json'
)

$ErrorActionPreference = 'Stop'

# 1. Carregar variaveis do .env de forma segura
$envPath = Join-Path $PSScriptRoot "..\.env"
if (-not (Test-Path $envPath)) {
    Write-Error "Arquivo .env nao encontrado na raiz do projeto. Defina TRELLO_KEY e TRELLO_TOKEN."
    exit 1
}

$trelloKey = ""
$trelloToken = ""
foreach ($line in [System.IO.File]::ReadAllLines($envPath, [System.Text.Encoding]::UTF8)) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith("#") -or [string]::IsNullOrWhiteSpace($trimmed)) { continue }
    $parts = $trimmed.Split('=', 2)
    if ($parts.Length -eq 2) {
        if ($parts[0].Trim() -eq "TRELLO_KEY") { $trelloKey = $parts[1].Trim().Trim('"').Trim("'") }
        if ($parts[0].Trim() -eq "TRELLO_TOKEN") { $trelloToken = $parts[1].Trim().Trim('"').Trim("'") }
    }
}

if ([string]::IsNullOrWhiteSpace($trelloKey) -or [string]::IsNullOrWhiteSpace($trelloToken)) {
    Write-Error "TRELLO_KEY ou TRELLO_TOKEN nao encontrados no .env."
    exit 1
}

# 2. Configuracoes do Quadro Monetis
$boardId = "69c43cb8ed9266858bde2654"
$listIds = @{
    "Backlog"           = "69c43cb8ed9266858bde264d"
    "A Fazer"           = "69c43cb8ed9266858bde264f"
    "Em andamento"      = "69c43cb8ed9266858bde2650"
    "Revisao de codigo" = "69c43cb8ed9266858bde2651"
    "Fase de teste"     = "69c43cb8ed9266858bde2652"
    "Concluido"         = "69c43cb8ed9266858bde2653"
}

function Invoke-TrelloApi {
    param(
        [string]$Endpoint,
        [string]$Method = "Get",
        [object]$Payload = $null
    )
    $separator = if ($Endpoint.Contains("?")) { "&" } else { "?" }
    $url = "https://api.trello.com/1/$Endpoint$($separator)key=$trelloKey&token=$trelloToken"

    if ($Payload -ne $null) {
        $json = $Payload | ConvertTo-Json -Compress -Depth 5
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Uri $url -Method $Method -ContentType "application/json; charset=utf-8" -Body $bytes
    } else {
        return Invoke-RestMethod -Uri $url -Method $Method
    }
}

function Add-TrelloCard {
    param(
        [string]$ListId,
        [string]$Title,
        [string]$Description,
        [object[]]$ChecklistItems = @()
    )

    $cardPayload = @{
        idList = $ListId
        name = $Title
        desc = $Description
    }

    $card = Invoke-TrelloApi -Endpoint "cards" -Method Post -Payload $cardPayload

    if ($ChecklistItems.Count -gt 0) {
        $checklistPayload = @{
            idCard = $card.id
            name = "Criterios de Aceite"
        }
        $checklist = Invoke-TrelloApi -Endpoint "checklists" -Method Post -Payload $checklistPayload

        foreach ($item in $ChecklistItems) {
            $checkItemPayload = @{
                name = [string]$item
            }
            Invoke-TrelloApi -Endpoint "checklists/$($checklist.id)/checkItems" -Method Post -Payload $checkItemPayload | Out-Null
        }
    }

    Write-Host "Card criado: $Title -> $($card.shortUrl)"
    return $card
}

# 3. Carregar definicoes de cards do arquivo JSON
$jsonPath = Join-Path $PSScriptRoot $DefinitionFile
if (-not (Test-Path $jsonPath)) {
    Write-Error "Arquivo $DefinitionFile nao encontrado em $jsonPath."
    exit 1
}

$jsonText = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8)
$cardsDef = $jsonText | ConvertFrom-Json

$filtered = $cardsDef | Where-Object { $Phase -eq 'All' -or $_.Phase -eq $Phase }

Write-Host "Total de cards selecionados: $($filtered.Count)"

foreach ($item in $filtered) {
    $targetListFinal = if (-not [string]::IsNullOrWhiteSpace($TargetList)) {
        $TargetList
    } else {
        $item.DefaultList
    }

    $matchedListId = $null
    if ($listIds.ContainsKey($targetListFinal)) {
        $matchedListId = $listIds[$targetListFinal]
    } else {
        $matchedListId = $listIds["Backlog"]
    }

    Add-TrelloCard -ListId $matchedListId -Title $item.Title -Description $item.Description -ChecklistItems $item.Checklist
}

Write-Host "`nSincronizacao com o Trello concluida com sucesso!"
