# Git Commit Listesi - Git Notes ile Geri Alma Bilgisi
param([string]$Action = "list")

$ErrorActionPreference = "SilentlyContinue"

function Get-RollbackInfo($commitHash) {
    $note = git notes show $commitHash 2>$null

    if ($note -match "rollback:(\d+):(\d{14}):(\d{14})") {
        $count = [int]$matches[1]
        $firstTime = $matches[2]
        $lastTime = $matches[3]

        # Tarihleri formatla
        $firstFormatted = Format-Timestamp $firstTime
        $lastFormatted = Format-Timestamp $lastTime

        return @{
            Count = $count
            FirstDate = $firstFormatted
            LastDate = $lastFormatted
        }
    }

    return $null
}

function Format-Timestamp($timestamp) {
    # 20250916143045 → 16.09.2025 14:30
    $year = $timestamp.Substring(0,4)
    $month = $timestamp.Substring(4,2)
    $day = $timestamp.Substring(6,2)
    $hour = $timestamp.Substring(8,2)
    $minute = $timestamp.Substring(10,2)

    return "${day}.${month}.${year} ${hour}:${minute}"
}

# Proje kokunu bul
if ($env:CLAUDE_PROJECT_DIR) {
    $projectRoot = $env:CLAUDE_PROJECT_DIR
} else {
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

Set-Location $projectRoot

if ($Action -eq "list") {
    # Mevcut Git repository bilgisini al
    $currentRepo = git remote get-url origin 2>$null
    $repoName = if ($currentRepo) {
        ($currentRepo -split '/')[-1] -replace '\.git$', ''
    } else {
        "Unknown"
    }

    Write-Output ""
    Write-Output "==================== GIT COMMIT LISTESI ===================="
    Write-Output "Repository: $repoName"
    Write-Output "LUTFEN BU LISTEYI AYNEN GOSTER - YORUMLAMA YAPMA!"
    Write-Output ""

    # Bu repository'nin tum commitlerini al (ilk commit'ten itibaren)
    # Ilk commit'i bul
    $firstCommit = git log --reverse --oneline | Select-Object -First 1 | ForEach-Object { ($_ -split ' ')[0] }

    if ($firstCommit) {
        # Ilk commit'ten HEAD'e kadar olan commitler
        $allCommits = git log "${firstCommit}..HEAD" --pretty=format:"%h|%cd|%s" --date=format:"%d.%m.%Y %H:%M"
        # Ilk commit'i de dahil et
        $firstCommitInfo = git log $firstCommit --pretty=format:"%h|%cd|%s" --date=format:"%d.%m.%Y %H:%M" -1
        $allCommits = @($firstCommitInfo) + @($allCommits)
    } else {
        # Fallback: Son 50 commit
        $allCommits = git log --pretty=format:"%h|%cd|%s" --date=format:"%d.%m.%Y %H:%M" -50
    }
    $versionedCommits = @()

    foreach ($commit in $allCommits) {
        $parts = $commit -split '\|'
        if ($parts.Length -eq 3) {
            $message = $parts[2]
            # Sadece "v250915" formatinda versiyon iceren commitler
            if ($message -match "v\d{12}") {
                $versionedCommits += $commit
            }
        }
    }

    $totalCommits = $versionedCommits.Count
    $count = $totalCommits

    # Notes'lari guncellemek icin fetch
    git fetch origin refs/notes/*:refs/notes/* 2>$null

    # Aktif commit'i tespit et
    $currentHead = git rev-parse HEAD 2>$null
    $shortHead = if ($currentHead) { $currentHead.Substring(0,7) } else { "" }

    foreach ($commit in $versionedCommits) {
        $parts = $commit -split '\|'
        if ($parts.Length -eq 3) {
            $hash = $parts[0]
            $date = $parts[1]
            $message = $parts[2]

            # Rollback bilgisini kontrol et
            $rollbackInfo = Get-RollbackInfo $hash

            # Aktif commit mi kontrol et
            $isActive = ($hash -eq $shortHead)

            if ($rollbackInfo) {
                if ($isActive) {
                    Write-Output "[$count] $date - $hash - $message <- AKTIF ($($rollbackInfo.Count) kez geri alinmis - Ilk: $($rollbackInfo.FirstDate), Son: $($rollbackInfo.LastDate))"
                } else {
                    Write-Output "[$count] $date - $hash - $message <- GERI ALINMIS ($($rollbackInfo.Count) kez - Ilk: $($rollbackInfo.FirstDate), Son: $($rollbackInfo.LastDate))"
                }
            } elseif ($isActive) {
                Write-Output "[$count] $date - $hash - $message ← AKTIF"
            } else {
                Write-Output "[$count] $date - $hash - $message"
            }
        }
        $count--
    }

    Write-Output ""
    Write-Output "Kullanim: /geri-al v[versiyon_no]"
    Write-Output "Ornek: /geri-al v250915191611"
    Write-Output ""
}
