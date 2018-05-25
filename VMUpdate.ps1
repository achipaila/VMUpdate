param($ListFile)

### Before running the script, please connect to the vCenter and also fill out the parametric variables
### Connect to a vCenter: connect-viserver <vCenter FQDN name> -user username-a
### Default file is VMList.txt or you can put a file for parameter

$scriptStart = (Get-Date)

### Section that takes a file parameter and checks if that file exists
### If no parameter is provided, the script loads by default the VMList.txt
### VMs list is placed in a variable which will be used later

if (!$ListFile) {
	$VMList = Get-Content ./VMList.txt
	$ListFile = "VMList.txt"
} else {
	try {
		$VMList = Get-Content ./$ListFile
		if ($? -eq $false) {throw $error[0].exception}
	}
	catch [Exception] {
		echo "$ListFile does not exist"
		break
	}
}

### Logging file
$currentDate = Get-Date -Format yyyyMMddHHmmss

$logFile = "Log$currentDate-$ListFile"
if (Test-Path $logFile) {
	Remove-Item $logFile
}

$nameAppend = " - NameAppend" ### replace with the text needed to be appended to the VM name
$notesAppend = " `r NoteAppend" ### replace with the text needed to be appended to the Notes

### Verbose information
echo "-------------------------------------------" | Tee-Object -FilePath "$logFile" -Append
$pinDate = get-date -UFormat '%A, %d %B %Y - %p %I:%M:%S'
echo $pinDate | Tee-Object -FilePath "$logFile" -Append

### Main loop which goes through the VM list sequentially
foreach($vm in $VMList) {
	
	### Current VM tracking
	$currentTime = Get-Date -Format HH:mm:ss
	echo "$currentTime - Processing $vm..."  | Tee-Object -FilePath "$logFile" -Append
	echo ""
	
	### Gets VM stats
	try {
		$VMStat = get-vm -Name $vm
		
		### If it fails, it will throw an error and skip the rest of the steps
		if ($? -eq $false) {
			throw $error[0].exception
		} else {

			$currentTime = Get-Date -Format HH:mm:ss
			echo "$currentTime - Processing $vm ...!"  | Tee-Object -FilePath "$logFile" -Append
			
			$PowerState = $(Get-VM -Name $vm).PowerState
			$NetworkConnectedState = $(Get-NetworkAdapter -VM $vm).ConnectionState.Connected
			$NetworkStartConnectedState = $(Get-NetworkAdapter -VM $vm).ConnectionState.StartConnected
			$InfoNotes = $(Get-VM -Name $vm).Notes
			
			$newName = $vm + $nameAppend
			$newNotes = $InfoNotes + $notesAppend
			
			echo "Name: $vm" | Tee-Object -FilePath "$logFile" -Append
			echo "PowerState: $PowerState" | Tee-Object -FilePath "$logFile" -Append
			echo "Network is connected: $NetworkConnectedState" | Tee-Object -FilePath "$logFile" -Append
			echo "Network will start connected: $NetworkStartConnectedState" | Tee-Object -FilePath "$logFile" -Append
			echo "Notes: $InfoNotes" | Tee-Object -FilePath "$logFile" -Append
			
			echo "New name will be: $newName"
			echo "Notes will be: $newNotes"
			
			### Try to change the name
			
			try {
				
				Get-VM -Name $vm | Set-VM -Name $newName -confirm:$false
				
				### If it fails, it will throw an error
				if ($? -eq $false) {
					throw $error[0].exception
				} else {
					echo "$vm has been renamed to $newName" | Tee-Object -FilePath "$logFile" -Append
				}
			}
			catch [Exception] {
				$currentTime = Get-Date -Format HH:mm:ss
				echo "$currentTime - Error renaming $vm !"  | Tee-Object -FilePath "$logFile" -Append
			}
			
			### Try to append the notes
			
			try {
				
				Get-VM -Name $newName | Set-VM -Description $newNotes -confirm:$false
				
				### If it fails, it will throw an error
				if ($? -eq $false) {
					throw $error[0].exception
				} else {
					echo "$vm has new notes." | Tee-Object -FilePath "$logFile" -Append
				}
			}
			catch [Exception] {
				$currentTime = Get-Date -Format HH:mm:ss
				echo "$currentTime - Error appending notes to $vm!"  | Tee-Object -FilePath "$logFile" -Append
			}
			
			
			### If VM is powered on, it will try to disconnect the network
			
			if ($PowerState -eq "PoweredOn") {
				try {
				
					Get-VM -Name $newName | Get-NetworkAdapter | Set-NetworkAdapter -connected:$false -confirm:$false
				
					### If it fails, it will throw an error
					if ($? -eq $false) {
						throw $error[0].exception
					} else {
						echo "$vm has been disconnected from the network." | Tee-Object -FilePath "$logFile" -Append
					}
				}
				catch [Exception] {
					$currentTime = Get-Date -Format HH:mm:ss
					echo "$currentTime - Error disconnecting $vm !"  | Tee-Object -FilePath "$logFile" -Append
				}
			}
			
			### It will try to disable the network on start
			
			try {
				Get-VM -Name $newName | Get-NetworkAdapter | Set-NetworkAdapter -startconnected:$false -confirm:$false
			
				### If it fails, it will throw an error
				if ($? -eq $false) {
					throw $error[0].exception
				} else {
					echo "$vm network disabled at start." | Tee-Object -FilePath "$logFile" -Append
				}
			}
			catch [Exception] {
				$currentTime = Get-Date -Format HH:mm:ss
				echo "$currentTime - Error disabling network at start for $vm !"  | Tee-Object -FilePath "$logFile" -Append
			}						
		}
	}
	catch [Exception] {
		$currentTime = Get-Date -Format HH:mm:ss
		echo "$currentTime - Error getting $vm data!"  | Tee-Object -FilePath "$logFile" -Append
	}

	echo "-------------------------------------------"  | Tee-Object -FilePath "$logFile" -Append
	### Simple index for keeping track of total VMs
	$index++
}

$currentTime = Get-Date -Format HH:mm:ss
$totalVMs = "$currentTime - Total VM(s): " + $index
echo   $totalVMs | Tee-Object -FilePath "$logFile" -Append


$scriptEnd = (Get-Date)
$elapsed = ($scriptEnd - $scriptStart)
$disp = "$currentTime - Script took " + $elapsed.Days + " day(s), " + $elapsed.Hours + " hour(s), " + $elapsed.Minutes + " minute(s) and " + $elapsed.Seconds + " second(s)"
echo $disp   | Tee-Object -FilePath "$logFile" -Append

$currentDate = Get-Date -Format yyyyMMddHHmmss
$currentTime = Get-Date -Format HH:mm:ss
echo "$currentTime - Stardate: $currentDate"  | Tee-Object -FilePath "$logFile" -Append
