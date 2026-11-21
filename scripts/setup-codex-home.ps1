<#
.SYNOPSIS
Connect one vault's independent Codex sessions to the current Codex login.
.EXAMPLE
./setup-codex-home.ps1 -Vault 'D:\My notes'
.EXAMPLE
./setup-codex-home.ps1 -Vault 'D:\My notes' -CheckOnly
#>
[CmdletBinding(DefaultParameterSetName = 'Vault')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Vault')][string]$Vault,
    [Parameter(ParameterSetName = 'Vault')][string]$Source,
    [Parameter(Mandatory = $true, ParameterSetName = 'Plan')][string]$Plan,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$setupPlan = $null
$temporaryPlan = $null
$temporaryResult = $null

function Get-FullPath([string]$Value) {
    # Match node:path.resolve, preserving junctions and letter case.
    if ($Value -notmatch '^(?:[A-Za-z]:[\\/]|[\\/]{2})') {
        $Value = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Value)
    }
    # .NET Framework expands existing 8.3 names; Node preserves their spelling.
    if (-not ('InplaceChat.NativePath' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
namespace InplaceChat {
    public static class NativePath {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern uint GetFullPathNameW(string path, uint size, StringBuilder buffer, IntPtr filePart);
    }
}
'@
    }
    $buffer = New-Object Text.StringBuilder 32768
    $length = [InplaceChat.NativePath]::GetFullPathNameW($Value, $buffer.Capacity, $buffer, [IntPtr]::Zero)
    if ($length -eq 0 -or $length -ge $buffer.Capacity) { throw "Cannot resolve Windows path: $Value" }
    $full = $buffer.ToString()
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) { $full = $full.TrimEnd([char[]]'\/') }
    return $full
}

function Test-AuthLink([string]$Link, [string]$Target) {
    $item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    if ($item.LinkType -ne 'SymbolicLink') { throw "Refusing to replace an existing authentication file: $Link" }
    $actual = [string]($item.Target | Select-Object -First 1)
    if (-not [IO.Path]::IsPathRooted($actual)) { $actual = Join-Path (Split-Path -Parent $Link) $actual }
    if ((Get-FullPath $actual) -ne $Target) { throw "Authentication link points to another Codex home: $Link" }
    return $true
}

function Write-SetupResult($Value) {
    if ($setupPlan -and $setupPlan.result) { $Value | ConvertTo-Json | Set-Content -LiteralPath $setupPlan.result -Encoding UTF8 }
}

try {
    if ($PSCmdlet.ParameterSetName -eq 'Plan') {
        $setupPlan = Get-Content -LiteralPath $Plan -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $setupPlan.homes -or -not $setupPlan.result) { throw 'Plan must contain homes and a result file path.' }
    }
    else {
        $vaultPath = Get-FullPath $Vault
        if (-not (Test-Path -LiteralPath $vaultPath -PathType Container)) { throw "Vault folder does not exist: $vaultPath" }
        if (-not $Source) { $Source = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' } }
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $digest = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($vaultPath))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
        $pluginHome = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('.obsidian-inplace-chat\codex\' + $digest.Substring(0, 16))
        $setupPlan = [pscustomobject]@{ homes = @([pscustomobject]@{ vault = $vaultPath; home = $pluginHome; source = (Get-FullPath $Source) }); result = $null }
    }
    $pending = @()
    $normalizedHomes = @()
    foreach ($entry in $setupPlan.homes) {
        if (-not $entry.home -or -not $entry.source) { throw 'Each plan entry must contain home and source paths.' }
        $pluginHome = Get-FullPath $entry.home
        $sourceHome = Get-FullPath $entry.source
        if ($pluginHome -eq $sourceHome) { throw 'Plugin and desktop Codex homes must differ.' }
        $normalizedHomes += [pscustomobject]@{ home = $pluginHome; source = $sourceHome; vault = $entry.vault }
        $auth = Get-Item -LiteralPath (Join-Path $sourceHome 'auth.json') -Force -ErrorAction SilentlyContinue
        if (-not $auth -or $auth.PSIsContainer -or $auth.Length -eq 0) {
            throw "No local Codex login found in $sourceHome. Run codex login first, then run this script again. For a custom CODEX_HOME, pass -Source with that directory."
        }
        foreach ($name in @('auth.json', 'auth.lock')) {
            $link = Join-Path $pluginHome $name
            $target = Join-Path $sourceHome $name
            if (-not (Test-AuthLink $link $target)) { $pending += [pscustomobject]@{ link = $link; target = $target; home = $pluginHome } }
        }
    }
    $setupPlan.homes = @($normalizedHomes)
    if ($setupPlan.result) { $setupPlan.result = Get-FullPath $setupPlan.result }
    if ($CheckOnly) { $setupPlan | ConvertTo-Json -Depth 5; return }
    if ($pending.Count -gt 0) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            # Freeze the original user's paths even if UAC uses another account.
            $temporaryPlan = Join-Path ([IO.Path]::GetTempPath()) ('ipc-codex-setup-' + [guid]::NewGuid().ToString('N') + '.json')
            $temporaryResult = $temporaryPlan + '.result.json'
            [pscustomobject]@{ homes = $setupPlan.homes; result = $temporaryResult } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporaryPlan -Encoding UTF8
            $scriptLiteral = $PSCommandPath.Replace("'", "''")
            $planLiteral = $temporaryPlan.Replace("'", "''")
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("& '$scriptLiteral' -Plan '$planLiteral'"))
            $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            Write-Host 'Windows will request administrator permission once to create two login links. Codex login files and system settings are not changed.'
            try { $child = Start-Process -FilePath $powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) -Verb RunAs -WindowStyle Hidden -Wait -PassThru }
            catch { throw 'Administrator permission was cancelled or unavailable. Run this script again and accept the Windows permission prompt.' }
            if (-not (Test-Path -LiteralPath $temporaryResult -PathType Leaf)) { throw 'The administrator setup did not return a result. Run this script again from a PowerShell window to see the error.' }
            $result = Get-Content -LiteralPath $temporaryResult -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $result.ok -or $child.ExitCode -ne 0) { throw "Administrator setup failed: $($result.error)" }
        }
        else {
            foreach ($item in $pending) {
                [IO.Directory]::CreateDirectory($item.home) | Out-Null
                New-Item -ItemType SymbolicLink -Path $item.link -Target $item.target | Out-Null
            }
        }
    }
    Write-SetupResult @{ ok = $true }
    Write-Host 'Codex login links are ready. Open or reload In-place Chat in this vault.'
}
catch {
    $message = $_.Exception.Message
    Write-SetupResult @{ ok = $false; error = $message }
    [Console]::Error.WriteLine("Codex setup failed: $message")
    exit 1
}
finally {
    foreach ($temporary in @($temporaryPlan, $temporaryResult)) {
        if ($temporary -and (Test-Path -LiteralPath $temporary -PathType Leaf)) { Remove-Item -LiteralPath $temporary -Force }
    }
}
