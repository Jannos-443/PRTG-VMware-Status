# PRTG-VMWare-Status
# About

## Project Owner:

Jannos-443

## Project Details

Using VMWare PowerCLI this Script checks VMware VM Status for example VMware Tools, Heartbeat, CDDrive Connected and Overall State

## HOW TO

1. Download PSx64.exe from PRTG Tools Familiy https://prtgtoolsfamily.com/downloads/sensors

2. Make sure the VMware PowerCLI Module exists on the Probe under the Powershell Module Path
   - C:\Program Files\WindowsPowerShell\Modules\VMware.VimAutomation.Core

3. Place "PSx64.exe" and "PRTG-VMware-Status.ps1" under "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML"

4. Create new Sensor PSx64.exe -f="PRTG-VMware-Status.ps1" -p="%VCenter%" "%Username%" "%PW%"
   - Set "Scanning Interval" to min "10 minutes"


5. Set the **VM exceptions** parameter to Exclude Alarms

## Examples
![PRTG-VMware-Status](media/VMware-Status-Error.png)

VM exceptions
------------------
Exceptions can be made within this script by changing the variable **IgnoreScript**. This way, the change applies to all PRTG sensors 
based on this script. If exceptions have to be made on a per sensor level, the script parameter **IgnorePattern** can be used.


For more information about regular expressions in PowerShell, visit [Microsoft Docs](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions).

".+" is one or more charakters
".*" is zero or more charakters
