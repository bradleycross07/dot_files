Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })
Set-Alias ls eza
function lt { eza --tree @args }
function ff {
    $env:OS_AGE_DAYS = ((Get-Date) - (Get-Item C:\).CreationTime).Days
    fastfetch -c "$HOME\.config\fastfetch\config.jsonc" @args
}

# show fastfetch when a new terminal opens
ff
