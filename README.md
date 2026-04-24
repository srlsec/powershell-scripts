# powershell-scripts
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 
```
### Check System Info
```
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
