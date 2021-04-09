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

    .PARAMETER IgnorePattern
    Regular expression to describe the VM Name to Ignore Alerts and Warnings from.

    Example: ^(DemoTestServer|DemoAusname2)$

    Example2: ^(Test123.*|TestPrinter555)$ excluded Test12345

    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1
    
    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    PSx64.exe -f="PRTG-VMware-Status.ps1" -p="%VCenter%" "%Username%" "%PW%"

    .NOTES
    This script is based on the sample by Paessler (https://kb.paessler.com/en/topic/70174-monitor-vcenter)

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-VMware-Status

#>
param(
    [string] $ViServer = "",
	[string] $User = "",
	[string] $Password = "",
    [string] $IgnorePattern = ""
)

#Catch all unhandled Errors
trap{
    $null = Disconnect-VIServer -Server $ViServer -Confirm:$false -ErrorAction SilentlyContinue
    Write-Error $_.ToString()
    Write-Error $_.ScriptStackTrace
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>$($_.ToString() - $($_.ScriptStackTrace))</text>"
    Write-Output "</prtg>"
    Exit
}


# Import VMware PowerCLI module
$ViModule = "VMware.VimAutomation.Core"

try {
    Import-Module $ViModule -ErrorAction Stop
} catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Error Loading VMware Powershell Module ($($_.Exception.Message))</text>"
    Write-Output "</prtg>"
    Exit
}

#avoid unecessary output
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP:$false -confirm:$false

# Ignore certificate warnings
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false | Out-Null

# Connect to vCenter
try {
    Connect-VIServer -Server $ViServer -User $User -Password $Password -ErrorAction Stop | Out-Null
} catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Could not connect to vCenter server $ViServer. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
}

#Get List of all VMs
try {
    $VMs = Get-VM -ErrorAction Stop

} catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Could not Get-VM. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
}


#Count before Filter
$PoweredOnVMs = ($VMs | where {$_.PowerState -eq "PoweredOn"}).Count
$PoweredOffVMs = ($VMs | where {$_.PowerState -eq "PoweredOff"}).Count
$CountVMs = $VMs.Count

#Filter VMs

# hardcoded list that applies to all hosts
$IgnoreScript = '^(TestIgnore)$' 

#Remove Ignored VMs
if ($IgnorePattern -ne "") {
    $VMsFilter = $VMs | where {$_.Name -notmatch $IgnorePattern}  
}

if ($IgnoreScript -ne "") {
    $VMs = $VMs | where {$_.Name -notmatch $IgnoreScript}  
}


#Count VMs
$CDConnected = New-Object System.Collections.ArrayList
$ToolsStatusNotOK = New-Object System.Collections.ArrayList
$heartbeatfail = New-Object System.Collections.ArrayList
$heartbeatok = New-Object System.Collections.ArrayList
$overallok = New-Object System.Collections.ArrayList
$overallfail = New-Object System.Collections.ArrayList

#Text Messages
$CDConnected_Text = "VMs with CD: "
$ToolsStatusNotOK_Text = "VMTools Problems: "
$HeaertbeatFail_Text = "Heartbeat Failed: "
$OverAllFail_Text = "Overall Status Failed: "

Foreach ($VM in $VMs)
    {
    #Nur Online VMs prüfen
    if($VM.PowerState -eq "PoweredOn")
        {
        #CD Drive Connected
        If((Get-CDDrive -VM $VM).ConnectionState.Connected -eq"True")
	        {
	        $null = $CDConnected.Add($VM)
            $CDConnected_Text += "$($VM.Name); "
	        }

        #VMWare Tools Status
        $toolsStatus = (Get-View -VIObject $VM).Guest.ToolsStatus
        If($toolsStatus -ne "toolsOk")
	        {
	        $null = $ToolsStatusNotOK.Add($VM)
            $ToolsStatusNotOK_Text += "$($VM.Name)=$($toolsStatus); "
	        }

        #Heartbeat Status
        $heartbeatstatus = $VM.ExtensionData.GuestHeartbeatStatus
        if(($heartbeatstatus -ne "green") -and ($heartbeatstatus -ne "gray"))
            {
            $null = $heartbeatfail.Add($VM)
            $HeaertbeatFail_Text += "$($VM.Name)=$($heartbeatstatus); "
            }  
        else
            {
            $null = $heartbeatok.Add($VM)
            }


        #Overall Status
        $OverallStatus = $VM.ExtensionData.OverallStatus
        if($OverallStatus -eq "green")
            {
            $null = $overallok.Add($VM)
            }  
        else
            {
            $null = $overallfail.Add($VM)
            $OverAllFail_Text += "$($VM.Name)=$($OverallStatus); "
            }
        }
    }



$xmlOutput = '<prtg>'


# Output Text
$OutputText =""

if($CDConnected.Count -gt 0)
    {
    $OutputText += "$($CDConnected_Text) ##"
    }

if($ToolsStatusNotOK.Count -gt 0)
    {
    $OutputText += "$($ToolsStatusNotOK_Text) ##"
    }

if($heartbeatfail.Count -gt 0)
    {
    $OutputText += "$($HeaertbeatFail_Text) ##"
    }

if($overallfail.Count -gt 0)
    {
    $OutputText += "$($OverAllFail_Text) ##"
    }


#Text Exists = Fails Found
if($OutputText -ne "")
    {
    $xmlOutput = $xmlOutput + "<text>$OutputText</text>"
    }

else
    {
    $xmlOutput = $xmlOutput + "<text>No problems found</text>"
    }

# Disconnect from vCenter
Disconnect-VIServer -Server $ViServer -Confirm:$false


$xmlOutput = $xmlOutput + "<result>
        <channel>VMs Total</channel>
        <value>$CountVMs</value>
        <unit>Count</unit>
        </result>
        
        <result>
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
        </result>

        <result>
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
        </result>

        <result>
        <channel>VMs with CD Connected</channel>
        <value>$($CDConnected.Count)</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxWarning>0.1</LimitMaxWarning>
        </result>

        <result>
        <channel>Tools old or not running</channel>
        <value>$($ToolsStatusNotOK.Count)</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxWarning>0.1</LimitMaxWarning>
        </result>

        <result>
        <channel>VMs PoweredOff</channel>
        <value>$PoweredOffVMs</value>
        <unit>Count</unit>
        </result>
        
        <result>
        <channel>VMs PoweredOn</channel>
        <value>$PoweredOnVMs</value>
        <unit>Count</unit>
        </result>"   
        


$xmlOutput = $xmlOutput + "</prtg>"

$xmlOutput