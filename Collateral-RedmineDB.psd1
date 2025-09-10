<#	
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:   	10/4/2024 12:23 AM
	 Created by:   	Jason Hickey
	 Organization: 	House of Powershell
	 Filename:     	Collateral-RedmineDB.psd1
	 -------------------------------------------------------------------------
	 Module Manifest
	-------------------------------------------------------------------------
	 Module Name: 	Collateral-RedmineDB
	===========================================================================
#>


@{
	
	# Script module or binary module file associated with this manifest
	RootModule            = 'Collateral-RedmineDB.psm1'
	
	# Version number of this module.
	ModuleVersion         = '1.0.3'
	
	# ID used to uniquely identify this module
	GUID                  = '7e95fea9-1d79-4b34-b4b4-877180167879'
	
	# Author of this module
	Author                = 'Jason Hickey'
	
	# Company or vendor of this module
	CompanyName           = 'House of Powershell'
	
	# Copyright statement for this module
	Copyright             = '(c) 2024-2025 Jason Hickey. All rights reserved.'
	
	# Description of the functionality provided by this module
	Description           = 'PowerShell module for Redmine database API operations with comprehensive HTTP request handling, bulk Excel operations, validation, and error management. Includes retry logic, authentication, and extensive parameter aliases for flexible data management.'
	
	# Supported PSEditions
	CompatiblePSEditions = @('Core', 'Desktop')
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion     = '5.1'
	
	# Name of the Windows PowerShell host required by this module
	PowerShellHostName    = ''
	
	# Minimum version of the Windows PowerShell host required by this module
	PowerShellHostVersion = ''
	
	# Minimum version of the .NET Framework required by this module
	DotNetFrameworkVersion = '4.7.2'
	
	# Minimum version of the common language runtime (CLR) required by this module
	CLRVersion = '4.0'
	
	# Processor architecture (None, X86, Amd64, IA64) required by this module
	ProcessorArchitecture = 'None'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules       = @(
		@{ModuleName = 'Microsoft.PowerShell.Utility'; ModuleVersion = '3.1.0.0'; Guid = '1da87e53-152b-403e-98dc-74d7b4d63d59'},
		@{ModuleName = 'Microsoft.PowerShell.Management'; ModuleVersion = '3.1.0.0'; Guid = 'eefcb906-b326-4e99-9f54-8b4bb6ef3c6d'}
	)
	
	# Assemblies that must be loaded prior to importing this module
	RequiredAssemblies    = @()
	
	# Script files (.ps1) that are run in the caller's environment prior to
	# importing this module
	ScriptsToProcess      = @()
	
	# Type files (.ps1xml) to be loaded when importing this module
	TypesToProcess        = @()
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess      = @()
	
	# Modules to import as nested modules of the module specified in
	# ModuleToProcess
	NestedModules         = @()
	
	# Functions to export from this module
	# For performance, list functions explicitly
	FunctionsToExport     = @(
		'Connect-Redmine',
		'Disconnect-Redmine',
		'Search-RedmineDB',
		'Set-RedmineDB',
		'New-RedmineDB',
		'Get-RedmineDB',
		'Edit-RedmineDB',
		'Edit-RedmineDBXL',
		'Remove-RedmineDB',
		'Invoke-ValidateDB',
		'Invoke-DecomissionDB',
		'Import-RedmineEnv',
		'Initialize-Logger',
		'Get-Logger',
		'Write-LogTrace',
		'Write-LogDebug',
		'Write-LogInfo',
		'Write-LogWarn',
		'Write-LogError',
		'Write-LogCritical',
		'Set-LogLevel',
		'Set-LogTargets',
		'Get-LogConfiguration',
		'Get-LogLevels',
		'Get-LogTargets',
		'Enable-FileLogging',
		'Disable-FileLogging',
		'Enable-ConsoleLogging',
		'Disable-ConsoleLogging',
		'Set-LogFile'
	)
	
	# Cmdlets to export from this module
	CmdletsToExport       = @() 
	
	# Variables to export from this module
	VariablesToExport     = @()
	
	# Aliases to export from this module
	AliasesToExport       = @('Dotenv', 'Import-Env')
	
	# DSC class resources to export from this module.
	#DSCResourcesToExport = ''
	
	# List of all modules packaged with this module
	ModuleList            = @()
	
	# List of all files packaged with this module
	FileList              = @(
		'Collateral-RedmineDB.psm1',
		'Collateral-RedmineDB.psd1',
		'README.md',
		'Docs\PROPERTIES.md',
		'Settings\building.xml',
		'Settings\gscstatus.xml',
		'Settings\lifecycle.xml',
		'Settings\opsystem.xml',
		'Settings\programs.xml',
		'Settings\properties.xml',
		'Settings\room.xml',
		'Settings\state.xml',
		'Settings\status.xml',
		'Settings\type.xml'
	)
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData           = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags       = @(
				'PowerShell',
				'REST',
				'API',
				'Redmine',
				'Database',
				'HTTP',
				'Web',
				'Enterprise',
				'Automation',
				'CRUD',
				'Excel',
				'Import',
				'Export',
				'Validation',
				'PSEdition_Core',
				'PSEdition_Desktop',
				'Windows',
				'Linux',
				'MacOS'
			)
			
			# A URL to the license for this module.
			LicenseUri = 'https://github.com/Zephynyah/Collateral-RedmineDB/blob/main/LICENSE'
			
			# A URL to the main website for this project.
			ProjectUri = 'https://github.com/Zephynyah/Collateral-RedmineDB'
			
			# A URL to an icon representing this module.
			IconUri = 'https://raw.githubusercontent.com/Zephynyah/Collateral-RedmineDB/main/icon.png'
			
			# ReleaseNotes of this module
			ReleaseNotes = @'
## Version 1.0.3

### New Features
- Added Send-HTTPRequest function with comprehensive retry logic and error handling
- Enhanced HTTP request capabilities with configurable timeouts and authentication
- Improved parameter validation and URI scheme checking

### Improvements
- Updated module manifest with better metadata and compatibility information
- Enhanced error handling across all functions
- Added comprehensive test suite for HTTP functionality
- Improved documentation and examples

### Bug Fixes
- Fixed lifecycle.xml configuration file
- Resolved module loading issues
- Enhanced parameter aliases for better usability

### Technical Details
- PowerShell 5.1+ compatible
- Cross-platform support (Windows, Linux, macOS)
- Comprehensive Pester test coverage
- Improved Git ignore configuration
'@
			
			# Prerelease string of this module
			# Prerelease = ''
			
			# Flag to indicate whether the module requires explicit user acceptance for install/update
			RequireLicenseAcceptance = $false
			
			# External dependent modules of this module
			ExternalModuleDependencies = @()
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}







