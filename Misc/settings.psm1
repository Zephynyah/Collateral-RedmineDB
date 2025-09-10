<#
	===========================================================================
	 Module Name:       settings.psm1
	 Created with:      SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:        9/10/2025
	 Created by:        Jason Hickey
	 Organization:      House of Powershell
	 Filename:          settings.psm1
	 Description:       Embedded settings data for Collateral-RedmineDB (converted from XML files)
	 Version:           1.0.0
	 Last Modified:     2025-09-10
	-------------------------------------------------------------------------
	 Copyright (c) 2025 Jason Hickey. All rights reserved.
	 Licensed under the MIT License.
	===========================================================================
#>

#Requires -Version 5.0

# Building array
$script:DBProperties = @(
    'CT - C Building',
    'CT - D Building',
    'CT - EB',
    'CT - EB2',
    'CT - ETC',
    'CT - G-Mezz',
    'CT - L Building',
    'CT - M Building',
    'CT - RTRC',
    'CT - Middletown',
    'CT - MT-130',
    'CT - MT-220',
    'CT - MT-331',
    'CT - M-Mezz',
    'CT - Windsor Locks',
    'IL - Rockford',
    'NB - NB',
    'NB - P Building',
    'NB - S Building',
    'OH - AFRL',
    'OH - Parallax',
    'OK - OKC',
    'PR - A Building',
    'Remote - Parallax',
    'Remote - Site 3',
    'Remote - WP Air Force Base',
    'Remote',
    'TN - AEDC',
    'WPB - B50',
    'WPB - B51',
    'WPB - B52',
    'WPB - B53',
    'WPB - B54',
    'WPB - B60',
    'WPB - B61',
    'WPB - B62',
    'WPB - B63',
    'WPB - B64',
    'WPB - B65',
    'WPB - SCIF'
)

$script:DBvalidBuilding = $script:DBProperties

# GSC Status array
$script:DBvalidStatusGSC = @(
    'Removed',
    'Pending Removal',
    'Quarantined',
    'Active',
    'Not Seen',
    'New',
    'Duplicate',
    'Unknown',
    'Managed by Other'
)

# Lifecycle array
$script:DBvalidLifecycle = @(
    'New (not in use)',
    'In Testing',
    'Active',
    'End of Life',
    'Retired',
    'Disposed',
    'Transferred',
    'Missing',
    'Unknown'
)

# Operating System array
$script:DBvalidOS = @(
    'Windows 11',
    'Windows 10',
    'Windows 8.1',
    'Windows 8',
    'Windows 7',
    'Windows Vista',
    'Windows XP',
    'Windows Server 2022',
    'Windows Server 2019',
    'Windows Server 2016',
    'Windows Server 2012 R2',
    'Windows Server 2012',
    'Windows Server 2008 R2',
    'Windows Server 2008',
    'Windows Server 2003',
    'Ubuntu',
    'CentOS',
    'RHEL',
    'SLES',
    'Debian',
    'Fedora',
    'macOS',
    'iOS',
    'Android',
    'VMware ESXi',
    'Citrix XenServer',
    'Unknown'
)

# Programs array  
$script:DBvalidProgram = @(
    'General Use',
    'CAD/CAM',
    'Engineering Software',
    'Development Tools',
    'Database Server',
    'Web Server',
    'File Server',
    'Print Server',
    'Domain Controller',
    'Email Server',
    'Backup Server',
    'Monitoring Tools',
    'Security Tools',
    'Network Management',
    'Virtualization',
    'Testing/QA',
    'Research',
    'Training',
    'Demo/Presentation',
    'Legacy Application',
    'Specialized Equipment',
    'IoT Device',
    'Unknown',
    'Other'
)

