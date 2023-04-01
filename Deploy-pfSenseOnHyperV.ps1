#Requires -Version 5
#Requires -Modules AZSBTools,Hyper-V

<# 
 .SYNOPSIS
  Function to Deploy pfSense firewall on a Hyper-V VM.

 .DESCRIPTION
  Function to Deploy pfSense firewall on a Hyper-V VM.

 .PARAMETER FolderPath
  Path to a local folder where this script will save the downloaded .gz file and the decompressed /iso file.

 .PARAMETER URL
  URL to the .gz file such as https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.6.0-RELEASE-amd64.iso.gz.

 .PARAMETER CheckSum
  This is the SHA256 checksum of the .gz file as obtained from https://www.pfsense.org/download/?section=downloads.

 .PARAMETER VMName
  The desired name of the pfSense virtual machine.

 .PARAMETER VMFolder
  Folder path where the VM files will be sored.

 .PARAMETER vSwitchName
  Name of the virtual switch to connect the first VM NIC to.

 .PARAMETER VMRAM
  Amount of (static) memory to allocate to the VM in GB.

 .PARAMETER VMBootDiskSize
  Size of the VM boot disk size in GB.

 .PARAMETER VMDisk1Size
  Size of the first VM data disk in GB.

 .PARAMETER VMDisk2Size
  Size of the second VM data disk in GB. These sizes should be identical because the data disks will be mirrored.

 .PARAMETER CoreCount
  The number of virtual CPU cores to make available to this VM.

 .EXAMPLE
  . .\Deploy-pfSenseOnHyperV.ps1

 .OUTPUTS
  This cmdlet display progress details to the console. 
      
 .LINK
  https://superwidgets.wordpress.com/category/powershell/
  https://www.pfsense.org/download/?section=downloads

 .NOTES
  Function by Sam Boutros
  v0.1 - 1 April 2023
#>

#region Input

[CmdletBinding(ConfirmImpact='Low')]
Param(
    [Parameter(Mandatory=$false)][String]$FolderPath    = 'C:\Sandbox\pfSense',
    [Parameter(Mandatory=$false)][String]$URL           = 'https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.6.0-RELEASE-amd64.iso.gz',
    [Parameter(Mandatory=$false)][String]$CheckSum      = '941a68c7f20c4b635447cceda429a027f816bdb78d54b8252bb87abf1fc22ee3',
    [Parameter(Mandatory=$false)][String]$VMName        = 'pfSense01',
    [Parameter(Mandatory=$false)][String]$VMFolder      = "D:\VMs\$VMName",
    [Parameter(Mandatory=$false)][String]$vSwitchName   = 'vGuest',
    [Parameter(Mandatory=$false)][Int64]$VMRAM          = 8GB,
    [Parameter(Mandatory=$false)][Int64]$VMBootDiskSize = 30GB,
    [Parameter(Mandatory=$false)][Int64]$VMDisk1Size    = 10GB,
    [Parameter(Mandatory=$false)][Int64]$VMDisk2Size    = 10GB,
    [Parameter(Mandatory=$false)][Int16]$CoreCount      = 4

)

#endregion

#region 1. Downaload the compressed ISO

$GZFilePath = Join-Path $FolderPath (Split-Path $URL -Leaf) # Concatenate the $FolderPath with the file name
Invoke-WebRequest -Uri $URL -OutFile $GZFilePath
$CalculatedHash = (Get-FileHash -Path $GZFilePath -Algorithm SHA256).Hash
$FileInfo = Get-Item $GZFilePath
if ($CalculatedHash -eq $CheckSum) {
    Write-Log 'Validated file',$GZFilePath,'Checksum hash. Size',('{0:N2}' -f ($FileInfo.Length/1MB)),'MB' Green,Cyan,Green,Cyan,Green
} else {
    Write-Log 'Error: Checksum/hash mismatch for file',$GZFilePath,'Size',('{0:N2}' -f ($FileInfo.Length/1MB)),'MB' Magenta,Yellow,Magenta,Yellow,Magenta
}

#endregion

#region 2. Deploy VM on Hyper-V

# Create VM
$VM = New-VM -Name $VMName -MemoryStartupBytes $VMRAM -Path $VMFolder 

# Create Disks
$Disk0 = New-VHD -Path "$VMFolder\$VMName-Disk0.vhdx" -SizeBytes $VMBootDiskSize -Dynamic
$Disk1 = New-VHD -Path "$VMFolder\$VMName-Disk1.vhdx" -SizeBytes $VMDisk1Size -Dynamic
$Disk2 = New-VHD -Path "$VMFolder\$VMName-Disk2.vhdx" -SizeBytes $VMDisk2Size -Dynamic

# Connect Disks to the VM
0..2 | foreach { Add-VMHardDiskDrive -VMName $VMName -Path "$VMFolder\$VMName-Disk$_.vhdx" }

# De-compress and Load up the ISO file to the VM DVD Drive
UnGZip-File -GzFile $GZFilePath -OutFile ($GZFilePath -replace '.gz','')
Get-VMDvdDrive -VMName $VMName | Set-VMDvdDrive -Path ($GZFilePath -replace '.gz','')

# Give the VM 4 CPU cores
Set-VMProcessor $VMName -Count $CoreCount

# Connect VM NIC to vSwitch
Get-VMNetworkAdapter -VMName $VMName | Connect-VMNetworkAdapter -SwitchName $vSwitchName

# Start the VM
Start-VM -Name $VMName

#endregion


