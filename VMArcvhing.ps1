param($ListFile)

### Before running the script, please connect to the vCenter and also fill out the parametric variables
### Connect to a vCenter: connect-viserver <vCenter FQDN name> -user username-a
### Default file is VMList.txt or you can put a file for parameter

$scriptStart = (Get-Date)

### PowerShell component loaded for the archiving step
Add-Type -assembly "system.io.compression.filesystem"

### These will be overwritten in the main loop function
### No need to change these 2 variables
$sourceName = "clone"
$archiveName = "clone.zip"

### Please add the folder paths where the script will export and archive the VMs

### Final folder where the zip archive will be kept - can be a network location
$finalDestination = "Z:\networkPath"

### Folder where the OVF will be temporarily kept until the archiving is finished
### Exported OVF will be deleted once the archiving process is completed
$ExportFolder = "E:\exportsPath"

### The source path for the archiving
### No need to change this variables
$sourcePath = $ExportFolder

### Archive folder where the archive is kept before copying it to the final location
### Archive will be deleted once the copy process is finished
$archivePath = "E:\archivesPath"


### vCenter information - needs to be filled with valid values

### The datastore where the VM can be cloned
$Datastore = "datastore"
### The ESX host where the VM can be cloned
$ESXHost = "esx"
### The clone disk format
$DiskFormat = "thin"

### Section that takes a file parameter and checks if that file exists
### If no parameter is provided, the script loads by default the VMList.txt
### VMs list is placed in a variable which will be used later

