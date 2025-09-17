# Working Stop Hook - Basit ve Etkili
# Orijinal çalışan versiyona dönüş + basit loop önleme

param(
    [string]$Message = "Session tamamlandi",
    [string]$HookType = "Stop"
)

$ErrorActionPreference = "SilentlyContinue"

# Çifte sonsuz döngü önleme - dosya + process tabanlı
$lockFile = Join-Path $env:TEMP "claude-stop-$(Get-Date -Format 'yyyyMMddHH').lock"
$processFile = Join-Path $env:TEMP "claude-stop-processes.txt"
$currentTime = Get-Date
$currentPID = $PID

# Process kontrolü - aynı anda çalışan hook'ları tespit et
$runningProcesses = @()
if (Test-Path $processFile) {
    try {
        $runningProcesses = Get-Content $processFile | Where-Object { $_ -and $_.Trim() }
    } catch {}
}

# Eğer zaten 2 veya daha fazla process çalışıyorsa sonsuz döngü
if ($runningProcesses.Count -ge 2) {
    exit 0
}

# Mevcut process'i listeye ekle
$runningProcesses += $currentPID
$runningProcesses | Out-File $processFile -Force

# Lock dosyası kontrolü
if (Test-Path $lockFile) {
    $lockTime = (Get-Item $lockFile).LastWriteTime
    $timeDiff = ($currentTime - $lockTime).TotalSeconds

    if ($timeDiff -lt 10) {
        # Process dosyasını temizle ve çık
        Remove-Item $processFile -Force -ErrorAction SilentlyContinue
        exit 0
    }
}

# Lock dosyası oluştur/güncelle
$currentTime.ToString() | Out-File $lockFile -Force

# Proje kökünü bul
function Find-ProjectRoot {
    $currentPath = (Get-Location).Path
    $maxDepth = 10
    $depth = 0
    
    while ($depth -lt $maxDepth) {
        $gitPath = Join-Path $currentPath ".git"
        if (Test-Path $gitPath) {
            return $currentPath
        }
        
        $configPath = Join-Path $currentPath "git-config.json"
        if (Test-Path $configPath) {
            return $currentPath
        }
        
        $parent = Split-Path $currentPath -Parent
        if (-not $parent -or $parent -eq $currentPath) {
            break
        }
        $currentPath = $parent
        $depth++
    }
    
    return (Get-Location).Path
}

