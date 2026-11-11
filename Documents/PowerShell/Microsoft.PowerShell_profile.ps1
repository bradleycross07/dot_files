Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })
Set-Alias ls eza
function lt { eza --tree @args }
Set-Alias ff fastfetch
