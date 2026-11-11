Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })
Set-Alias ls eza
function lt { eza --tree @args }
function ff { fastfetch -c "$HOME\.config\fastfetch\config.jsonc" @args }

# show fastfetch when a new terminal opens
ff
