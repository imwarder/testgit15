# Claude CLI Git Sistemi - Ana Kurulum (PowerShell)
param(
    [string]$GitName = "",
    [string]$GitEmail = "",
    [string]$RepoUrl = ""
)

# Console encoding ayarlari - Turkce karakter destegi
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Windows Console icin UTF-8 ayari
try {
    chcp 65001 | Out-Null
    [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Hata durumunda sessizce devam et
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                    CLAUDE CLI GIT SISTEMI KURULUMU" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bu kurulum sunlari yapacak:" -ForegroundColor Yellow
Write-Host "  - Git ayarlarinizi yapilandiracak" -ForegroundColor White
Write-Host "  - Otomatik commit sistemini kuracak" -ForegroundColor White
Write-Host "  - Versiyon takip sistemini aktiflestirecek" -ForegroundColor White
Write-Host "  - Claude CLI hook'larini ayarlayacak" -ForegroundColor White
Write-Host "  - GitHub entegrasyonunu yapacak" -ForegroundColor White
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Git kontrolu
try {
    git --version | Out-Null
} catch {
    Write-Host "HATA: Git yuklu degil!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Git'i yuklemek icin: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Devam etmek icin Enter'a basin"
    exit 1
}

Write-Host "Lutfen bilgilerinizi girin:" -ForegroundColor Cyan
Write-Host ""

# Kullanici bilgilerini al
if (-not $GitName) {
    $GitName = Read-Host "Git kullanici adiniz (orn: Ahmet Yilmaz)"
    if (-not $GitName) {
        Write-Host "HATA: Kullanici adi bos olamaz!" -ForegroundColor Red
        Read-Host "Devam etmek icin Enter'a basin"
        exit 1
    }
}

if (-not $GitEmail) {
    $GitEmail = Read-Host "Git email adresiniz (orn: ahmet@gmail.com)"
    if (-not $GitEmail) {
        Write-Host "HATA: Email adresi bos olamaz!" -ForegroundColor Red
        Read-Host "Devam etmek icin Enter'a basin"
        exit 1
    }
}

Write-Host ""
Write-Host "GitHub Repository Ayarlari (Zorunlu)" -ForegroundColor Cyan
if (-not $RepoUrl) {
    $RepoUrl = Read-Host "GitHub repo URL'si (orn: https://github.com/kullanici/proje.git)"
    if (-not $RepoUrl) {
        Write-Host "HATA: GitHub repository URL'si gerekli!" -ForegroundColor Red
        Write-Host "Bu sistem GitHub entegrasyonu ile calisir." -ForegroundColor Yellow
        Read-Host "Devam etmek icin Enter'a basin"
        exit 1
    }
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "GITHUB REPOSITORY KONTROL EDILIYOR..." -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# GitHub repository durumunu kontrol et
Write-Host "Repository kontrol ediliyor: $RepoUrl" -ForegroundColor White

try {
    $remoteCheck = git ls-remote --heads $RepoUrl main 2>$null
    $hasCommits = $remoteCheck -and $remoteCheck.Trim() -ne ""
    
    if ($hasCommits) {
        # MEVCUT PROJE
        Write-Host ""
        Write-Host "================================================================================" -ForegroundColor Green
        Write-Host "MEVCUT PROJE TESPIT EDILDI" -ForegroundColor Green
        Write-Host "================================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "GitHub'da commitler bulundu. Bu mevcut bir proje." -ForegroundColor Yellow
        Write-Host "Guncelleme secenekleri:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1) Claude ayarlarini guncelle (Guvenli - Onerilen)" -ForegroundColor White
        Write-Host "     - .claude klasoru commit edilir" -ForegroundColor Gray
        Write-Host "     - Mevcut dosyalariniz dokunulmaz" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2) Mevcut degisiklikleri commit et (Yeni/degisen dosyalar)" -ForegroundColor White
        Write-Host "     - Git'te izlenen tum degisiklikler commit edilir" -ForegroundColor Gray
        Write-Host "     - Yeni dosyalar eklenir" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  3) TUM proje dosyalarini yeniden commit et (Sync)" -ForegroundColor White
        Write-Host "     - Tum dosyalar sifirdan commit edilir" -ForegroundColor Gray
        Write-Host "     - GitHub ile sync sorunlari cozulur" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  4) Commit yapma (Manuel kontrol)" -ForegroundColor White
        Write-Host "     - Hicbir commit yapilmaz" -ForegroundColor Gray
        Write-Host "     - Kendiniz manuel commit atabilirsiniz" -ForegroundColor Gray
        Write-Host ""
        
        $commitChoice = Read-Host "Seciminiz (1-4)"
        if (-not $commitChoice) { $commitChoice = "1" }
        
        switch ($commitChoice) {
            "1" { $commitMode = "selective" }
            "2" { $commitMode = "changes" }
            "3" { $commitMode = "all" }
            "4" { $commitMode = "none" }
            default { $commitMode = "selective" }
        }
        
        $githubMode = "existing"
        
    } else {
        # YENI PROJE
        Write-Host ""
        Write-Host "================================================================================" -ForegroundColor Magenta
        Write-Host "YENI PROJE TESPIT EDILDI" -ForegroundColor Magenta
        Write-Host "================================================================================" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "GitHub'da commit bulunamadi veya repository bos." -ForegroundColor Yellow
        Write-Host "Yeni proje baslatilacak:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [OK] Git repository olusturulacak" -ForegroundColor Green
        Write-Host "  [OK] Ilk commit atilacak" -ForegroundColor Green
        Write-Host "  [OK] GitHub'a push yapilacak" -ForegroundColor Green
        Write-Host "  [OK] Temiz commit history baslatilacak" -ForegroundColor Green
        Write-Host ""
        
        $continue = Read-Host "Devam edilsin mi? (E/H)"
        if ($continue -ne "E" -and $continue -ne "e") {
            Write-Host "Kurulum iptal edildi." -ForegroundColor Yellow
            Read-Host "Devam etmek icin Enter'a basin"
            exit 0
        }
        
        $commitChoice = "5"
        $commitMode = "initial"
        $githubMode = "new"
    }
    
} catch {
    Write-Host "HATA: GitHub repository kontrol edilemedi!" -ForegroundColor Red
    Write-Host "Hata: $($_.Exception.Message)" -ForegroundColor Gray
    Read-Host "Devam etmek icin Enter'a basin"
    exit 1
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "KURULUM BASLIYOR..." -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# PowerShell Execution Policy ayari
Write-Host "PowerShell ayarlari yapiliyor..." -ForegroundColor White
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
} catch {
    Write-Host "[UYARI] PowerShell execution policy ayarlanamadi" -ForegroundColor Yellow
}