# State hashtable (key = abbreviation, value = full name)
$script:DBvalidState = @{
    'AL' = 'Alabama'
    'AK' = 'Alaska'
    'AZ' = 'Arizona'
    'AR' = 'Arkansas'
    'CA' = 'California'
    'CO' = 'Colorado'
    'CT' = 'Connecticut'
    'DE' = 'Delaware'
    'FL' = 'Florida'
    'GA' = 'Georgia'
    'HI' = 'Hawaii'
    'ID' = 'Idaho'
    'IL' = 'Illinois'
    'IN' = 'Indiana'
    'IA' = 'Iowa'
    'KS' = 'Kansas'
    'KY' = 'Kentucky'
    'LA' = 'Louisiana'
    'ME' = 'Maine'
    'MD' = 'Maryland'
    'MA' = 'Massachusetts'
    'MI' = 'Michigan'
    'MN' = 'Minnesota'
    'MS' = 'Mississippi'
    'MO' = 'Missouri'
    'MT' = 'Montana'
    'NE' = 'Nebraska'
    'NV' = 'Nevada'
    'NH' = 'New Hampshire'
    'NJ' = 'New Jersey'
    'NM' = 'New Mexico'
    'NY' = 'New York'
    'NC' = 'North Carolina'
    'ND' = 'North Dakota'
    'OH' = 'Ohio'
    'OK' = 'Oklahoma'
    'OR' = 'Oregon'
    'PA' = 'Pennsylvania'
    'RI' = 'Rhode Island'
    'SC' = 'South Carolina'
    'SD' = 'South Dakota'
    'TN' = 'Tennessee'
    'TX' = 'Texas'
    'UT' = 'Utah'
    'VT' = 'Vermont'
    'VA' = 'Virginia'
    'WA' = 'Washington'
    'WV' = 'West Virginia'
    'WI' = 'Wisconsin'
    'WY' = 'Wyoming'
    'DC' = 'District of Columbia'
}

# Room array (all 215 entries from original XML)
$script:DBvalidRoom = @(
    'A3 - Main Control Room',
    'A8 - Control',
    'A8 - Engine Test Facility',
    'A8 - Main Control Room',
    'A8 - Testing Facility',
    'A9 - Main Control Room',
    'A9 - Second Floor',
    'AEDC - 1306',
    'AEDC - C1',
    'AFRL - AFRL',
    'B50 - B4',
    'B50 - Fiji',
    'B50 - Hawaii',
    'B50 - Kauai',
    'B50 - Key West',
    'B50 - Maui',
    'B50 - Samoa',
    'B99 - B & O',
    'B99 - Baltic',
    'B99 - Breezeway',
    'B99 - Chessie',
    'B99 - Community Chest',
    'B99 - Electric Company',
    'B99 - Indiana',
    'B99 - Pennsylvania',
    'B99 - Reading',
    'B99 - Union Pacific',
    'B99 - Water Works',
    'Belcan - Belcan',
    'C - AETP Room',
    'C - Data Center',
    'C - Dry Bench',
    'Collins - Rockford',
    'Collins - Windsor Locks',
    'D - 117',
    'D - 130',
    'D - 131',
    'D - 133',
    'D - 134',
    'D - 141',
    'D - 142',
    'D - 143',
    'D - 144',
    'D - 145',
    'D - 148',
    'D - 149',
    'D - 151',
    'D - 152',
    'D - 153',
    'D - 154',
    'D - 413',
    'D - MPE 102',
    'D - MPE 103',
    'D - MPE 104',
    'D - MPE 105',
    'D - MPE 106',
    'D - MPE 108',
    'EB - D-8',
    'EB - D-9',
    'EB - D-10',
    'EB - D-11',
    'EB - D-12',
    'EB - EB2',
    'EB - EB2 Condo 1',
    'EB - EB2 Condo 2',
    'EB - EB2 Condo 3',
    'EB - EB2 CR1',
    'EB - EB2 CR2',
    'EB - G-6',
    'EB - G-8',
    'EB2 - Condo 1',
    'EB2 - Condo 2',
    'EB2 - Condo 3',
    'EB2 - CTF Datacenter',
    'EB2 - D-8',
    'EB2 - D-9',
    'EB2 - G-6',
    'EB2 - G-8',
    'EB2 - G-10',
    'EB2 - G-12',
    'EB2 - CR 1',
    'EB2 - CR 2',
    'EOB - 3005',
    'EOB - Atlantis',
    'EOB - CAVE',
    'EOB - C-LAB',
    'EOB - Dolphin',
    'EOB - Grouper',
    'EOB - Kingfish',
    'EOB - Marlin',
    'EOB - Metropolis',
    'EOB - Sailfish',
    'EOB - Snapper',
    'EOB - Snook',
    'EOB - Swordfish',
    'EOB - Tarpon',
    'EOB - Trout',
    'EOB - Trout DC',
    'EOB - Wahoo',
    'G-Mezz - A',
    'G-Mezz - B',
    'G-Mezz - C',
    'L - ADVANCED COATINGS',
    'L - Booth 15',
    'L - LMS-2',
    'L - Mezz',
    'L - SIGNATURE CLINIC',
    'M - 103',
    'M - 108',
    'M - 110',
    'M - 112',
    'M - B130',
    'M - B220',
    'M - B331',
    'M - Burner Rig',
    'M - GSC Conference Room',
    'M - M1DC',
    'M - Storage Room 1',
    'MFG - Arches',
    'MFG - Crater Lake',
    'MFG - Denali',
    'MFG - Grand Canyon',
    'MFG - Joshua Tree',
    'MFG - Redwood',
    'MFG - Sequoia',
    'MFG - West Wing',
    'MFG - Yellowstone',
    'MFG - Yosemite',
    'MFG - Zion',
    'M-Mezz - 2',
    'M-Mezz - 3',
    'M-Mezz - 4',
    'M-Mezz - 5',
    'M-Mezz - 6',
    'M-Mezz - 7',
    'M-Mezz - 8',
    'M-Mezz - 9',
    'M-Mezz - 10',
    'M-Mezz - 11',
    'M-Mezz - 103',
    'M-Mezz - 108',
    'M-Mezz - 112',
    'M-Mezz - 12',
    'M-Mezz - 13',
    'M-Mezz - 14',
    'M-Mezz - 15',
    'M-Mezz - 16',
    'M-Mezz - 17',
    'M-Mezz - 18',
    'M-Mezz - 24',
    'M-Mezz - 25',
    'M-Mezz - 26',
    'M-Mezz - 27',
    'M-Mezz - 28',
    'M-Mezz - 29',
    'M-Mezz - 30',
    'M-Mezz - 31',
    'M-Mezz - 32',
    'M-Mezz - 33',
    'M-Mezz - 34',
    'M-Mezz - 35',
    'M-Mezz - 36',
    'M-Mezz - 38',
    'M-Mezz - 39',
    'M-Mezz - 40',
    'M-Mezz - 41',
    'M-Mezz - 43',
    'M-Mezz - ACC',
    'M-Mezz - CR-A',
    'M-Mezz - CR-B',
    'M-Mezz - M-DC',
    'MT - 220',
    'MT - Abaris II',
    'MT - B130',
    'MT - Conference Room',
    'MT - PC-101',
    'MT - PC-102',
    'MT - PC-201',
    'MT - PC-202',
    'MT - PC-203',
    'MT - PC-301',
    'MT - PC-302',
    'MT - PC-303',
    'MT - PC-304',
    'MT - Secure Room 1',
    'MT - Secure Room 2',
    'MT - X960',
    'MPE - 102',
    'MPE - 103',
    'MPE - 104',
    'MPE - 105',
    'MPE - 106',
    'MPE - 108',
    'OKC - LAB',
    'P - 18',
    'Parallax - 384A',
    'Parallax - AFLCMC',
    'PR - A',
    'PR - Conference Room',
    'PR - Data Room',
    'PR - IT Mezzanine',
    'RTRC - CTF',
    'RTRC - PGP',
    'S - 16',
    'Site 3',
    'STB - Booth 8 & 9',
    'STB - Low Temp',
    'STB - Profit RM',
    'STB - STB',
    'TAB - Conference Room',
    'TAB - Office 1',
    'TAB - Office 2',
    'TAB - Server Room',
    'WP Air Force Base - AFRL',
    'TBD'
)

# Status hashtable
$script:DBStatus = @{
    'valid'     = 0
    'to verify' = 1
    'invalid'   = 2
}

# Type hashtable
$script:DBType = @{
    'Workstation'             = 1
    'Laptop'                  = 2  
    'Server'                  = 4
    'VoIP'                    = 5
    'Printer'                 = 6
    'Network Switch'          = 7
    'Firewall'                = 8
    'Camera'                  = 9
    'Scanner'                 = 10
    'Hard Drive'              = 11
    'Removable Media'         = 12
    'External Optical Drive'  = 13
    'Internal Optical Drive'  = 14
    'Test Equipment'          = 15
    'Data Transfer Accessory' = 16
    'NVM Peripheral'          = 17
    'VR Accessories'          = 18
    'SAN/NAS'                 = 19
    '3D Printer'              = 20
    'Virtual Server'          = 21
    'Other'                   = 22
    'Virtual Workstation'     = 23
    '3D Mouse'                = 24
    'Borescope'               = 25
    'Cluster'                 = 26
    'Encryptor'               = 27
    'Fiber Channel Switch'    = 28
    'Forensic Bridge'         = 29
    'Infiniband Switch'       = 30
    'Media Converter'         = 31
    'PDU'                     = 32
    'PNA'                     = 33
    'SD Card'                 = 34
    'Secure KVM'              = 35
    'VNA'                     = 36
}

# Properties (configuration) hashtable
$script:DBProperties = @{
    'APIVersion'            = '5.0'
    'DefaultProject'        = 'collateral-management'
    'PageSize'              = 100
    'TimeoutSeconds'        = 30
    'RetryCount'            = 3
    'EnableVerboseLogging'  = $false
    'EnableDebugMode'       = $false
    'MaxExportRecords'      = 10000
    'ValidateSSL'           = $true
    'UserAgent'             = 'Collateral-RedmineDB/1.0'
    'DateFormat'            = 'yyyy-MM-dd'
    'TimeFormat'            = 'HH:mm:ss'
    'CacheTimeout'          = 300
    'BatchSize'             = 50
    'MaxConcurrentRequests' = 5
    'EnableCaching'         = $true
    'CacheLocation'         = $env:TEMP
    'LogLevel'              = 'Information'
    'LogTargets'            = 'Console,File'
    'MaxLogFileSize'        = '10MB'
    'MaxLogFiles'           = 5
    'EnableMetrics'         = $false
    'MetricsInterval'       = 60
    'BackupEnabled'         = $true
    'BackupRetention'       = 30
    'DatabaseTimeout'       = 120
    'ConnectionPoolSize'    = 10
    'QueryTimeout'          = 60
    'EnableTransactions'    = $true
    'IsolationLevel'        = 'ReadCommitted'
    'EnableAuditLog'        = $true
    'AuditLogLevel'         = 'Warning'
    'EnableNotifications'   = $false
    'NotificationEndpoint'  = ''
    'SecurityLevel'         = 'High'
    'EncryptionEnabled'     = $true
    'CompressionEnabled'    = $false
    'ThrottleRequests'      = $true
    'MaxRequestsPerMinute'  = 100
    'EnableHealthCheck'     = $true
    'HealthCheckInterval'   = 300
}

# Function to get settings data
function Get-SettingsData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'DBProperties', 
            'DBType', 
            'DBStatus', 
            'DBvalidOS', 
            'DBvalidProgram', 
            'DBvalidState', 
            'DBvalidBuilding', 
            'DBvalidRoom', 
            'DBvalidStatusGSC', 
            'DBvalidLifecycle'
        )]
        [string]$DataName
    )
    
    return (Get-Variable -Name $DataName -Scope Script).Value
}

# Function to get all available data names
function Get-AvailableSettings {
    return @(
        'DBProperties', 
        'DBType', 
        'DBStatus', 
        'DBvalidOS', 
        'DBvalidProgram', 
        'DBvalidState', 
        'DBvalidBuilding', 
        'DBvalidRoom', 
        'DBvalidStatusGSC', 
        'DBvalidLifecycle'
    )
}

# Export functions
Export-ModuleMember -Function @(
    'Get-SettingsData', 
    'Get-AvailableSettings'
)

# Export variables for backward compatibility
Export-ModuleMember -Variable @(
    'DBProperties', 
    'DBType', 
    'DBStatus', 
    'DBvalidOS', 
    'DBvalidProgram',
    'DBvalidState', 
    'DBvalidBuilding', 
    'DBvalidRoom', 
    'DBvalidStatusGSC', 
    'DBvalidLifecycle'
)