if (!$ListFile) {
	$VMList = Get-Content ./VMList3.txt
	$ListFile = "VMList3.txt"
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

$nameAppend = " - NetworkDisconnectPerCHG0035404"
$notesAppend = " `rSystem was archived."

### Verbose information
echo "-------------------------------------------" | Tee-Object -FilePath "$logFile" -Append
$pinDate = get-date -UFormat '%A, %d %B %Y - %p %I:%M:%S'
echo $pinDate | Tee-Object -FilePath "$logFile" -Append
echo "-------------------------------------------" | Tee-Object -FilePath "$logFile" -Append
echo "Export folder is: $ExportFolder" | Tee-Object -FilePath "$logFile" -Append
echo "Source path is: $sourcePath" | Tee-Object -FilePath "$logFile" -Append
echo "Archive path is: $archivePath" | Tee-Object -FilePath "$logFile" -Append
echo "Final destinations is: $finalDestination" | Tee-Object -FilePath "$logFile" -Append
echo "Cloning to $ESXHost on datastore $Datastore" | Tee-Object -FilePath "$logFile" -Append
echo "Stardate is: $currentDate" | Tee-Object -FilePath "$logFile" -Append
echo "-------------------------------------------" | Tee-Object -FilePath "$logFile" -Append

### Main loop which goes through the VM list sequentially
foreach($vm in $VMList) {
	
	### Current VM tracking
	$currentTime = Get-Date -Format HH:mm:ss
	echo "$currentTime - Processing $vm..."  | Tee-Object -FilePath "$logFile" -Append
	echo ""
	
	### Gets VM stats
	
	$newName = $vm + $nameAppend
	
	try {
		$VMStat = get-vm -Name $newName
		
		
		### If it fails, it will throw an error and skip the rest of the steps
		if ($? -eq $false) {
			throw $error[0].exception
		} else {

			$currentTime = Get-Date -Format HH:mm:ss
			echo "$currentTime - Processing $vm ...!"  | Tee-Object -FilePath "$logFile" -Append
			
			$PowerState = $(Get-VM -Name $newName).PowerState
			$NetworkConnectedState = $(Get-NetworkAdapter -VM $newName).ConnectionState.Connected
			$NetworkStartConnectedState = $(Get-NetworkAdapter -VM $newName).ConnectionState.StartConnected
			$VMTools = $(Get-VM -Name $newName).ExtensionData.Guest.ToolsStatus
			$InfoNotes = $(Get-VM -Name $newName).Notes
			
			$newNotes = $InfoNotes + $notesAppend
			
			echo "Name: $vm" | Tee-Object -FilePath "$logFile" -Append
			echo "PowerState: $PowerState" | Tee-Object -FilePath "$logFile" -Append
			echo "Network is connected: $NetworkConnectedState" | Tee-Object -FilePath "$logFile" -Append
			echo "Network will start connected: $NetworkStartConnectedState" | Tee-Object -FilePath "$logFile" -Append
			echo "VMTools status: $VMTools" | Tee-Object -FilePath "$logFile" -Append
			
			### Try to change the name
			
			try {
				
				Get-VM -Name $newName | Set-VM -Name $vm -confirm:$false
				
				### If it fails, it will throw an error
				if ($? -eq $false) {
					throw $error[0].exception
				} else {
					echo "$newName has been renamed to $vm" | Tee-Object -FilePath "$logFile" -Append
				}
			}
			catch [Exception] {
				$currentTime = Get-Date -Format HH:mm:ss
				echo "$currentTime - Error renaming $vm !"  | Tee-Object -FilePath "$logFile" -Append
				continue
			}
			
			### Try to append the notes
			
			try {
				
				Get-VM -Name $vm | Set-VM -Description $newNotes -confirm:$false
				
				### If it fails, it will throw an error
				if ($? -eq $false) {
					throw $error[0].exception
				} else {
					echo "$vm has new notes." | Tee-Object -FilePath "$logFile" -Append
					Start-Sleep -Seconds 3
				}
			}
			catch [Exception] {
				$currentTime = Get-Date -Format HH:mm:ss
				echo "$currentTime - Error appending notes to $vm!"  | Tee-Object -FilePath "$logFile" -Append
				continue
			}
			
			
			### If VM is powered on, it will try to power it off
			
			if ($PowerState -eq "PoweredOn") {
			
				try {
				
					Stop-VM -VM $vm -Confirm:$false
					
					### If it fails, it will throw an error
					if ($? -eq $false) {
						throw $error[0].exception
					} else {
						echo "$vm has been powered off." | Tee-Object -FilePath "$logFile" -Append
					}
				}
				catch [Exception] {
					$currentTime = Get-Date -Format HH:mm:ss
					echo "$currentTime - Error powering off $vm !"  | Tee-Object -FilePath "$logFile" -Append
					continue
				}
			}
			
			
			### If the VM has been powered off or it was already off, proceed with the archiving
			
			$currentTime = Get-Date -Format HH:mm:ss
			echo "$currentTime - Processing $vm ...!"  | Tee-Object -FilePath "$logFile" -Append
					
			### Starts OVF Export job
			try {
			
				$currentTime = Get-Date -Format HH:mm:ss
				echo "$currentTime - Starting $vm OVF Export..."  | Tee-Object -FilePath "$logFile" -Append
				
				### OVF Export command
				get-vm -Name "$vm" | Export-VApp -Destination "$ExportFolder" -CreateSeparateFolder -Force -Description "$vm OVF export"
				
				### If the command fails, it will throw an error and skip the rest of the steps
				if ($? -eq $false) {
					throw $error[0].exception
				} else {
				
					$currentTime = Get-Date -Format HH:mm:ss
					echo "$currentTime - $vm export done!"  | Tee-Object -FilePath "$logFile" -Append
					
					### Starts the archiving process
					try {
					
						$currentTime = Get-Date -Format HH:mm:ss
						echo "$currentTime - Starting $vm archiving..."  | Tee-Object -FilePath "$logFile" -Append
						
						### Sets the source and archive names
						$sourceName = "$vm"
						$archiveName = "$vm.zip"
						
						### Archive command
						[io.compression.zipfile]::CreateFromDirectory("$sourcePath\$sourceName", "$archivePath\$archiveName")
						
						### If the command fails, it will throw an error and skip the next steps
						if ($? -eq $false) {
							throw $error[0].exception
						} else {
							
							$currentTime = Get-Date -Format HH:mm:ss
							echo "$currentTime - $vm has been archived!"  | Tee-Object -FilePath "$logFile" -Append
							
							### Starts copying the archive to the final location
							try {
							
								$currentTime = Get-Date -Format HH:mm:ss
								echo "$currentTime - Starting $vm copy to network location..."  | Tee-Object -FilePath "$logFile" -Append
								
								### Copy command
								copy-item -force -path "$archivePath\$archiveName" -destination $finalDestination
								
								### If the command fails, it will throw an error and skip the next step
								if ($? -eq $false) {
									throw $error[0].exception
								} else {
								
									### Clean-up - Local folders cleanup
									### OVF Export will be deleted
									### Local archive file will be deleted
									try {
										
										$currentTime = Get-Date -Format HH:mm:ss
										echo "$currentTime - Cleaning up $vm..."  | Tee-Object -FilePath "$logFile" -Append
										
										### Delete commands
										remove-item -recurse -force "$sourcePath\$sourceName"
										remove-item -force "$archivePath\$archiveName"
										
										### If any of the commands fail, it will throw an error
										if ($? -eq $false) {
											throw $error[0].exception
										} else {
											$currentTime = Get-Date -Format HH:mm:ss
											echo "$currentTime - Cleanup complete!"  | Tee-Object -FilePath "$logFile" -Append													
											echo "$currentTime - $vm archived and moved successfully!"  | Tee-Object -FilePath "$logFile" -Append
										}
									}
									catch [Exception] {
										$currentTime = Get-Date -Format HH:mm:ss
										echo "$currentTime - Error cleaning up!"  | Tee-Object -FilePath "$logFile" -Append
									}
								}
							}
							catch [Exception] {
								$currentTime = Get-Date -Format HH:mm:ss
							echo "$currentTime - Error copying $vm to the final destination!"  | Tee-Object -FilePath "$logFile" -Append
							}								
						}
					}
					catch [Exception] {
						$currentTime = Get-Date -Format HH:mm:ss
						echo "$currentTime - Error archiving $vm!"  | Tee-Object -FilePath "$logFile" -Append
					}						
				}
			}
			catch [Exception] {
				$currentTime = Get-Date -Format HH:mm:ss
				echo "$currentTime - Error exporting $vm!"  | Tee-Object -FilePath "$logFile" -Append
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
