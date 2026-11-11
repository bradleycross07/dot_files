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

# --- integrations (init scripts cached; rebuilt when the tool is updated) ---
function Get-InitCache($tool, [scriptblock]$generate) {
    $file = "$HOME\.cache\pwsh\$tool-init.ps1"
    $exe  = (Get-Command $tool -ErrorAction SilentlyContinue).Source
    if ($exe -and (-not (Test-Path $file) -or (Get-Item $exe).LastWriteTime -gt (Get-Item $file).LastWriteTime)) {
        New-Item -ItemType Directory (Split-Path $file) -Force | Out-Null
        & $generate | Set-Content $file
    }
    $file
}
. (Get-InitCache starship { starship init powershell --print-full-init })
. (Get-InitCache zoxide   { zoxide init powershell })

# fzf: PSFzf loads on first Ctrl+R / Ctrl+T instead of at startup
function Enable-PSFzf {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock { Enable-PSFzf; Invoke-FzfPsReadlineHandlerHistory }
Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock { Enable-PSFzf; Invoke-FzfPsReadlineHandlerProvider }

# --- startup ---
ff
