<#   
    .SYNOPSIS
    Monitors VMWare VM Status for example VMware Tools, Heartbeat, CDDrive Connected or Overall State

    .DESCRIPTION
    Using VMware PowerCLI this Script checks VM Status
    Exceptions can be made within this script by changing the variable $IgnorePattern. This way, the change applies to all PRTG sensors 
    based on this script. If exceptions have to be made on a per sensor level, the script parameter VMIgnorePattern or AlarmIgnorePattern can be used.

    Copy this script to the PRTG probe EXEXML scripts folder (${env:ProgramFiles(x86)}\PRTG Network Monitor\Custom Sensors\EXEXML)
    and create a "EXE/Script Advanced. Choose this script from the dropdown and set at least:

    + Parameters: VCenter, Username, Password
    + Scanning Interval: minimum 5 minutes

    .PARAMETER ViServer
    The Hostname of the VCenter Server

    .PARAMETER UserName
    Provide the VCenter Username

    .PARAMETER Password
    Provide the VCenter Password

    .PARAMETER ExcludeVMName
    Regular expression to describe the VM Name to Ignore Alerts and Warnings from.

    Example1: ^(Test123|VM3)$ excludes Test123 and VM3

    Example2: ^(Test123.*|VM3)$ excluded Test123* (also Test123-somename) and VM3

    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1
    
    .PARAMETER ExcludeFolder
    Regular expression to exclude vmware folder

    .PARAMETER ExcludeFolder
    Regular expression to exclude vmware folder

    .PARAMETER ExcludeRessource
    Regular expression to exclude vmware ressource

    .PARAMETER ExcludeVM_VMTools
    Regular expression to exclude a vm by name from this kind of check

    .PARAMETER ExcludeVM_VMHeartbeat
    Regular expression to exclude a vm by name from this kind of check

    .PARAMETER ExcludeVM_VMStatus
    Regular expression to exclude a vm by name from this kind of check

    .PARAMETER ExcludeVM_VMCDConnected
    Regular expression to exclude a vm by name from this kind of check

    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    "PRTG-VMware-Status.ps1" -ViServer "YourVcenter" -User "YourUser" -Password "YourPassword"

    .NOTES
    This script is based on the sample by Paessler (https://kb.paessler.com/en/topic/70174-monitor-vcenter)

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-VMware-Status

#>
param(
    [string] $ViServer = "",
    [string] $User = "",
    [string] $Password = '',
    [string] $ExcludeVMName = '',
    [string] $ExcludeFolder = '',
    [string] $ExcludeRessource = '',
    [string] $ExcludeVMHost = '',
    [string] $ExcludeVM_VMTools = '',
    [string] $ExcludeVM_VMHeartbeat = '',
    [string] $ExcludeVM_VMStatus = '',
    [string] $ExcludeVM_VMCDConnected = '',
    [string] $IncludeVMName = '',
    [string] $IncludeFolder = '',
    [string] $IncludeRessource = '',
    [string] $IncludeVMHost = '',
    [string] $IncludeVM_VMTools = '',
    [string] $IncludeVM_VMHeartbeat = '',
    [string] $IncludeVM_VMStatus = '',
    [string] $IncludeVM_VMCDConnected = '',
    [switch] $HideVMTools = $False,
    [switch] $HideVMHeartbeat = $False,
    [switch] $HideVMStatus = $False,
    [switch] $HideVMCDConnected = $False,
    [switch] $HideStoragePath = $False
)

#Catch all unhandled Errors
trap {
    if ($connected) {
        $null = Disconnect-VIServer -Server $ViServer -Confirm:$false -ErrorAction SilentlyContinue
    }
    $Output = "line:$($_.InvocationInfo.ScriptLineNumber.ToString()) char:$($_.InvocationInfo.OffsetInLine.ToString()) --- message: $($_.Exception.Message.ToString()) --- line: $($_.InvocationInfo.Line.ToString()) "
    $Output = $Output.Replace("<", "")
    $Output = $Output.Replace(">", "")
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$Output</text>"
    Write-Output "</prtg>"
    Exit
}

#https://stackoverflow.com/questions/19055924/how-to-launch-64-bit-powershell-from-32-bit-cmd-exe
#############################################################################
#If Powershell is running the 32-bit version on a 64-bit machine, we 
#need to force powershell to run in 64-bit mode .
#############################################################################
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    if ($myInvocation.Line) {
        [string]$output = &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    }
    else {
        [string]$output = &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    }

    #Remove any text after </prtg>
    try {
        $output = $output.Substring(0, $output.LastIndexOf("</prtg>") + 7)
    }

    catch {
    }

    Write-Output $output
    exit
}

