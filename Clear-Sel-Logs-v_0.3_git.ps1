#Requires -Modules Posh-SSH

<#
.Synopsis
  Clear SEL LOGS from UCS Blade Servers
.DESCRIPTION
   Clear SEL LOGS from UCS Blade Servers through SSH connection on ESXI Hosts
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet

Based on the script posted byt Jonathon Harper in:

#https://blog.jonathonharper.com/2017/05/19/clear-sel-logs-for-esxi-hosts/

Pre requirements

#Install Posh-SSH Module on Powershell

#Instal PowerCli version 11 or superior

CHANGED BY:
.AUTHOR
   Juliano Alves de Brito Ribeiro (Find me at: julianoalvesbr@live.com or https://github.com/JULIANOABR or https://twitter.com/powershell_tips)
.VERSION
   v.0.3
.ENVIRONMENT
   PRODUCTION
.TOTHINK
   JOHN 14.6-7
   Jesus answered, “I am the way and the truth and the life. No one comes to the Father except through me. 
   7 If you really know me, you will know my Father as well. From now on, you do know him and have seen him.”

#>

Clear-Host

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Verbose

Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

#VALIDATE MODULE
$moduleExists = Get-Module -Name Vmware.VimAutomation.Core

if ($moduleExists){
    
    Write-Output "The Module Vmware.VimAutomation.Core is already loaded"
    
}#if validate module
else{
    
    Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
}#else validate module

#Get Encryted Password to Connect to ESXi
$rootUser = "root"

#YOU MUST USE A SCRIPT CALLED ENCRYPT_PWD.ps1 in this repository to encrypt password first. Your encrypted password only work on same machine that you encrypted it.
$MainPWD = (Get-content "$env:SystemDrive:\TEMP\PWD\ENCRYPT\root-encryptedpwd.txt") | ConvertTo-SecureString 

#Root Password = ConvertTo-SecureString -string $encrypted 
$MainCred = New-Object -typename System.Management.Automation.PSCredential -Argumentlist $rootUser,$MainPWD

#Get Encryted Password to Connect to ESXi (alternate credential)

$SecondaryPWD = (Get-content "$env:SystemDrive:\TEMP\PWD\ENCRYPT\alternate_root-encryptedpwd.txt") | ConvertTo-SecureString

#$OnePassword = ConvertTo-SecureString -string $encrypted 
$SecondaryCred = New-object -typename System.Management.Automation.PSCredential -Argumentlist $rootUser,$SecondaryPWD


#Get Domain User Encrypted Password to Connect to vCenters
$vcUser = "domain\user"

$vcPWD = (Get-content "$env:SystemDrive:\TEMP\PWD\ENCRYPT\domain-pwd-encryptedpwd.txt") | ConvertTo-SecureString

#vCenter Password = ConvertTo-SecureString -string $encrypted 
$vCenterCred = New-Object -typename System.Management.Automation.PSCredential -Argumentlist $vCUser,$vCPWD

#DEFINE vCENTER LIST
$vcServerList = @()

#ADD OR REMOVE vCenter Servers according to your environment   
$vcServerList = ('SERVER1','SERVER2','SERVER3','SERVER4','SERVER5','SERVER6','SERVER7') | Sort-Object


foreach ($vCServerName in $vCServerList)
{
    
    Connect-VIServer -Server $vCServerName -Port 443 -Credential $vCenterCred -Verbose 

    $esxiHostList = @()

    $esxiHostList = Get-VMHost -State Connected | Select-Object -ExpandProperty Name | Sort-Object


    foreach ($esxiHostName in $esxiHostList)
    {
           
     $esxiHostObj = Get-VMHost -Name $esxiHostName -Verbose

     $error.Clear()

     $manufacturer = $esxiHostObj.Manufacturer

         if ($manufacturer -like 'Cisco*'){
     
            $mgmtInterface = $esxiHostObj.NetworkInfo.VirtualNic | Where-Object -FilterScript {$_.Name -eq "vmk0"}       
            
            $mgmtInterfaceIP = $mgmtInterface.IP

            $sshServiceStatus = Get-VmHostService -VMHost $esxiHostObj | Where { $_.Key -eq “TSM-SSH”}

            if ($sshServiceStatus.Running -eq $true){
                
                    Write-Host ("Host: $esxiHostName. SSH Service is already running") -ForegroundColor White -BackgroundColor DarkCyan

                    $sshSessionStatus = Get-SSHSession -ComputerName $mgmtInterface
                    
                    if ($sshSessionStatus -eq $null){
                        
                        Write-Host "Trying to connect with Main Credential" -ForegroundColor White -BackgroundColor DarkBlue

                        New-SSHSession -ComputerName $mgmtInterfaceIP -AcceptKey -ConnectionTimeout 300 -Credential $MainCred -Verbose -ErrorAction SilentlyContinue
                                                   
                        if ($error[0]){
                            
                            $error.Clear()

                            Write-Host "Trying to connect with Secondary Credential" -ForegroundColor White -BackgroundColor DarkBlue

                            New-SSHSession -ComputerName $mgmtInterfaceIP -AcceptKey -ConnectionTimeout 300 -Credential $SecondaryCred -Verbose -ErrorAction SilentlyContinue

                                if ($error[0]){
                                
                                    Write-Host "I couldn't connect with Main Credential ou Secondary Credential. Try another one" -ForegroundColor White -BackgroundColor Red -Verbose                                
                                
                                }#end of IF try to connect with alternate credential
                                else{
                                
                                    Write-Host "Connected to $esxiHostName" -ForegroundColor White -BackgroundColor DarkBlue
                                
                                    $sshSessionHost = Get-SSHSession -ComputerName $mgmtInterfaceIP -Verbose

                                    [System.Int32]$sshSessionID = $sshSessionHost.SessionID
                                    
                                    Invoke-SSHCommand -SessionId $sshSessionID -Command "localcli hardware ipmi sel clear" -Verbose

                                    [System.Boolean]$sshSessionState = $sshSessionHost.Connected

                                    if ($sshSessionState){
                            
                                        Remove-SSHSession -SessionId $sshSessionID -Verbose

                                    }#valide if ssh connection is connected
                                    else{
                            
                                        Write-Host "I didn't found SSH Session for ESXi Host: $esxiHostName" -ForegroundColor White -BackgroundColor Green                           
                            
                                    }#valide else ssh connection is connected
                                
                               }#end of ELSE try to connect with alternate credential
                                                        
                        }#end of IF ERROR with Main Credential
                        else{
                            
                            Write-Host "Connected to $esxiHostName" -ForegroundColor White -BackgroundColor DarkCyan

                            Invoke-SSHCommand -SessionId 0 -Command "localcli hardware ipmi sel clear" -Verbose

                            $sshSessionHost = Get-SSHSession -ComputerName $mgmtInterfaceIP -Verbose

                            $sshSessionID = $sshSessionHost.SessionID

                            [System.Boolean]$sshSessionState = $sshSessionHost.Connected

                            if ($sshSessionState){
                            
                                Remove-SSHSession -SessionId $sshSessionID -Verbose

                            }#valide if ssh connection is connected
                            else{
                            
                                Write-Host "I didn't found SSH Session for ESXi Host: $esxiHostName" -ForegroundColor White -BackgroundColor Green                           
                            
                            }#valide else ssh connection is connected

                    
                        }#End of ELSE try to connect with main credential
                                     
                    }#validate if session is null
                    else{
                    
                        Write-Host "I found a connection to this Host: $esxiHostName" -ForegroundColor White -BackgroundColor DarkGreen
                    
                    
                    }#validate else session is null

                }#if validate ssh status
            else{
                
                    Start-VMHostService -HostService $sshServiceStatus -Confirm:$false -Verbose
                    
                    Start-Sleep -Seconds 10

                    Write-Host ("Host: $esxiHostName. SSH Service is starting")

                    Write-Host "Trying to connect with Main Credential" -ForegroundColor White -BackgroundColor DarkBlue
                    
                    New-SSHSession -ComputerName $mgmtInterfaceIP -AcceptKey -ConnectionTimeout 300 -Credential $MainCred -Verbose

                    if ($error[0]){
                            
                            $error.Clear()

                            Write-Host "Trying to connect with Secondary Credential" -ForegroundColor White -BackgroundColor DarkBlue

                            New-SSHSession -ComputerName $mgmtInterfaceIP -ConnectionTimeout 300 -AcceptKey -Credential $SecondaryCred -Verbose

                                if ($error[0]){
                                
                                    Write-Host "In Host: $esxiHostName, I couldn't connect with Main Credential ou Secondary Credential. Try another one" -ForegroundColor White -BackgroundColor Red -Verbose                                
                                
                                }#end of IF try to connect with alternate credential
                                else{
                                
                                    Write-Host "Connected to $esxiHostName" -ForegroundColor White -BackgroundColor DarkBlue
                                    
                                    $sshSessionHost = Get-SSHSession -ComputerName $mgmtInterfaceIP -Verbose

                                    [System.Int32]$sshSessionID = $sshSessionHost.SessionID
                                    
                                    Invoke-SSHCommand -SessionId $sshSessionID -Command "localcli hardware ipmi sel clear" -Verbose
                                    
                                    [System.Boolean]$sshSessionState = $sshSessionHost.Connected

                                    if ($sshSessionState){
                            
                                        Remove-SSHSession -SessionId $sshSessionID -Verbose

                                    }#valide if ssh connection is connected
                                    else{
                            
                                        Write-Host "I didn't found SSH Session for ESXi Host: $esxiHostName" -ForegroundColor White -BackgroundColor Green                           
                            
                                    }#valide else ssh connection is connected
                                
                               }#end of ELSE try to connect with alternate credential
                                                        
                        }#end of IF ERROR with Main Credential
                    else{
                            
                            Write-Host "Connected to $esxiHostName" -ForegroundColor White -BackgroundColor DarkCyan

                            $sshSessionHost = Get-SSHSession -ComputerName $mgmtInterfaceIP -Verbose

                            [System.Int32]$sshSessionID = $sshSessionHost.SessionID
                                    
                            Invoke-SSHCommand -SessionId $sshSessionID -Command "localcli hardware ipmi sel clear" -Verbose
                            
                            [System.Boolean]$sshSessionState = $sshSessionHost.Connected

                            if ($sshSessionState){
                            
                                Remove-SSHSession -SessionId $sshSessionID -Verbose

                            }#valide if ssh connection is connected
                            else{
                            
                                Write-Host "I didn't found any SSH Session for ESXi Host: $esxiHostName" -ForegroundColor White -BackgroundColor Green                           
                            
                            }#valide else ssh connection is connected

                    
                        }#End of ELSE try to connect with main credential
                
                }#else validate ssh status
                  
     
         }#end of validate if this Server is a CISCO Systems Inc.
         else{
     
            Write-Host "Host: $esxiHostName. Manufacturer: $manufacturer. It does not have SEL LOGS" -ForegroundColor White -BackgroundColor Red
     
         }#end of else validate it is a CISCO SYSTEMS Inc.
        
    }#End of ForEach Host

}#End of ForEach for vCenter Server

Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue