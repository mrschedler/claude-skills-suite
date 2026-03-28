#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets up a Windows machine for Claude Code + Claude Desktop with the
    claude-skills-suite as the single source of truth for configuration.

.DESCRIPTION
    Creates junctions and symlinks so that Claude Code and Claude Desktop
    read config from C:\dev\claude-skills-suite (git-backed, Syncthing-synced).
    Handles both fresh install and migration from existing .claude config.

.NOTES
    Must run as Administrator (symlinks require it on Windows).
    Assumes C:\dev\ is the Syncthing share and claude-skills-suite is synced.
#>

$ErrorActionPreference = "Stop"

$DevRoot = "C:\dev"
$SkillsSuite = "$DevRoot\claude-skills-suite"
$ClaudeDir = "$DevRoot\.claude"
$UserClaude = "$env:USERPROFILE\.claude"
$DesktopAppData = "$env:APPDATA\Claude"
$BackupDir = "$ClaudeDir\backups\pre-consolidation"

# ── Preflight checks ─────────────────────────────────────────────────────

Write-Host "`n=== Claude Platform Setup ===" -ForegroundColor Cyan

if (-not (Test-Path $DevRoot)) {
    Write-Error "C:\dev does not exist. Sync via Syncthing first."
    exit 1
}
if (-not (Test-Path $SkillsSuite)) {
    Write-Error "claude-skills-suite not found at $SkillsSuite. Sync via Syncthing first."
    exit 1
}
if (-not (Test-Path $ClaudeDir)) {
    Write-Host "Creating $ClaudeDir..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ClaudeDir | Out-Null
}

# ── 1. Junction: ~/.claude -> C:\dev\.claude ──────────────────────────────

Write-Host "`n[1/7] Junction: $UserClaude -> $ClaudeDir" -ForegroundColor Green

if (Test-Path $UserClaude) {
    $item = Get-Item $UserClaude -Force
    if ($item.LinkType -eq "Junction") {
        $target = $item.Target
        if ($target -eq $ClaudeDir -or $target -contains $ClaudeDir) {
            Write-Host "  Already exists and points correctly. Skipping." -ForegroundColor Gray
        } else {
            Write-Warning "  Junction exists but points to $target. Removing and recreating."
            $item.Delete()
            New-Item -ItemType Junction -Path $UserClaude -Target $ClaudeDir | Out-Null
            Write-Host "  Recreated." -ForegroundColor Green
        }
    } else {
        # Real directory — back up and replace
        Write-Host "  Real directory found. Backing up to $BackupDir\user-claude-backup..." -ForegroundColor Yellow
        if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
        Copy-Item -Path $UserClaude -Destination "$BackupDir\user-claude-backup" -Recurse -Force
        Remove-Item -Path $UserClaude -Recurse -Force
        New-Item -ItemType Junction -Path $UserClaude -Target $ClaudeDir | Out-Null
        Write-Host "  Backed up and replaced with junction." -ForegroundColor Green
    }
} else {
    New-Item -ItemType Junction -Path $UserClaude -Target $ClaudeDir | Out-Null
    Write-Host "  Created." -ForegroundColor Green
}

# ── 2. Config file symlinks ───────────────────────────────────────────────

Write-Host "`n[2/7] Config symlinks in $ClaudeDir" -ForegroundColor Green

$configFiles = @(
    @{ Name = "CLAUDE.md";                 Source = "$SkillsSuite\config\code\CLAUDE.md" },
    @{ Name = "settings.json";             Source = "$SkillsSuite\config\code\settings.json" },
    @{ Name = "behavioral-reminders.txt";  Source = "$SkillsSuite\config\code\behavioral-reminders.txt" }
)

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

