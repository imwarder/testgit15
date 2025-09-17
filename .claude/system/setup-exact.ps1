# Claude CLI Setup - Direkt JSON guncelleme
param(
    [string]$GitName,
    [string]$GitEmail,
    [string]$RepoUrl = "",
    [string]$CommitMode = "selective",
    [string]$GitHubMode = "existing"
)

Write-Host "Claude CLI Setup" -ForegroundColor Cyan

# Mevcut klasor adini dinamik olarak al
# .claude/system -> .claude -> gittest12
$scriptDir = $PSScriptRoot  # Script'in bulundugu dizin
$claudeDir = Split-Path $scriptDir -Parent  # .claude
$projectDir = Split-Path $claudeDir -Parent  # proje ana dizini
$currentFolder = Split-Path $projectDir -Leaf

# GitHub modu kontrolu
if ($GitHubMode -eq "new") {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "=================================================================================" -ForegroundColor Cyan
    Write-Host "                           YENI PROJE MODU" -ForegroundColor Magenta
    Write-Host "=================================================================================" -ForegroundColor Cyan
    Write-Host "Git repository sifirdan olusturuluyor..." -ForegroundColor Yellow
    Write-Host ""

    # Git repository olustur
    if (-not (Test-Path ".git")) {
        git init
        git branch -M main
        Write-Host "[OK] Git repository olusturuldu" -ForegroundColor Green
    } else {
        Write-Host "[UYARI] Git repository zaten mevcut" -ForegroundColor Yellow
    }

    # YENI PROJE modunda GitHub remote'u hemen ayarla
    if ($RepoUrl -and $RepoUrl.Trim() -ne "") {
        git remote add origin $RepoUrl
        Write-Host "[OK] GitHub repository baglandi: $RepoUrl" -ForegroundColor Green

        # Remote baglantisini test et
        $testRemote = git remote get-url origin 2>$null
        if ($testRemote) {
            Write-Host "[OK] Remote repository basariyla ayarlandi!" -ForegroundColor Green
        } else {
            Write-Host "[UYARI] Remote repository ayarlanamadi!" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[UYARI] GitHub repository URL bulunamadi" -ForegroundColor Yellow
    }

    # Commit mode'u initial olarak ayarla
    $CommitMode = "initial"
} else {
    Write-Host "Mevcut proje guncelleniyor..." -ForegroundColor Cyan
}

# Debug mesajlari kaldirildi

try {
    # 1. Mevcut settings.local.json'u oku ve backup al
    $settingsPath = Join-Path $claudeDir "settings.local.json"
    $existingRepoUrl = ""
    $existingAutoPush = $false

    if (Test-Path $settingsPath) {
        try {
            # Eski settings'i oku
            $existingSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($existingSettings.git.repository.url) {
                $existingRepoUrl = $existingSettings.git.repository.url
                Write-Host "Mevcut GitHub URL korunuyor: $existingRepoUrl" -ForegroundColor Cyan
            }
            if ($existingSettings.git.repository.autoPush) {
                $existingAutoPush = $existingSettings.git.repository.autoPush
            }
        } catch {
            Write-Host "Eski settings okunamadi, yeni ayarlar olusturuluyor..." -ForegroundColor Yellow
        }

        # Backup al
        $backupPath = Join-Path $claudeDir "settings.local.json.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $settingsPath $backupPath
        Write-Host "Mevcut Claude ayarlari yedeklendi: $(Split-Path $backupPath -Leaf)" -ForegroundColor Green
    }

    # 2. JSON'u direkt olustur
    Write-Host "Claude ayarlari guncelleniyor..." -ForegroundColor Yellow



    # JSON objesini olustur - Tum ayarlar tek dosyada
    $settings = @{
        permissions = @{
            defaultMode = "bypassPermissions"
            allow = @("*")
            deny = @()
        }
        hooks = @{
            PostToolUse = @(
                @{
                    matcher = "Write|Edit|MultiEdit|Bash|Remove|Move|Copy|Create"
                    hooks = @(
                        @{
                            type = "command"
                            command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$projectDir\.claude\system\universal-hook.ps1`" -Message `"Claude degisikligi`" -HookType PostToolUse"
                        }
                    )
                }
            )
            Stop = @(
                @{
                    matcher = ".*"
                    hooks = @(
                        @{
                            type = "command"
                            command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$projectDir\.claude\system\working-stop-hook.ps1`" -Message `"Session tamamlandi`" -HookType Stop"
                        }
                    )
                }
            )
        }
        git = @{
            user = @{
                name = $GitName
                email = $GitEmail
            }
            repository = @{
                url = if ($RepoUrl -and $RepoUrl.Trim() -ne "") { $RepoUrl } elseif ($existingRepoUrl -and $existingRepoUrl.Trim() -ne "") { $existingRepoUrl } else { "" }
                branch = "main"
                autoPush = if ($RepoUrl -and $RepoUrl.Trim() -ne "") { $true } elseif ($existingRepoUrl -and $existingRepoUrl.Trim() -ne "") { $existingAutoPush } else { $false }
            }
            versioning = @{
                enabled = $true
                sessionCommits = $true
                format = "YYMMDDHHMMSS"
            }
        }
    }

    # JSON'a cevir ve kaydet
    $jsonContent = $settings | ConvertTo-Json -Depth 10

    # UTF8 BOM'suz olarak kaydet
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($settingsPath, $jsonContent, $utf8NoBom)

    Write-Host "Claude ayarlari guncellendi - Tum ayarlar tek dosyada!" -ForegroundColor Green

    # 4. Git kullanici bilgilerini ayarla
    git config user.name $GitName
    git config user.email $GitEmail
    Write-Host "Git kullanici bilgileri ayarlandi" -ForegroundColor Green

    if ($CommitMode -eq "selective") {
        Write-Host "`nNot: Sadece Claude ayarlari commit edilecek, diger dosyalariniz dokunulmayacak" -ForegroundColor Yellow
    } elseif ($CommitMode -eq "changes") {
        Write-Host "`nNot: Mevcut degisiklikler commit edilecek (yeni/degisen dosyalar)" -ForegroundColor Cyan
    } elseif ($CommitMode -eq "all") {
        Write-Host "`nNot: TUM dosyalar yeniden commit edilecek (mevcut + yeni, force)" -ForegroundColor Magenta
    } else {
        Write-Host "`nNot: Commit yapilmayacak, manuel kontrol gerekli" -ForegroundColor Gray
    }

    # 5. GitHub repo baglantisi - Dinamik URL kullanimi
    $finalRepoUrl = $RepoUrl
    if (-not $finalRepoUrl -and $settings.git.repository.url) {
        $finalRepoUrl = $settings.git.repository.url
        Write-Host "Settings'den GitHub URL alindi: $finalRepoUrl" -ForegroundColor Cyan
    }

    if ($finalRepoUrl -and $finalRepoUrl.Trim() -ne "") {
        $remoteExists = git remote get-url origin 2>$null
        if ($remoteExists) {
            git remote set-url origin $finalRepoUrl
            Write-Host "GitHub repository URL guncellendi: $finalRepoUrl" -ForegroundColor Green
        } else {
            git remote add origin $finalRepoUrl
            Write-Host "GitHub repository baglandi: $finalRepoUrl" -ForegroundColor Green
        }

        # Remote baglantisini test et
        $testRemote = git remote get-url origin 2>$null
        if ($testRemote) {
            Write-Host "[OK] Remote repository basariyla ayarlandi!" -ForegroundColor Green
        } else {
            Write-Host "[UYARI] Remote repository ayarlanamadi!" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[UYARI] GitHub repository URL bulunamadi - Remote ayarlanmadi" -ForegroundColor Yellow
        Write-Host "Manuel olarak ayarlamak icin: git remote add origin [URL]" -ForegroundColor Gray
    }

    # 6. Commit yap - Kullanici secinine gore
    if ($CommitMode -ne "none") {
        # Proje ana dizinine gec
        Push-Location
        Set-Location $projectDir

        if ($CommitMode -eq "initial") {
            Write-Host "YENI PROJE - Ilk commit atiliyor..." -ForegroundColor Magenta

            # Once .claude/system/.git varsa temizle
            if (Test-Path ".claude/system/.git") {
                Remove-Item -Recurse -Force ".claude/system/.git" -ErrorAction SilentlyContinue
                Write-Host "[UYARI] .claude/system/.git temizlendi" -ForegroundColor Yellow
            }

            # Tum dosyalari ekle
            Write-Host "Tum dosyalar ekleniyor..." -ForegroundColor Green
            git add . 2>$null

            if ($LASTEXITCODE -ne 0) {
                Write-Host "[UYARI] Git add hatasi, tekrar deneniyor..." -ForegroundColor Yellow
                git add --all 2>$null
            }

            # Git status kontrol
            $status = git status --porcelain
            if (-not $status) {
                Write-Host "[UYARI] Hicbir dosya staged degil, .claude klasorunu ekleniyor..." -ForegroundColor Yellow
                git add .claude/ 2>$null
            }

            # Ilk commit
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $commitMessage = "Ilk commit - Claude CLI otomatik versiyonlama sistemi kuruldu - v$timestamp"

            Write-Host "Ilk commit atiliyor: $commitMessage" -ForegroundColor Cyan
            git commit -m $commitMessage 2>$null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Ilk commit basarili!" -ForegroundColor Green
            } else {
                Write-Host "❌ Ilk commit basarisiz!" -ForegroundColor Red
                Write-Host "Git status:" -ForegroundColor Gray
                git status
            }

        } elseif ($CommitMode -eq "all") {
            Write-Host "TUM proje dosyalari yeniden commit ediliyor (sifirdan)..." -ForegroundColor Magenta

            # Tum dosyalari listele
            $allFiles = git ls-files
            Write-Host "Toplam $($allFiles.Count) dosya sifirdan commit edilecek..." -ForegroundColor Cyan

            # Git gecmisini sifirla ve tum dosyalari yeniden commit et
            Write-Host "Git index sifirlaniyor..." -ForegroundColor Yellow
            git reset

            # Tum dosyalari yeniden ekle
            Write-Host "Tum dosyalar yeniden ekleniyor..." -ForegroundColor Green
            git add .

            # Commit et - tum dosyalar yeniden commit edilecek
            git commit -m "Claude CLI Setup - All $($allFiles.Count) project files recommitted (complete reset)"
        } elseif ($CommitMode -eq "changes") {
            Write-Host "Mevcut degisiklikler commit ediliyor..." -ForegroundColor Yellow
            git add .
            git commit -m "Claude CLI Setup - Current changes committed"
        } elseif ($CommitMode -eq "selective") {
            Write-Host "Sadece Claude ayarlari commit ediliyor..." -ForegroundColor Green
            git add .claude/settings.local.json
            git add .claude/settings.local.json.backup.*
            git add .claude/system/
            git commit -m "Claude CLI Setup - Settings configured"
        }

        Pop-Location  # Geri don
    } else {
        Write-Host "Commit atlaniyor - Manuel kontrol gerekli" -ForegroundColor Cyan
    }
    
    if ($finalRepoUrl -and $finalRepoUrl.Trim() -ne "" -and $CommitMode -ne "none") {
        Push-Location
        Set-Location $projectDir

        Write-Host "`nGitHub'a push yapiliyor..." -ForegroundColor Yellow

        # Once normal push dene
        $pushResult = git push -u origin main 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Push basarili!" -ForegroundColor Green
        } else {
            # Push basarisiz, force push gerekebilir
            Write-Host "[UYARI] Normal push basarisiz. Sebep:" -ForegroundColor Yellow
            Write-Host "$pushResult" -ForegroundColor Gray

            Write-Host "`nGitHub'daki versiyon farkli. Zorla push yapilsin mi?" -ForegroundColor Cyan
            Write-Host "  1) Evet - Zorla push yap (GitHub'daki farkli commit'ler silinir)" -ForegroundColor Red
            Write-Host "  2) Hayir - Manuel cozum gerekli" -ForegroundColor Yellow

            $choice = Read-Host "`nSeciminiz (1/2)"

            if ($choice -eq "1") {
                Write-Host "`nZorla push yapiliyor..." -ForegroundColor Red
                $forcePushResult = git push --force origin main 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Zorla push basarili!" -ForegroundColor Green
                    Write-Host "GitHub'daki proje lokal proje ile sync edildi." -ForegroundColor Cyan
                } else {
                    Write-Host "❌ Zorla push da basarisiz!" -ForegroundColor Red
                    Write-Host "$forcePushResult" -ForegroundColor Gray
                    Write-Host "Manuel olarak GitHub'i kontrol edin." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Push atlaniyor. Manuel cozum gerekli:" -ForegroundColor Yellow
                Write-Host "  git pull origin main" -ForegroundColor Gray
                Write-Host "  git push origin main" -ForegroundColor Gray
                Write-Host "veya:" -ForegroundColor Gray
                Write-Host "  git push --force origin main" -ForegroundColor Gray
            }
        }

        Pop-Location
    } elseif ($CommitMode -eq "none") {
        Write-Host "Push atlaniyor - Commit yapilmadi" -ForegroundColor Cyan
    }

    Write-Host "`nSETUP TAMAMLANDI!" -ForegroundColor Magenta
    Write-Host "Klasor: $currentFolder" -ForegroundColor Cyan
    Write-Host "Kullanici: $GitName" -ForegroundColor Cyan
    Write-Host "Email: $GitEmail" -ForegroundColor Cyan
    if ($RepoUrl) {
        Write-Host "Repo: $RepoUrl" -ForegroundColor Cyan
    }
    Write-Host "`nJSON DIREKT OLUSTURULDU - PATH DINAMIK!" -ForegroundColor Green
    
} catch {
    Write-Host "Setup hatasi: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
