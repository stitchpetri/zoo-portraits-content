cd "C:\Users\yello\Desktop\zoo-portaits-content\photos"

Add-Type -AssemblyName System.Drawing

# ---- settings ---------------------------------------------------------------
# Set to $true to preview without changing anything
$DRYRUN = $false

# Already-processed names: folder-slug-YYYY-MM-DD-###.ext
$pattern = '^[a-z0-9\-]+-\d{4}-\d{2}-\d{2}-\d{3}\.(jpg|jpeg|png|heic)$'
# ---------------------------------------------------------------------------

$grandRenamed = 0
$grandSkipped = 0

Get-ChildItem -Directory | ForEach-Object {
    $folder     = $_.FullName
    $folderName = $_.Name
    Write-Host "Processing folder: $folderName" -ForegroundColor Yellow

    $counters = @{}           # per-date counter for this folder
    $renamed  = 0
    $skipped  = 0

    $files = Get-ChildItem -Path $folder -File
    foreach ($f in $files) {

        # Skip if already formatted
        if ($f.Name -match $pattern) {
            Write-Host "  SKIP  $($f.Name)" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        # Pick date (EXIF for JPG/JPEG; else file time)
        $dt = $null
        if ($f.Extension -match '^\.(jpe?g)$') {
            try {
                $img  = [System.Drawing.Image]::FromFile($f.FullName)
                $prop = $img.PropertyItems | Where-Object { $_.Id -eq 0x9003 } # DateTimeOriginal
                if ($prop) {
                    $raw = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0)
                    $dt  = [datetime]::ParseExact($raw, "yyyy:MM:dd HH:mm:ss", $null)
                }
                $img.Dispose()
            } catch { }
        }
        if (-not $dt) { $dt = $f.CreationTime }

        $dateStr = $dt.ToString("yyyy-MM-dd")

        if (-not $counters.ContainsKey($dateStr)) { $counters[$dateStr] = 1 }
        else { $counters[$dateStr]++ }

        $count = "{0:D3}" -f $counters[$dateStr]  # 001, 002, ...

        $baseNew = "{0}-{1}-{2}" -f $folderName, $dateStr, $count
        $ext     = $f.Extension.ToLower()
        $newName = "$baseNew$ext"

        # Collision safety: if somehow exists, append -dupN
        $candidate = $newName
        $dup = 1
        while (Test-Path -LiteralPath (Join-Path $folder $candidate)) {
            $candidate = "{0}-dup{1}{2}" -f $baseNew, $dup, $ext
            $dup++
        }

        if ($DRYRUN) {
            Write-Host ("  PREVIEW  {0} -> {1}" -f $f.Name, $candidate) -ForegroundColor Cyan
            $renamed++  # counts as would-rename
        } else {
            Rename-Item -LiteralPath $f.FullName -NewName $candidate
            Write-Host ("  RENAMED  {0} -> {1}" -f $f.Name, $candidate) -ForegroundColor Green
            $renamed++
        }
    }

    $grandRenamed += $renamed
    $grandSkipped += $skipped
    Write-Host ("Folder summary [{0}]: {1} renamed, {2} skipped" -f $folderName, $renamed, $skipped) -ForegroundColor Magenta
    Write-Host ""
}

Write-Host ("TOTAL: {0} renamed, {1} skipped" -f $grandRenamed, $grandSkipped) -ForegroundColor White
