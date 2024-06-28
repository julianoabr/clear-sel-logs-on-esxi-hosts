<#$password = read-host -prompt "Enter your Password"
write-host "$password is password"
$secure = ConvertTo-SecureString $password -force -asPlainText
$bytes = ConvertFrom-SecureString $secure
$bytes | out-file .\securepassword.txt
#>

$fileSuffix = Read-Host -Prompt "Enter File Suffix"

$password = Read-Host -prompt "Enter your Password"

Write-Host "$password is password" -ForegroundColor White -BackgroundColor Red

$secure = ConvertTo-SecureString $password -AsPlainText -Force | ConvertFrom-SecureString | Out-File ".\$fileSuffix-encryptedpwd.txt"



