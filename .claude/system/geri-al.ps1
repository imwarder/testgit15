param([string]$Version = "")

$ErrorActionPreference = "SilentlyContinue"

function Update-RollbackNote($commitHash) {
    $currentTime = Get-Date -Format "yyyyMMddHHmmss"

    # Mevcut note'u oku
    $existingNote = git notes show $commitHash 2>$null

    $count = 1
    $firstTime = $currentTime

    if ($existingNote -match "rollback:(\d+):(\d{14}):(\d{14})") {
        # Mevcut note var - güncelle
        $count = [int]$matches[1] + 1
        $firstTime = $matches[2]
    }

    # Yeni note oluştur
    $newNote = "rollback:${count}:${firstTime}:${currentTime}"
    git notes add -f -m $newNote $commitHash 2>$null

    return "$count kez"
}

# Claude Project Directory kullan
if ($env:CLAUDE_PROJECT_DIR) {
    $projectRoot = $env:CLAUDE_PROJECT_DIR
} else {
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

Set-Location $projectRoot

# Help veya bos parametre
if ($Version -eq "" -or $Version -eq "help") {
    Write-Output "Kullanim: /geri-al v250915180452"
    Write-Output "Liste: /geri-al-list"
    exit 0
}

# List komutu artık ayrı komutta
if ($Version -eq "list") {
    Write-Output "Liste icin /geri-al-list kullanin"
    exit 0
}

# Versiyon numarasi ile geri donme
if ($Version -match '^v?\d+$') {
    $versionNumber = $Version -replace '^v', ''
    $commits = git log --oneline --all
    $targetCommit = $null

    foreach ($commit in $commits) {
        if ($commit -match "v$versionNumber(\s|$)") {
            $targetCommit = $commit.Split(' ')[0]
            Write-Output "Commit bulundu: $targetCommit"
            break
        }
    }

    if (-not $targetCommit) {
        Write-Output "HATA: $Version versiyonu bulunamadi!"
        Write-Output "Liste: /geri-al-list"
        exit 1
    }

    Write-Output "Versiyon bulundu: $targetCommit"

    # Otomatik geri alma
    $backupBranch = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git branch $backupBranch 2>$null
    git reset --hard $targetCommit 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Output "BASARILI! $Version versiyonuna geri donuldu!"
        Write-Output "Backup: $backupBranch"

        # Git Notes güncelleme
        $rollbackInfo = Update-RollbackNote $targetCommit
        Write-Output "Geri alma kaydedildi: $rollbackInfo"

        # GitHub'a force push
        $pushResult = git push --force origin main 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "GitHub guncellendi!"
        } else {
            Write-Output "GitHub guncellenemedi"
        }

        # Notes'ları da push et
        git push origin refs/notes/* 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Geri alma bilgisi senkronize edildi!"
        }
    } else {
        Write-Output "HATA: Geri alma basarisiz!"
    }
} else {
    Write-Output "HATA: Gecersiz format!"
    Write-Output "Ornek: /geri-al v250915180452"
}