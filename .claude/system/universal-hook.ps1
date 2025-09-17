# Universal Git Hook - Her projede çalışır
# Bu script herhangi bir dizinde çalışabilir ve proje kökünü otomatik bulur

param(
    [string]$Message = "Claude degisikligi",
    [string]$Action = "commit",
    [string]$HookType = "PostToolUse"  # PostToolUse veya Stop
)

# SONSUZ DÖNGÜ ÖNLEME - JSON input'u oku
$jsonInput = ""
if (-not [Console]::IsInputRedirected) {
    # Eğer stdin yoksa normal çalış
} else {
    try {
        $jsonInput = [Console]::In.ReadToEnd()
        if ($jsonInput) {
            $inputData = $jsonInput | ConvertFrom-Json
            # stop_hook_active kontrolü - sonsuz döngüyü önle
            if ($inputData.stop_hook_active -eq $true) {
                # Zaten bir stop hook aktif, sessizce çık
                exit 0
            }
        }
    } catch {
        # JSON parse hatası, devam et
    }
}

$ErrorActionPreference = "SilentlyContinue"

# Proje kökünü bul
function Find-ProjectRoot {
    $currentPath = (Get-Location).Path
    $maxDepth = 10  # Maksimum 10 seviye yukarı çık
    $depth = 0
    
    while ($depth -lt $maxDepth) {
        # Git repository kontrolü
        $gitPath = Join-Path $currentPath ".git"
        if (Test-Path $gitPath) {
            return $currentPath
        }
        
        # git-config.json kontrolü
        $configPath = Join-Path $currentPath ".claude\system\git-config.json"
        if (Test-Path $configPath) {
            return $currentPath
        }
        
        # package.json kontrolü (Node.js projesi)
        $packagePath = Join-Path $currentPath "package.json"
        if (Test-Path $packagePath) {
            return $currentPath
        }
        
        # .gitignore kontrolü
        $gitignorePath = Join-Path $currentPath ".gitignore"
        if (Test-Path $gitignorePath) {
            return $currentPath
        }
        
        # Üst dizine çık
        $parent = Split-Path $currentPath -Parent
        if (-not $parent -or $parent -eq $currentPath) {
            break  # Root'a ulaştık
        }
        $currentPath = $parent
        $depth++
    }
    
    # Bulunamazsa mevcut dizini döndür
    return (Get-Location).Path
}

# Git konfigürasyonunu yükle - settings.local.json'dan
function Load-GitConfig {
    param([string]$ProjectPath)

    $settingsPath = Join-Path $ProjectPath ".claude\settings.local.json"
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($settings.git) {
                return $settings
            }
        } catch {
            return $null
        }
    }
    return $null
}

# Git kullanıcı bilgilerini ayarla
function Set-GitUser {
    param($GitConfig)
    
    if ($GitConfig -and $GitConfig.git.user.name -and $GitConfig.git.user.email) {
        git config user.name $GitConfig.git.user.name 2>$null
        git config user.email $GitConfig.git.user.email 2>$null
        return $true
    }
    return $false
}

# Ana işlem
$projectRoot = Find-ProjectRoot
Set-Location $projectRoot

# Git repository kontrolü
if (-not (Test-Path ".git")) {
    # Git repository değilse, init yap
    git init 2>$null
}

# Konfigürasyon yükle
$config = Load-GitConfig -ProjectPath $projectRoot
$gitConfigLoaded = Set-GitUser -GitConfig $config

# Değişiklik kontrolü
$changes = git status --porcelain 2>$null
if (-not $changes) {
    # Değişiklik yoksa
    if ($HookType -eq "Stop") {
        @{continue = $true} | ConvertTo-Json
    }
    exit 0
}

# Versiyon oluştur
$timestamp = Get-Date -Format "yyMMddHHmmss"
$version = "v$timestamp"

# Commit yap
git add . 2>$null
$commitResult = git commit -m "$Message - $version" 2>$null

if ($LASTEXITCODE -eq 0) {
    # Commit başarılı
    $commitHash = git rev-parse --short HEAD 2>$null
    
    # Push yap (eğer remote varsa ve ayarlıysa)
    $hasRemote = git remote 2>$null
    $pushStatus = "Lokal"
    
    if ($hasRemote -and $config -and $config.git.repository.autoPush -eq $true) {
        $pushResult = git push origin main --quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            $pushStatus = "GitHub'a gönderildi"
        } else {
            $pushStatus = "Push hatası"
        }
    }
    
    # Hook tipine göre çıktı
    if ($HookType -eq "Stop") {
        # Session sonu - JSON output (Claude'un görebileceği format)
        $stopMessage = @"

========================================
  OTOMATIK KAYIT BASARILI!
========================================
  Proje: $(Split-Path $projectRoot -Leaf)
  Versiyon: $version
  Commit: $commitHash
  Mesaj: $Message
  Tarih: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
  GitHub: $pushStatus
========================================

"@

        # JSON output - Claude Code'un beklediği format
        $output = @{
            continue = $true
            stopReason = $stopMessage
        }

        # JSON'u stdout'a yaz
        $jsonOutput = $output | ConvertTo-Json -Depth 3
        Write-Output $jsonOutput
    } else {
        # PostToolUse - sessiz mod (sadece hata durumunda mesaj)
        if (-not $gitConfigLoaded) {
            Write-Output "Git kullanıcı bilgileri ayarlanmadı"
        }
    }
} else {
    # Commit başarısız
    if ($HookType -eq "Stop") {
        @{continue = $true; stopReason = "Git commit hatası"} | ConvertTo-Json
    }
}

exit 0
