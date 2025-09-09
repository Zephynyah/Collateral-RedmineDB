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
	ModuleVersion         = '1.0.2'
	
	# ID used to uniquely identify this module
	GUID                  = '7e95fea9-1d79-4b34-b4b4-877180167879'
	
	# Author of this module
	Author                = 'Jason Hickey'
	
	# Company or vendor of this module
	CompanyName           = 'House of Powershell'
	
	# Copyright statement for this module
	Copyright             = '(c) 2024. All rights reserved.'
	
	# Description of the functionality provided by this module
	Description           = 'Windows PowerShell module to interact with Redmine DB API. Includes bulk operations via Excel import with validation and error handling.'
	
	# Supported PSEditions
	# CompatiblePSEditions = @('Core', 'Desktop')
	
	# Minimum version of the Windows PowerShell engine required by this module
	# PowerShellVersion     = '5.1'
	
	# Name of the Windows PowerShell host required by this module
	PowerShellHostName    = ''
	
	# Minimum version of the Windows PowerShell host required by this module
	PowerShellHostVersion = ''
	
	# Minimum version of the .NET Framework required by this module
	#DotNetFrameworkVersion = '4.5.2'
	
	# Minimum version of the common language runtime (CLR) required by this module
	# CLRVersion = ''
	
	# Processor architecture (None, X86, Amd64, IA64) required by this module
	ProcessorArchitecture = 'None'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules       = @(
		'Microsoft.PowerShell.Utility'
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
		'New-RedmineDB',
		'Get-RedmineDB',
		'Edit-RedmineDB',
		'Remove-RedmineDB',
		'Invoke-ValidateDB',
		'Edit-RedmineDBXL',
		'Import-RedmineEnv',
		'Import-Excel'
	)
	
	# Cmdlets to export from this module
	CmdletsToExport       = '*' 
	
	# Variables to export from this module
	VariablesToExport     = '*'
	
	# Aliases to export from this module
	AliasesToExport       = '*' #For performance, list alias explicitly
	
	# DSC class resources to export from this module.
	#DSCResourcesToExport = ''
	
	# List of all modules packaged with this module
	ModuleList            = @()
	
	# List of all files packaged with this module
	FileList              = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData           = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags       = @(
                "powershell",
                "rest",
                "api",
                "redmine",
                "db"
            )
			
			# A URL to the license for this module.
			LicenseUri = 'https://github.pw.utc.com/m335619/RedmineDB/blob/main/LICENSE'
			
			# A URL to the main website for this project.
			ProjectUri = 'https://github.pw.utc.com/m335619/RedmineDB'
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# ReleaseNotes of this module
			# ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}