#############################################################################
#End
#############################################################################    

$connected = $false

# Error if there's anything going on
$ErrorActionPreference = "Stop"


# Import VMware PowerCLI module
try {
    Import-Module "VMware.VimAutomation.Core" -ErrorAction Stop
}
catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Error Loading VMware Powershell Module ($($_.Exception.Message))</text>"
    Write-Output "</prtg>"
    Exit
}

# PowerCLI Configuration Settings
try {
    #Ignore certificate warnings
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Scope User -Confirm:$false | Out-Null

    #Disable CEIP
    Set-PowerCLIConfiguration -ParticipateInCeip $false -Scope User -Confirm:$false | Out-Null
}

catch {
    Write-Host "Error in Set-PowerCLIConfiguration but we will ignore it." #Error when another Script is currently accessing it.
}

# Connect to vCenter
try {
    Connect-VIServer -Server $ViServer -User $User -Password $Password
            
    $connected = $true
}
 
catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Could not connect to vCenter server $ViServer. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
}

#Get List of all VMs
try {
    $VMs = Get-VM -ErrorAction Stop

}
catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Could not Get-VM. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
}


#Count before Filter
$PoweredOnVMs = ($VMs | Where-Object { $_.PowerState -eq "PoweredOn" }).Count
$PoweredOffVMs = ($VMs | Where-Object { $_.PowerState -eq "PoweredOff" }).Count
$CountVMs = $VMs.Count

# Region: VM Filter (Include/Exclude)
# hardcoded list that applies to all hosts
$ExcludeVMNameScript = '^(TestIgnore)$' 
$IncludeVMNameScript = ''

#VM Name
if ($ExcludeVMName -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -notmatch $ExcludeVMName }  
}

if ($ExcludeVMNameScript -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -notmatch $ExcludeVMNameScript }  
}

if ($IncludeVMName -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -match $IncludeVMName }  
}

if ($IncludeVMNameScript -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -match $IncludeVMNameScript }  
}

#VM Folder
if ($ExcludeFolder -ne "") {
    $VMs = $VMs | Where-Object { $_.Folder.Name -notmatch $ExcludeFolder }  
}

if ($IncludeFolder -ne "") {
    $VMs = $VMs | Where-Object { $_.Folder.Name -match $IncludeFolder }  
}

#VM Resource
if ($ExcludeRessource -ne "") {
    $VMs = $VMs | Where-Object { $_.ResourcePool.Name -notmatch $ExcludeRessource }  
}

if ($IncludeRessource -ne "") {
    $VMs = $VMs | Where-Object { $_.ResourcePool.Name -match $IncludeRessource }  
}

#VM Host
if ($ExcludeVMHost -ne "") {
    $VMs = $VMs | Where-Object { $_.VMHost.Name -notmatch $ExcludeVMHost }  
}

if ($IncludeVMHost -ne "") {
    $VMs = $VMs | Where-Object { $_.VMHost.Name -match $IncludeVMHost }  
}
#End Region VM Filter

#Count VMs
$CDConnected = New-Object System.Collections.ArrayList
$ToolsStatusNotOK = New-Object System.Collections.ArrayList
$heartbeatfail = New-Object System.Collections.ArrayList
$heartbeatok = New-Object System.Collections.ArrayList
$overallok = New-Object System.Collections.ArrayList
$overallfail = New-Object System.Collections.ArrayList
$StoragePathFail = New-Object System.Collections.ArrayList

#Text Messages
$CDConnected_Text = "VMs with CD: "
$ToolsStatusNotOK_Text = "VMTools Problems: "
$HeaertbeatFail_Text = "Heartbeat Failed: "
$OverAllFail_Text = "Overall Status Failed: "
$StoragePath_Text = "Storage Paths: "