# Ana proje klasorune gec
$scriptDir = $PSScriptRoot  # .claude/system
$claudeDir = Split-Path $scriptDir -Parent  # .claude
$projectDir = Split-Path $claudeDir -Parent  # ana proje klasoru

Write-Host "Proje klasoru: $projectDir" -ForegroundColor Gray
Set-Location $projectDir

# Setup scriptini calistir
Write-Host "Sistem kuruluyor..." -ForegroundColor White
try {
    & "$scriptDir\setup-exact.ps1" -GitName $GitName -GitEmail $GitEmail -RepoUrl $RepoUrl -CommitMode $commitMode -GitHubMode $githubMode
    
    if ($LASTEXITCODE -ne 0) {
        throw "Setup script hata dondurdu: $LASTEXITCODE"
    }

} catch {
    Write-Host ""
    Write-Host "HATA: Kurulum sirasinda hata olustu!" -ForegroundColor Red
    Write-Host "Hata: $($_.Exception.Message)" -ForegroundColor Gray
    Read-Host "Devam etmek icin Enter'a basin"
    exit 1
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "KURULUM TAMAMLANDI!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Sistem Bilgileri:" -ForegroundColor Cyan
Write-Host "   Kullanici: $GitName" -ForegroundColor White
Write-Host "   Email: $GitEmail" -ForegroundColor White
if ($RepoUrl) {
    Write-Host "   Repository: $RepoUrl" -ForegroundColor White
}
Write-Host ""
Write-Host "Kullanabileceginiz Komutlar:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Versiyonlari listele:" -ForegroundColor White
Write-Host "      /geri-al-list" -ForegroundColor Gray
Write-Host ""
Write-Host "   Belirli versiyona geri don:" -ForegroundColor White
Write-Host "      /geri-al v[versiyon_no]" -ForegroundColor Gray
Write-Host "      Ornek: /geri-al v250914220011" -ForegroundColor Gray
Write-Host ""
Write-Host "   Claude'da kullanim:" -ForegroundColor White
Write-Host "      /geri-al-list" -ForegroundColor Gray
Write-Host "      /geri-al v250914220011" -ForegroundColor Gray
Write-Host "      /geri-al help" -ForegroundColor Gray
Write-Host ""

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Claude CLI artik her degisikligi otomatik olarak kaydedecek!" -ForegroundColor Green
Write-Host ""
Write-Host "Not: Claude ile calisirken:" -ForegroundColor Yellow
Write-Host "   - Her dosya degisikligi otomatik commit olacak" -ForegroundColor White
Write-Host "   - Her session sonunda otomatik commit atilacak" -ForegroundColor White
Write-Host "   - Tum degisiklikler versiyon numarasi ile kaydedilecek" -ForegroundColor White
Write-Host "   - /geri-al komutlari ile istediginiz versiyona donebilirsiniz" -ForegroundColor White
Write-Host ""
Write-Host "GitHub Durumu:" -ForegroundColor Cyan
if ($RepoUrl) {
    Write-Host "   Repository: $RepoUrl" -ForegroundColor White
    Write-Host "   Otomatik Push: AKTIF" -ForegroundColor Green
    Write-Host "   Her commit otomatik olarak GitHub'a gonderilir" -ForegroundColor White
} else {
    Write-Host "   GitHub baglantisi yok - lokal Git" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Devam etmek icin Enter'a basin"
