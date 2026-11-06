# Escape! launcher for Windows: brings the local copy up to date, then starts the game.
#
# Started by "Play Escape.bat" in the game folder. On every start it:
#   1. looks on GitHub for a newer version of the game and installs it
#      (a git checkout is pulled; any other copy is replaced file by file),
#   2. finds Godot 4.7, or downloads the right version once into .launcher\,
#   3. lets Godot prepare (import) the new files and starts the game.
# Without an internet connection the game simply starts as it is.
# Saved games live in Godot's user folder (%APPDATA%\Godot\app_userdata\Escape!) and are never touched.
#
# Switches: -NoUpdate (start without looking for updates), -Editor (open the Godot editor instead).

param(
	[string]$GameDir = "",
	[switch]$NoUpdate,
	[switch]$Editor
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is many times slower with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = "devilbane/escape"
$Branch = "main"
$FallbackGodotVersion = "4.7.2"

if ($GameDir -eq "") { $GameDir = Join-Path $PSScriptRoot "..\.." }
$GameDir = [IO.Path]::GetFullPath($GameDir).TrimEnd("\")
$State = Join-Path $GameDir ".launcher"
New-Item -ItemType Directory -Force -Path $State | Out-Null

function Say([string]$text, [string]$colour = "Gray") { Write-Host $text -ForegroundColor $colour }

function Get-Text([string]$url) {
	return (Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ "User-Agent" = "escape-launcher" } -TimeoutSec 20).Content
}

function Get-File([string]$url, [string]$target) {
	Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $target -Headers @{ "User-Agent" = "escape-launcher" }
}

# --- 1. Updates ---------------------------------------------------------------

function Find-Git {
	$cmd = Get-Command git -ErrorAction SilentlyContinue
	if ($cmd) { return $cmd.Source }
	# GitHub Desktop brings its own git without putting it on the PATH.
	$desktop = Get-ChildItem -Path "$env:LOCALAPPDATA\GitHubDesktop" -Filter git.exe -Recurse -ErrorAction SilentlyContinue |
		Where-Object { $_.FullName -like "*\cmd\git.exe" } | Sort-Object FullName -Descending | Select-Object -First 1
	if ($desktop) { return $desktop.FullName }
	return $null
}

function Update-WithGit([string]$Git) {
	# A git checkout: fast-forward it, but never throw away the player's own changes.
	$current = (& $Git -C $GameDir rev-parse --abbrev-ref HEAD).Trim()
	if ($current -ne $Branch) {
		Say "This copy is on the branch '$current', not '$Branch': no automatic update." "Yellow"
		return $false
	}
	$before = (& $Git -C $GameDir rev-parse HEAD).Trim()
	& $Git -C $GameDir fetch --quiet origin $Branch | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
	$behind = [int](& $Git -C $GameDir rev-list --count "HEAD..origin/$Branch")
	if ($behind -eq 0) { Say "Escape! is up to date." "Green"; return $false }
	Say "Installing $behind new change(s)..." "Cyan"
	& $Git -C $GameDir merge --ff-only --quiet "origin/$Branch" | Out-Null
	if ($LASTEXITCODE -ne 0) {
		Say "The update could not be applied: files changed here clash with it (see 'git status')." "Yellow"
		Say "The game starts in its current version." "Yellow"
		return $false
	}
	return ((& $Git -C $GameDir rev-parse HEAD).Trim() -ne $before)
}

function Update-WithDownload {
	# Any other copy (for example a downloaded ZIP): compare with the newest commit on GitHub,
	# download that version and copy it over the game folder.
	$info = Get-Text "https://api.github.com/repos/$Repo/commits/$Branch" | ConvertFrom-Json
	$latest = $info.sha
	$installedFile = Join-Path $State "installed.txt"
	$installed = ""
	if (Test-Path $installedFile) { $installed = (Get-Content $installedFile -Raw).Trim() }
	if ($installed -eq $latest -and (Test-Path (Join-Path $GameDir "project.godot"))) {
		Say "Escape! is up to date." "Green"
		return $false
	}
	if ($installed -eq "") { Say "Downloading Escape!..." "Cyan" } else { Say "Downloading the new version of Escape!..." "Cyan" }

	$work = Join-Path $State "download"
	if (Test-Path $work) { Remove-Item -Recurse -Force $work }
	New-Item -ItemType Directory -Force -Path $work | Out-Null
	$zip = Join-Path $work "escape.zip"
	Get-File "https://codeload.github.com/$Repo/zip/$latest" $zip
	Say "Unpacking..."
	Expand-Archive -Path $zip -DestinationPath $work -Force
	$source = (Get-ChildItem -Directory -LiteralPath $work | Select-Object -First 1).FullName

	# Files that were part of the old version but are gone from the new one are removed,
	# so deleted levels or scripts do not linger. Files the player made themselves stay.
	$newList = Get-ChildItem -Recurse -File -LiteralPath $source | ForEach-Object { $_.FullName.Substring($source.Length + 1) }
	$listFile = Join-Path $State "files.txt"
	if (Test-Path $listFile) {
		$keep = @{}
		foreach ($f in $newList) { $keep[$f.ToLowerInvariant()] = $true }
		foreach ($old in Get-Content $listFile) {
			if ($old -ne "" -and -not $keep.ContainsKey($old.ToLowerInvariant())) {
				$path = Join-Path $GameDir $old
				if (Test-Path $path) { Remove-Item -Force $path }
			}
		}
	}

	# robocopy only copies what changed. ("Play Escape.bat" may be replaced while it runs:
	# it is written so that cmd has already read all of it.)
	robocopy $source $GameDir /E /NFL /NDL /NJH /NJS /NP /R:2 /W:1 | Out-Null
	if ($LASTEXITCODE -ge 8) { throw "copying the new files failed (robocopy $LASTEXITCODE)" }
	$global:LASTEXITCODE = 0

	Set-Content -Path $listFile -Value $newList -Encoding UTF8
	Set-Content -Path $installedFile -Value $latest -Encoding ASCII
	Remove-Item -Recurse -Force $work
	return $true
}

$updated = $false
if (-not $NoUpdate) {
	try {
		if (Test-Path (Join-Path $GameDir ".git")) {
			# A git checkout is only ever updated with git, so its history stays clean.
			$git = Find-Git
			if ($git) {
				$updated = Update-WithGit $git
			} else {
				Say "This copy was cloned with git, but git was not found: no automatic update." "Yellow"
			}
		} else {
			$updated = Update-WithDownload
		}
		if ($updated) { Say "Update installed." "Green" }
	} catch {
		Say "Could not look for updates ($($_.Exception.Message))." "Yellow"
		Say "The game starts in its current version." "Yellow"
	}
}

if (-not (Test-Path (Join-Path $GameDir "project.godot"))) {
	Say "The game files are missing and could not be downloaded. Check the internet connection and try again." "Red"
	exit 1
}

# --- 2. Godot -------------------------------------------------------------------

# The Godot version the game is built with: the same one the browser version uses.
$GodotVersion = $FallbackGodotVersion
$workflow = Join-Path $GameDir ".github\workflows\web.yml"
if (Test-Path $workflow) {
	$m = Select-String -Path $workflow -Pattern "GODOT_VERSION:\s*([0-9.]+)" | Select-Object -First 1
	if ($m) { $GodotVersion = $m.Matches[0].Groups[1].Value }
}
$minor = ($GodotVersion -split "\.")[0..1] -join "."

function Test-Godot([string]$exe) {
	if (-not $exe -or -not (Test-Path $exe)) { return $false }
	if ((Split-Path $exe -Leaf) -like "Godot_v$minor*") { return $true }
	# Any other name (for example a "godot.exe" on the PATH): ask it for its version.
	$probe = $exe -replace "\.exe$", "_console.exe"
	if (-not (Test-Path $probe)) { $probe = $exe }
	try {
		$v = (& $probe --version 2>$null | Select-Object -First 1)
		return ("$v" -like "$minor*")
	} catch { return $false }
}

function Find-Godot {
	# The console build is used for the import step (it waits and shows output), the normal one to play.
	$candidates = @()
	if ($env:GODOT) { $candidates += $env:GODOT }
	$candidates += Get-ChildItem -Path (Join-Path $State "godot") -Filter "Godot_v*_win64.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
	$cmd = Get-Command godot -ErrorAction SilentlyContinue
	if ($cmd) { $candidates += $cmd.Source }
	foreach ($dir in @($GameDir, (Split-Path $GameDir), "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "$env:LOCALAPPDATA\Programs")) {
		$candidates += Get-ChildItem -Path $dir -Filter "Godot_v$minor*win64.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
			Sort-Object Name -Descending | ForEach-Object { $_.FullName }
	}
	foreach ($c in $candidates) {
		if ($c -like "*_console.exe") { $c = $c -replace "_console\.exe$", ".exe" }
		if (Test-Godot $c) { return $c }
	}
	return $null
}

$godot = Find-Godot
if (-not $godot) {
	Say "Godot $GodotVersion is needed to run the game. Downloading it once (about 70 MB)..." "Cyan"
	try {
		$dir = Join-Path $State "godot"
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
		$zip = Join-Path $dir "godot.zip"
		Get-File "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable/Godot_v$GodotVersion-stable_win64.exe.zip" $zip
		Expand-Archive -Path $zip -DestinationPath $dir -Force
		Remove-Item -Force $zip
		$godot = Join-Path $dir "Godot_v$GodotVersion-stable_win64.exe"
	} catch {
		Say "Godot could not be downloaded ($($_.Exception.Message))." "Red"
		Say "Install Godot $GodotVersion from https://godotengine.org/download/ and start this file again." "Red"
		exit 1
	}
}
$console = $godot -replace "\.exe$", "_console.exe"
if (-not (Test-Path $console)) { $console = $godot }

# --- 3. Prepare and start -------------------------------------------------------

if ($updated -or -not (Test-Path (Join-Path $GameDir ".godot\imported"))) {
	Say "Preparing the game files (the first start can take a few minutes)..." "Cyan"
	$p = Start-Process -FilePath $console -ArgumentList @("--headless", "--path", "`"$GameDir`"", "--import") -NoNewWindow -Wait -PassThru
	if ($p.ExitCode -ne 0) { Say "Godot reported a problem while preparing the files; trying to start anyway." "Yellow" }
}

if ($Editor) {
	Say "Opening the Godot editor..." "Green"
	Start-Process -FilePath $godot -ArgumentList @("--editor", "--path", "`"$GameDir`"")
} else {
	Say "Starting Escape!..." "Green"
	Start-Process -FilePath $godot -ArgumentList @("--path", "`"$GameDir`"")
}
exit 0
