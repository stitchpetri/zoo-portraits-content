# make-json.ps1
param(
  [string]$GitHubUser = "<YOUR_GH_USERNAME>",
  [string]$Repo = "zoo-portraits-content",
  [string]$Branch = "main"
)

$root = Split-Path -Parent $PSCommandPath
$photosDir = Join-Path $root "photos"
$dataDir   = Join-Path $root "data"
$newJson   = Join-Path $dataDir "portraits.json"

if (!(Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }

# Collect records
$items = New-Object System.Collections.Generic.List[Object]

# Helper: Capitalize species from slug ("texas-tortoise" -> "Texas Tortoise")
function Format-Species($slug) {
  $parts = $slug -split '-'
  ($parts | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ' '
}

Get-ChildItem -Path $photosDir -Directory | ForEach-Object {
  $folder = $_.FullName          # e.g. ...\photos\willa-donkey
  $slug   = $_.Name              # e.g. willa-donkey

  # Split slug → name/species when possible
  $namePart, $speciesPart = $null, $null
  $segments = $slug -split '-'
  if ($segments.Count -ge 2) {
    $namePart    = $segments[0]                 # "willa" or "unknown"
    $speciesPart = ($segments | Select-Object -Skip 1) -join '-'   # "donkey" or "llama", "texas-tortoise"
  } else {
    $namePart    = $slug
    $speciesPart = ""
  }

  $displayName = if ($namePart -eq 'unknown') { $null } else { $namePart.Substring(0,1).ToUpper() + $namePart.Substring(1) }
  $species     = if ($speciesPart) { Format-Species $speciesPart } else { "" }

  Get-ChildItem -Path $folder -File | Where-Object {
    $_.Extension -match '^\.(jpe?g|png|heic)$'
  } | ForEach-Object {
    $file = $_
    $basename = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    # Expect names like: slug-YYYY-MM-DD-###.ext
    $date = $null
    if ($basename -match '^\w[\w\-]*-(\d{4}-\d{2}-\d{2})-\d{3}$') {
      $date = $Matches[1]
    } else {
      $date = $file.CreationTime.ToString("yyyy-MM-dd")
    }

    $id = $basename          # stable id = filename w/o extension
    $rel = "photos/$slug/$($file.Name)"
    $rawUrl = "https://raw.githubusercontent.com/$GitHubUser/$Repo/$Branch/$rel"

    $record = [ordered]@{
      id       = $id
      slug     = $slug
      name     = $displayName       # null if unknown-<species>
      species  = $species
      tags     = @($speciesPart)    # quick starter tag; edit later if you want
      date     = $date
      image    = $rawUrl
      thumb    = $rawUrl            # start same as image; can swap later to /thumbs
      location = "Austin Zoo"
      credit   = "Amanda Roche"
    }
    $items.Add([pscustomobject]$record) | Out-Null
  }
}

# Sort newest first, then slug
$sorted = $items | Sort-Object -Property @{Expression="date";Descending=$true}, @{Expression="slug";Descending=$false}

# Write JSON (pretty)
$json = $sorted | ConvertTo-Json -Depth 5
# ConvertTo-Json adds \r\n and spacing; we keep as is for readability
Set-Content -Path $newJson -Value $json -Encoding UTF8

Write-Host "Wrote $($sorted.Count) records to $newJson"
