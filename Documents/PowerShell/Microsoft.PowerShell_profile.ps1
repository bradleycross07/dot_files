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

# --- integrations ---
Invoke-Expression (&starship init powershell)
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# --- startup ---
ff
