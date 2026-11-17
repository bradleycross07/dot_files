# powershell config

# --- environment ---
$env:EDITOR = 'nvim'
$env:BAT_CONFIG_PATH = "$HOME\.config\bat\config"

# --- zsh-style editing ---
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView   # autosuggestions
Set-PSReadLineOption -MaximumHistoryCount 10000 -HistoryNoDuplicates
Set-PSReadLineOption -AddToHistoryHandler { param($line) $line -notmatch '^\s' } # leading space = not saved
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# --- auto cd ---
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

# --- init script cache ---
# generated init/completion scripts are saved to ~\.cache\pwsh
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
if ($f = Get-InitCache starship { starship init powershell --print-full-init }) { . $f }

# --- completions (loaded on first Tab, not at startup) ---
$global:LazyCompletions = @{
    gh      = { gh completion -s powershell }
    chezmoi = { chezmoi completion powershell }
    rustup  = { rustup completions powershell }
    rg      = { rg --generate complete-powershell }
    fd      = { fd --gen-completions powershell }
}
foreach ($name in $LazyCompletions.Keys) {
    Register-ArgumentCompleter -Native -CommandName $name -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $tool = $commandAst.GetCommandName()
        if (-not ($file = Get-InitCache $tool $global:LazyCompletions[$tool])) { return }
        # load as a global module so the script's helper functions stay available
        New-Module -Name "$tool-completion" -ScriptBlock ([scriptblock]::Create((Get-Content -Raw $file))) | Import-Module -Global
        # the real completer has replaced this one; ask it for this Tab press
        (TabExpansion2 -inputScript $commandAst.Extent.Text -cursorColumn ($cursorPosition - $commandAst.Extent.StartOffset)).CompletionMatches
    }
}
Remove-Variable f, name

# --- fzf ---
function Enable-PSFzf {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock { Enable-PSFzf; Invoke-FzfPsReadlineHandlerHistory }
Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock { Enable-PSFzf; Invoke-FzfPsReadlineHandlerProvider }
