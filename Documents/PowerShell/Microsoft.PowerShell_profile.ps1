# ~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1 - pwsh 7 equivalent of ~/.zshrc

# --- environment (the ~/.zprofile part) ---
$env:EDITOR = 'nvim'

# --- PSReadLine: zsh-style editing ---
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView   # autosuggestions
Set-PSReadLineOption -MaximumHistoryCount 10000 -HistoryNoDuplicates
Set-PSReadLineOption -AddToHistoryHandler { param($line) $line -notmatch '^\s' } # leading space = not saved
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# --- auto cd: type a folder name to cd into it ---
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($name, $e)
    if (Test-Path -LiteralPath $name -PathType Container) {
        $e.CommandScriptBlock = { Set-Location -LiteralPath $name }.GetNewClosure()
        $e.StopSearch = $true
    }
}

# --- aliases ---
Remove-Item Alias:ls, Alias:clear -Force -ErrorAction SilentlyContinue
function ls { eza -lah --git --color=auto @args }
function lt { eza --tree -a --color=auto @args }
Set-Alias df duf
function ff {
    $env:OS_AGE_DAYS = ((Get-Date) - (Get-Item C:\).CreationTime).Days
    fastfetch -c "$HOME\.config\fastfetch\config.jsonc" @args
}
function clear { Clear-Host; [Console]::Write("`e[3J"); ff }

# --- init script cache ---
# Generated init/completion scripts are saved to ~\.cache\pwsh and only regenerated when the
# tool is updated. Returns the cache path, or nothing if the tool isn't installed.
function Get-InitCache($tool, [scriptblock]$generate) {
    $exe = (Get-Command $tool -ErrorAction SilentlyContinue).Source
    if (-not $exe) { return }
    $file = "$HOME\.cache\pwsh\$tool-init.ps1"
    # Scoop shim exes keep a fixed timestamp; the .shim next to them is rewritten on each update
    $stamp = [IO.Path]::ChangeExtension($exe, 'shim')
    if (-not (Test-Path $stamp)) { $stamp = $exe }
    if (-not (Test-Path $file) -or (Get-Item $stamp).LastWriteTime -gt (Get-Item $file).LastWriteTime) {
        New-Item -ItemType Directory (Split-Path $file) -Force | Out-Null
        & $generate | Set-Content $file
    }
    $file
}

# --- integrations ---
# dot-sourced here (not inside a function) so what they define stays in the session
if ($f = Get-InitCache starship { starship init powershell --print-full-init }) { . $f }
if ($f = Get-InitCache zoxide   { zoxide init powershell }) { . $f }

# --- completions (the compinit part) ---
if ($f = Get-InitCache gh      { gh completion -s powershell }) { . $f }
if ($f = Get-InitCache chezmoi { chezmoi completion powershell }) { . $f }
if ($f = Get-InitCache rustup  { rustup completions powershell }) { . $f }
if ($f = Get-InitCache rg      { rg --generate complete-powershell }) { . $f }
if ($f = Get-InitCache fd      { fd --gen-completions powershell }) { . $f }
Remove-Variable f

# --- fzf: PSFzf loads on first Ctrl+R / Ctrl+T instead of at startup ---
function Enable-PSFzf {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock { Enable-PSFzf; Invoke-FzfPsReadlineHandlerHistory }
Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock { Enable-PSFzf; Invoke-FzfPsReadlineHandlerProvider }

# --- startup ---
ff