foreach ($f in $configFiles) {
    $linkPath = "$ClaudeDir\$($f.Name)"
    $targetPath = $f.Source

    if (-not (Test-Path $targetPath)) {
        Write-Warning "  Source not found: $targetPath. Skipping $($f.Name)."
        continue
    }

    if (Test-Path $linkPath) {
        $item = Get-Item $linkPath -Force
        if ($item.LinkType -eq "SymbolicLink") {
            Write-Host "  $($f.Name): Already a symlink. Skipping." -ForegroundColor Gray
            continue
        }
        # Real file — backup then replace
        Write-Host "  $($f.Name): Backing up real file..." -ForegroundColor Yellow
        Copy-Item -Path $linkPath -Destination "$BackupDir\$($f.Name)" -Force
        Remove-Item -Path $linkPath -Force
    }

    New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath | Out-Null
    Write-Host "  $($f.Name): Symlink created." -ForegroundColor Green
}

# ── 3. Skills symlink ────────────────────────────────────────────────────

Write-Host "`n[3/7] Skills symlink" -ForegroundColor Green

$skillsLink = "$ClaudeDir\skills"
$skillsTarget = "$SkillsSuite\skills"

if (Test-Path $skillsLink) {
    $item = Get-Item $skillsLink -Force
    if ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction") {
        Write-Host "  Already exists. Skipping." -ForegroundColor Gray
    } else {
        Write-Warning "  Real directory at $skillsLink. Renaming to skills-old and creating symlink."
        Rename-Item $skillsLink "$ClaudeDir\skills-old-$(Get-Date -Format 'yyyyMMdd')"
        New-Item -ItemType SymbolicLink -Path $skillsLink -Target $skillsTarget | Out-Null
        Write-Host "  Symlink created." -ForegroundColor Green
    }
} else {
    New-Item -ItemType SymbolicLink -Path $skillsLink -Target $skillsTarget | Out-Null
    Write-Host "  Created." -ForegroundColor Green
}

# ── 4. Desktop config symlink ────────────────────────────────────────────

Write-Host "`n[4/7] Desktop config symlink" -ForegroundColor Green

$desktopConfig = "$DesktopAppData\claude_desktop_config.json"
$desktopSource = "$SkillsSuite\config\desktop\claude_desktop_config.json"

if (-not (Test-Path $DesktopAppData)) {
    Write-Host "  Claude Desktop not installed ($DesktopAppData missing). Skipping." -ForegroundColor Yellow
} elseif (-not (Test-Path $desktopSource)) {
    Write-Host "  No desktop config at $desktopSource." -ForegroundColor Yellow
    $templatePath = "$SkillsSuite\config\desktop\claude_desktop_config.template.json"
    if (Test-Path $templatePath) {
        Write-Host "  Copying template. You'll need to fill in CF Access secrets." -ForegroundColor Yellow
        Copy-Item $templatePath $desktopSource
    } else {
        Write-Warning "  No template found either. Desktop config must be created manually."
    }
    # Still create the symlink if we copied the template
    if (Test-Path $desktopSource) {
        if (Test-Path $desktopConfig) {
            $item = Get-Item $desktopConfig -Force
            if ($item.LinkType -ne "SymbolicLink") {
                Copy-Item $desktopConfig "$BackupDir\claude_desktop_config.json" -Force
                Remove-Item $desktopConfig -Force
            } else {
                Write-Host "  Already a symlink. Skipping." -ForegroundColor Gray
            }
        }
        if (-not (Test-Path $desktopConfig)) {
            New-Item -ItemType SymbolicLink -Path $desktopConfig -Target $desktopSource | Out-Null
            Write-Host "  Symlink created." -ForegroundColor Green
        }
    }
} else {
    if (Test-Path $desktopConfig) {
        $item = Get-Item $desktopConfig -Force
        if ($item.LinkType -eq "SymbolicLink") {
            Write-Host "  Already a symlink. Skipping." -ForegroundColor Gray
        } else {
            Copy-Item $desktopConfig "$BackupDir\claude_desktop_config.json" -Force
            Remove-Item $desktopConfig -Force
            New-Item -ItemType SymbolicLink -Path $desktopConfig -Target $desktopSource | Out-Null
            Write-Host "  Backed up and symlinked." -ForegroundColor Green
        }
    } else {
        New-Item -ItemType SymbolicLink -Path $desktopConfig -Target $desktopSource | Out-Null
        Write-Host "  Created." -ForegroundColor Green
    }
}