# Git konfigürasyonunu yükle
function Load-GitConfig {
    param([string]$ProjectPath)
    
    $configPath = Join-Path $ProjectPath "git-config.json"
    if (Test-Path $configPath) {
        try {
            return Get-Content $configPath -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

# Ana işlem
$projectRoot = Find-ProjectRoot
Set-Location $projectRoot

# Git repository kontrolü
if (-not (Test-Path ".git")) {
    git init 2>$null
}

# Konfigürasyon yükle
$config = Load-GitConfig -ProjectPath $projectRoot

# Git kullanıcı bilgilerini ayarla
if ($config -and $config.git.user.name -and $config.git.user.email) {
    git config user.name $config.git.user.name 2>$null
    git config user.email $config.git.user.email 2>$null
}

# Değişiklik kontrolü
$changes = git status --porcelain 2>$null
if (-not $changes) {
    # Git bilgilerini al
    $lastCommitHash = git rev-parse --short HEAD 2>$null
    $lastCommitMessage = git log -1 --pretty=format:"%s" 2>$null
    $gitUserName = git config user.name 2>$null
    if (-not $gitUserName) { $gitUserName = "Kullanıcı" }

    # Proje istatistikleri
    $totalFiles = (git ls-files | Measure-Object).Count
    $htmlFiles = (git ls-files "*.html" | Measure-Object).Count
    $cssFiles = (git ls-files "*.css" | Measure-Object).Count
    $jsFiles = (git ls-files "*.js" | Measure-Object).Count
    $otherFiles = $totalFiles - $htmlFiles - $cssFiles - $jsFiles

    # Son commit tarihi
    $lastCommitDate = git log -1 --pretty=format:"%cd" --date=format:"%d.%m.%Y %H:%M" 2>$null

    # Branch bilgisi
    $currentBranch = git branch --show-current 2>$null
    if (-not $currentBranch) { $currentBranch = "main" }

    # Değişiklik yoksa detaylı bilgi mesajı
    $infoMessage = @"

========================================
  SESSION SONU - DEGISIKLIK YOK
========================================
  Proje: $(Split-Path $projectRoot -Leaf)
  Committer: $gitUserName
  Branch: $currentBranch
  Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
  Durum: Tum dosyalar guncel

  Proje Ozeti:
  Toplam Dosya: $totalFiles
  HTML: $htmlFiles, CSS: $cssFiles, JS: $jsFiles, Diger: $otherFiles

  Son Commit: $lastCommitHash - "$lastCommitMessage"
  Commit Tarihi: $lastCommitDate
========================================

"@
    
    # STDERR'e yaz ve exit 2 - Bu Claude'a mesajı zorla gösterir
    [Console]::Error.WriteLine($infoMessage)

    # Process dosyasını temizle
    Remove-Item $processFile -Force -ErrorAction SilentlyContinue
    exit 2
}

# Akıllı commit mesajı oluştur
$timestamp = Get-Date -Format "yyMMddHHmmss"
$version = "v$timestamp"

# Son değişen dosyaları analiz et ve akıllı mesaj oluştur
$smartMessage = $Message

# git add'den önce değişen dosyaları yakala
$unstagedFiles = git diff --name-only 2>$null
$untrackedFiles = git ls-files --others --exclude-standard 2>$null
$allChangedFiles = @()

if ($unstagedFiles) { $allChangedFiles += $unstagedFiles }
if ($untrackedFiles) { $allChangedFiles += $untrackedFiles }

if ($allChangedFiles) {
    $fileCount = $allChangedFiles.Count

    if ($fileCount -eq 1) {
        # Tek dosya değişmişse dosya adını kullan
        $fileName = Split-Path $allChangedFiles[0] -Leaf
        $extension = [System.IO.Path]::GetExtension($fileName).ToLower()

        # Dosya yeni mi yoksa değiştirilmiş mi kontrol et
        $isNewFile = $untrackedFiles -contains $allChangedFiles[0]

        switch ($extension) {
            ".html" {
                $smartMessage = if ($isNewFile) { "$fileName olusturuldu" } else { "$fileName guncellendi" }
            }
            ".css" {
                $smartMessage = if ($isNewFile) { "$fileName olusturuldu" } else { "$fileName guncellendi" }
            }
            ".js" {
                $smartMessage = if ($isNewFile) { "$fileName olusturuldu" } else { "$fileName guncellendi" }
            }
            ".txt" {
                $smartMessage = if ($isNewFile) { "$fileName eklendi" } else { "$fileName guncellendi" }
            }
            ".ps1" { $smartMessage = "$fileName guncellendi" }
            ".json" { $smartMessage = "$fileName guncellendi" }
            default {
                $smartMessage = if ($isNewFile) { "$fileName olusturuldu" } else { "$fileName guncellendi" }
            }
        }
    } elseif ($fileCount -le 3) {
        # 2-3 dosya değişmişse kısa liste
        $fileNames = $allChangedFiles | ForEach-Object { Split-Path $_ -Leaf }
        $smartMessage = "$($fileNames -join ', ') guncellendi"
    } else {
        # Çok dosya değişmişse genel mesaj
        $smartMessage = "$fileCount dosya guncellendi"
    }
}

git add . 2>$null
$commitResult = git commit -m "$smartMessage - $version" 2>$null

if ($LASTEXITCODE -eq 0) {
    $commitHash = git rev-parse --short HEAD 2>$null
    $gitUserName = git config user.name 2>$null
    if (-not $gitUserName) { $gitUserName = "Kullanıcı" }

    # Değişen dosyaları say ve listele
    $changedFiles = git diff --name-only HEAD~1 HEAD 2>$null
    $changedFileCount = if ($changedFiles) { ($changedFiles | Measure-Object).Count } else { 0 }
    $changedFileList = if ($changedFiles) {
        $fileList = $changedFiles -join ", "
        if ($fileList.Length -gt 50) {
            $fileList.Substring(0, 47) + "..."
        } else {
            $fileList
        }
    } else { "Yok" }

    # Dosya tipi analizi
    $htmlCount = ($changedFiles | Where-Object { $_ -like "*.html" } | Measure-Object).Count
    $cssCount = ($changedFiles | Where-Object { $_ -like "*.css" } | Measure-Object).Count
    $jsCount = ($changedFiles | Where-Object { $_ -like "*.js" } | Measure-Object).Count
    $otherCount = $changedFileCount - $htmlCount - $cssCount - $jsCount

    # Branch bilgisi
    $currentBranch = git branch --show-current 2>$null
    if (-not $currentBranch) { $currentBranch = "main" }

    # Push yap
    $hasRemote = git remote 2>$null
    $pushStatus = "Lokal"

    if ($hasRemote -and $config -and $config.git.repository.autoPush -eq $true) {
        $pushResult = git push origin main --quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            $pushStatus = "GitHub'a gonderildi"
        } else {
            $pushStatus = "Push hatasi"
        }
    }

    # Başarı mesajı - STDERR'e yaz ve exit 2
    $successMessage = @"

========================================
  OTOMATIK KAYIT BASARILI!
========================================
  Proje: $(Split-Path $projectRoot -Leaf)
  Committer: $gitUserName
  Branch: $currentBranch
  Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
  Durum: Degisiklikler kaydedildi

  Degisen Dosyalar: $changedFileCount
  Dosyalar: $changedFileList
  Tipler: HTML($htmlCount), CSS($cssCount), JS($jsCount), Diger($otherCount)

  Son Commit: $commitHash - "$smartMessage"
  GitHub: $pushStatus
========================================

Bu mesaj Claude tarafindan gorulecek ve session sonu olarak kaydedilecek.

"@
    
    # STDERR'e yaz ve exit 2 - Bu Claude'a mesajı zorla gösterir
    [Console]::Error.WriteLine($successMessage)

    # Process dosyasını temizle
    Remove-Item $processFile -Force -ErrorAction SilentlyContinue
    exit 2
} else {
    # Commit hatası
    $gitUserName = git config user.name 2>$null
    if (-not $gitUserName) { $gitUserName = "Kullanıcı" }
    $lastCommitHash = git rev-parse --short HEAD 2>$null
    $lastCommitMessage = git log -1 --pretty=format:"%s" 2>$null

    $errorMessage = @"

========================================
  GIT COMMIT HATASI!
========================================
  Proje: $(Split-Path $projectRoot -Leaf)
  Committer: $gitUserName
  Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
  Durum: Commit yapilamadi
  Degisen Dosya: Bilinmiyor
  Son Commit: $lastCommitHash - "$lastCommitMessage"
========================================

"@

    [Console]::Error.WriteLine($errorMessage)

    # Process dosyasını temizle
    Remove-Item $processFile -Force -ErrorAction SilentlyContinue
    exit 2
}

# Process dosyasını temizle
Remove-Item $processFile -Force -ErrorAction SilentlyContinue
exit 0
