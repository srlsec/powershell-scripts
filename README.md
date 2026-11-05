# Powershell Scripts for Sys Admins
### Powershell policy execution bypass
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 
```
### Check System Info
```
Min
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/sysinfo-min.ps1").Content
Max
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/systeminfo.ps1").Content
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/systeminfo.ps1" -UseBasicParsing).Content
```
### Optimize Windows
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/optimize-windows.ps1").Content
```
### Activate Windows / Office
```
irm https://get.activated.win | iex
```
### Allow insecure guest logons 
```
Powershell run as administrator

Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force
Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
Set-SmbServerConfiguration -RequireSecuritySignature $false -Force
```
#### Install MS365
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-MS365.ps1").Content
```

### Install AnyDesk
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-AnyDesk.ps1").Content
```

### Install UltraViewer
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-UltraViewer.ps1").Content
```

### Install Rustdesk
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Rustdesk.ps1").Content
```

### Install Quick Heal Internet Security Essentials
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-QuickHeal.ps1").Content
```

### Install Google Chrome
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Chrome.ps1").Content
```

### Install Brave
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Brave.ps1").Content
```

### Install Firefox Browser
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Firefox.ps1").Content
```

### Install Avast Free Antivirus
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Avast.ps1").Content
```

### Install 
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Avast.ps1").Content
```

### Install 
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Avast.ps1").Content
```

### Install 
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Avast.ps1").Content
```

### Install 
```
iex (iwr -Uri "https://raw.githubusercontent.com/srlsec/powershell-scripts/refs/heads/main/scripts/Install-Avast.ps1").Content
```