Foreach ($VM in $VMs) {
    #only check online VMs
    if ($VM.PowerState -eq "PoweredOn") {
        #CD Drive connected
        if (-not $HideVMCDConnected) {
            $exclude = $false
            if (($ExcludeVM_VMCDConnected -ne "") -and ($ExcludeVM_VMCDConnected -ne $null)) {
                if ($VM.name -match $ExcludeVM_VMCDConnected) {
                    $exlude = $true
                }
            }
            if (($IncludeVM_VMCDConnected -ne "") -and ($IncludeVM_VMCDConnected -ne $null)) {
                if ($VM.name -notmatch $IncludeVM_VMCDConnected) {
                    $exlude = $true
                }
            }

            if (-not $exclude) {
                If ((Get-CDDrive -VM $VM).ConnectionState.Connected -eq "True") {
                    $null = $CDConnected.Add($VM)
                    $CDConnected_Text += "$($VM.Name); "
                }
            }
        }

        #VMWare Tools status
        if (-not $HideVMTools) {
            $exclude = $false
            if (($ExcludeVM_VMTools -ne "") -and ($ExcludeVM_VMTools -ne $null)) {
                if ($VM.name -match $ExcludeVM_VMTools) {
                    $exlude = $true
                }
            }
            if (($IncludeVM_VMTools -ne "") -and ($IncludeVM_VMTools -ne $null)) {
                if ($VM.name -notmatch $IncludeVM_VMTools) {
                    $exlude = $true
                }
            }

            if (-not $exclude) {
                $toolsStatus = (Get-View -VIObject $VM).Guest.ToolsStatus
                If ($toolsStatus -ne "toolsOk") {
                    $null = $ToolsStatusNotOK.Add($VM)
                    $ToolsStatusNotOK_Text += "$($VM.Name)=$($toolsStatus); "
                }
            }
        }
        
        #Heartbeat status
        if (-not $HideVMHeartbeat) {
            $exclude = $false
            if (($ExcludeVM_VMHeartbeat -ne "") -and ($ExcludeVM_VMHeartbeat -ne $null)) {
                if ($VM.name -match $ExcludeVM_VMHeartbeat) {
                    $exlude = $true
                }
            }
            if (($IncludeVM_VMHeartbeat -ne "") -and ($IncludeVM_VMHeartbeat -ne $null)) {
                if ($VM.name -notmatch $IncludeVM_VMHeartbeat) {
                    $exlude = $true
                }
            }

            if (-not $exclude) {
                $heartbeatstatus = $VM.ExtensionData.GuestHeartbeatStatus
                if (($heartbeatstatus -ne "green") -and ($heartbeatstatus -ne "gray")) {
                    $null = $heartbeatfail.Add($VM)
                    $HeaertbeatFail_Text += "$($VM.Name)=$($heartbeatstatus); "
                }  
                else {
                    $null = $heartbeatok.Add($VM)
                }
            }
        }

        #Overall status
        if (-not $HideVMStatus) {
            $exclude = $false
            if (($ExcludeVM_VMStatus -ne "") -and ($ExcludeVM_VMStatus -ne $null)) {
                if ($VM.name -match $ExcludeVM_VMStatus) {
                    $exlude = $true
                }
            }
            if (($IncludeVM_VMStatus -ne "") -and ($IncludeVM_VMStatus -ne $null)) {
                if ($VM.name -notmatch $IncludeVM_VMStatus) {
                    $exlude = $true
                }
            }

            if (-not $exclude) {
                $OverallStatus = $VM.ExtensionData.OverallStatus
                if ($OverallStatus -eq "green") {
                    $null = $overallok.Add($VM)
                }  
                else {
                    $null = $overallfail.Add($VM)
                    $OverAllFail_Text += "$($VM.Name)=$($OverallStatus); "
                }
            }
        }
    }
}

## Storage Path Monitoring
if (-not $HideStoragePath) {
    $EXHosts = Get-VMHost 
    foreach ($EXHost in $EXHosts) {
        $HBAs = Get-VMHostHba -VMHost $EXHost -Type "FibreChannel" | Where-Object { $_.status -ne "online" }
        foreach ($HBA in $HBAs) {
            $null = $StoragePathFail.Add($HBA) 
            $StoragePath_Text += "$($EXHost.name) HBA $($HBA.device) is $($HBA.status); "
        }
    }
}


