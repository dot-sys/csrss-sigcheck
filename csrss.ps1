#MIT License
#Copyright (c) 2024 dot-sys


$csrsspath = "C:\temp\dump\csrss"
New-Item -Path "$csrsspath" -ItemType Directory -Force | Out-Null
Set-Location $csrsspath

function Confirm-Setup {
    Clear-Host
    $confirmation = Read-Host "Download System-Informer and dump both csrss. Put them exactly like this:`nC:\temp\dump\csrss\csrss.txt`nC:\temp\dump\csrss\csrss2.txt`nIf the files are correctly named and in the correct directory, press Y"

    if ($confirmation -ne 'Y') {
        Write-Host "Aborting script."
        exit
    }

    $doubleCheck = Read-Host "Are you sure everything is setup correctly? Press Y to continue or N to abort"

    if ($doubleCheck -ne 'Y') {
        Write-Host "Aborting script."
        exit
    }
}

Confirm-Setup

Clear-Host
Write-Host "`n`n`n   Script is running. This takes about 2 Minutes`n`n`n" -ForegroundColor Yellow

$csrss_filePath1 = "$csrsspath\csrss.txt"
$csrss_filePath2 = "$csrsspath\csrss2.txt"

if (-not (Test-Path $csrss_filePath1) -or -not (Test-Path $csrss_filePath2)) {
    Write-Host "One or both of the required files are missing. Aborting script."
    exit
}

$csrss_patterns = @{
    exe       = "^[A-Za-z]:\\.+\.exe$"
    dll       = "^[A-Za-z]:\\.+\.dll$"
    unmatched = "^[\\?]{2}.*\.(dll|exe)$"
}

$csrss_content = Get-Content $csrss_filePath1, $csrss_filePath2

$csrss_paths = @{
    exe       = @()
    dll       = @()
    unmatched = @()
}

foreach ($line in $csrss_content) {
    if ($line -match ":\s*(.*\.(dll|exe))") {
        $csrss_path = $matches[1]
        switch -Wildcard ($csrss_path) {
            {$csrss_path -match $csrss_patterns.exe}       { $csrss_paths.exe += $csrss_path }
            {$csrss_path -match $csrss_patterns.dll}       { $csrss_paths.dll += $csrss_path }
            {$csrss_path -match $csrss_patterns.unmatched} { $csrss_paths.unmatched += $csrss_path }
        }
    }
}

function Validating {
    param ($filePath)
    try { return (Get-AuthenticodeSignature -FilePath $filePath).Status -eq 'Valid' } catch { $false }
}

$csrss_signed = @()
$csrss_unsigned = @()
$csrss_deleted = @()

foreach ($csrss_path in $csrss_paths.exe + $csrss_paths.dll) {
    if (Test-Path $csrss_path) {
        if (Validating $csrss_path) { $csrss_signed += $csrss_path.ToUpper() }
        else { $csrss_unsigned += $csrss_path.ToUpper() }
    } else { $csrss_deleted += $csrss_path.ToUpper() }
}

$extpathPattern = '(?<=0x[0-9a-f]+ \(\d+\): )(.+)'
$extfilterPattern = '^[A-Z]:\\.*(?<!\.(exe|dll|config|manifest))$'
$extension = $csrss_content | ForEach-Object {
    if ($_ -match $extpathPattern) {
        $matches[1].Trim()
    }
} | Where-Object {
    $_ -match $extfilterPattern -and $_ -notmatch '\\$'
} | Where-Object {
    $path = $_
    if (Test-Path $path) {
        -not (Get-Item $path).PSIsContainer
    } else {
        $true
    }
}

$csrss_signed | Sort-Object | Out-File "$csrsspath\csrss_signed.txt"
$csrss_unsigned | Sort-Object | Out-File "$csrsspath\csrss_unsigned.txt"
$csrss_deleted | Sort-Object | Out-File "$csrsspath\csrss_deleted.txt"
$extension | Sort-Object | Out-File "$csrsspath\csrss_extension.txt"

Clear-Host
Write-Output "`n`n`nDone!`n`n`n"
Invoke-Item "$csrsspath"