# ── 5. Machine identity ──────────────────────────────────────────────────

Write-Host "`n[5/7] Machine identity" -ForegroundColor Green

$machineIdFile = "$DevRoot\.machine-id"
if (Test-Path $machineIdFile) {
    $content = Get-Content $machineIdFile -Raw
    Write-Host "  .machine-id exists: $($content.Trim())" -ForegroundColor Gray
} else {
    $machineName = Read-Host "  Enter machine name (e.g., dell-xps, skip)"
    $hostname = $env:COMPUTERNAME
    @"
machine: $machineName
hostname: $hostname
model: $(Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Model)
"@ | Out-File -FilePath $machineIdFile -Encoding utf8 -NoNewline
    Write-Host "  Created .machine-id for '$machineName'" -ForegroundColor Green
}

$machineIdentity = "$ClaudeDir\machine-identity.json"
if (Test-Path $machineIdentity) {
    Write-Host "  machine-identity.json exists. Skipping." -ForegroundColor Gray
} else {
    $displayName = Read-Host "  Enter Mattermost display name (e.g., Claude (Dell-Silver), Claude (Skip))"
    @"
{"name": "$machineName", "mattermost_username": "$displayName"}
"@ | Out-File -FilePath $machineIdentity -Encoding utf8 -NoNewline
    Write-Host "  Created machine-identity.json" -ForegroundColor Green
}

# ── 6. Cleanup stale files ───────────────────────────────────────────────

Write-Host "`n[6/7] Cleanup stale files" -ForegroundColor Green

$staleItems = @(
    "$ClaudeDir\skills-old",
    "$ClaudeDir\.stversions",
    "$ClaudeDir\.stignore",
    "$ClaudeDir\.stfolder",
    "$ClaudeDir\claude-config"
)

foreach ($path in $staleItems) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Host "  Removed: $path" -ForegroundColor Yellow
    }
}

# Remove sync conflict files
Get-ChildItem "$ClaudeDir\.credentials.sync-conflict-*" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force
    Write-Host "  Removed: $($_.Name)" -ForegroundColor Yellow
}

# ── 7. Verification ──────────────────────────────────────────────────────

Write-Host "`n[7/7] Verification" -ForegroundColor Green

$checks = @(
    @{ Name = "Junction ~/.claude";    Path = $UserClaude;     Type = "Junction" },
    @{ Name = "Symlink CLAUDE.md";     Path = "$ClaudeDir\CLAUDE.md"; Type = "SymbolicLink" },
    @{ Name = "Symlink settings.json"; Path = "$ClaudeDir\settings.json"; Type = "SymbolicLink" },
    @{ Name = "Symlink behavioral-reminders.txt"; Path = "$ClaudeDir\behavioral-reminders.txt"; Type = "SymbolicLink" },
    @{ Name = "Symlink skills";        Path = "$ClaudeDir\skills"; Type = "SymbolicLink" }
)

$allGood = $true
foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        $item = Get-Item $c.Path -Force
        if ($item.LinkType -eq $c.Type -or ($c.Type -eq "SymbolicLink" -and $item.LinkType -eq "Junction")) {
            Write-Host "  OK: $($c.Name)" -ForegroundColor Green
        } else {
            Write-Host "  WARN: $($c.Name) is $($item.LinkType), expected $($c.Type)" -ForegroundColor Red
            $allGood = $false
        }
    } else {
        Write-Host "  MISSING: $($c.Name) at $($c.Path)" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
if ($allGood) {
    Write-Host "=== Setup complete! ===" -ForegroundColor Cyan
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Run 'claude login' if this is a new machine" -ForegroundColor White
    Write-Host "  2. Start Claude Code and verify hooks fire" -ForegroundColor White
    Write-Host "  3. Restart Claude Desktop and verify gateway connects" -ForegroundColor White
} else {
    Write-Host "=== Setup completed with warnings. Review above. ===" -ForegroundColor Yellow
}