$xmlOutput = '<prtg>'


# Output Text
$OutputText = ""

if (-not $HideVMCDConnected) {
    if ($CDConnected.Count -gt 0) {
        $OutputText += "$($CDConnected_Text) ##"
    }
}

if (-not $HideVMTools) {
    if ($ToolsStatusNotOK.Count -gt 0) {
        $OutputText += "$($ToolsStatusNotOK_Text) ##"
    }
}

if (-not $HideVMHeartbeat) {
    if ($heartbeatfail.Count -gt 0) {
        $OutputText += "$($HeaertbeatFail_Text) ##"
    }
}


if (-not $HideVMStatus) {
    if ($overallfail.Count -gt 0) {
        $OutputText += "$($OverAllFail_Text) ##"
    }
}

if (-not $HideStoragePath) {
    if ($StoragePathFail.Count -gt 0) {
        $OutputText += "$($StoragePath_Text) ##"
    }
}



#Text exists = problems found
if ($OutputText -ne "") {
    $xmlOutput = $xmlOutput + "<text>$OutputText</text>"
}

else {
    $xmlOutput = $xmlOutput + "<text>No problems found</text>"
}

# Disconnect from vCenter
Disconnect-VIServer -Server $ViServer -Confirm:$false

$connected = $false

$xmlOutput = $xmlOutput + "<result>
        <channel>VMs Total</channel>
        <value>$CountVMs</value>
        <unit>Count</unit>
        </result>"
        
if (-not $HideVMHeartbeat) {
    $xmlOutput = $xmlOutput + "<result>
            <channel>VMs Heartbeat OK</channel>
            <value>$($heartbeatok.Count)</value>
            <unit>Count</unit>
            </result>

            <result>
            <channel>VMs Heartbeat Failed</channel>
            <value>$($heartbeatfail.Count)</value>
            <unit>Count</unit>
            <limitmode>1</limitmode>
            <LimitMaxError>0.1</LimitMaxError>
            </result>"
}

if (-not $HideVMStatus) {
    $xmlOutput = $xmlOutput + "<result>
            <channel>VMs Status OK</channel>
            <value>$($overallok.Count)</value>
            <unit>Count</unit>
            </result>

            <result>
            <channel>VMs Status Failed</channel>
            <value>$($overallfail.Count)</value>
            <unit>Count</unit>
            <limitmode>1</limitmode>
            <LimitMaxError>0.1</LimitMaxError>
            </result>" 
}
        
if (-not $HideVMCDConnected) {
    $xmlOutput = $xmlOutput + "<result>
            <channel>VMs with CD Connected</channel>
            <value>$($CDConnected.Count)</value>
            <unit>Count</unit>
            <limitmode>1</limitmode>
            <LimitMaxWarning>0.1</LimitMaxWarning>
            </result>"
}

if (-not $HideVMTools) {
    $xmlOutput = $xmlOutput + "<result>
            <channel>Tools old or not running</channel>
            <value>$($ToolsStatusNotOK.Count)</value>
            <unit>Count</unit>
            <limitmode>1</limitmode>
            <LimitMaxWarning>0.1</LimitMaxWarning>
            </result>"   
}

        
if (-not $HideStoragePath) {
    $xmlOutput = $xmlOutput + "<result>
            <channel>Storage Path Failed</channel>
            <value>$($StoragePathFail.Count)</value>
            <unit>Count</unit>
            <limitmode>1</limitmode>
            <LimitMaxWarning>0.1</LimitMaxWarning>
            </result>"
}
        

$xmlOutput = $xmlOutput + "<result>
        <channel>VMs PoweredOff</channel>
        <value>$($PoweredOffVMs)</value>
        <unit>Count</unit>
        </result>
        
        <result>
        <channel>VMs PoweredOn</channel>
        <value>$($PoweredOnVMs)</value>
        <unit>Count</unit>
        </result>"   
        


$xmlOutput = $xmlOutput + "</prtg>"

Write-Output $xmlOutput
