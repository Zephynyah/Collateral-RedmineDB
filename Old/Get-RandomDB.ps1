function Get-RandomDB {
    <#
    .SYNOPSIS
    Generates a random integer within a specified range.

    .DESCRIPTION
    The Get-Random function generates a random integer between the specified minimum and maximum values.
    This can be useful for testing, sampling, or any scenario where a random number is needed.

    .PARAMETER Minimum
    Specifies the inclusive lower bound of the random number range (default: 25).
    Type: Int32
    Position: Named
    Mandatory: Yes

    .PARAMETER Maximum
    Specifies the exclusive upper bound of the random number range (default: 18721).
    Type: Int32
    Position: Named
    Mandatory: Yes

    .EXAMPLE
    Get-Random

    Generates a random integer between default values (25 and 18720).

    .EXAMPLE
    Get-Random -Minimum 1 -Maximum 1000

    Generates a random integer between 1 and 999.

    .EXAMPLE
    $randomNumber = Get-Random -Minimum 10 -Maximum 20
    Write-Host "Random number between 10 and 19: $randomNumber"

    Generates a random integer between 10 and 19 and displays it.

    .OUTPUTS
    System.Int32
    Returns a randomly generated integer within the specified range.

    .NOTES
    - The Minimum value is inclusive, while the Maximum value is exclusive.
    - Ensure that Minimum is less than Maximum to avoid errors.

    .LINK
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-random
    #>
    Param (
        [Parameter(Mandatory = $false)]
        [Int32]$Count = 1
    )

    try {
        $allEntries = $Script:Redmine.DB.GetAll()
        if ($allEntries.Count -eq 0) {
            Write-LogInfo "No entries found in the Redmine database."
            return $null
        }
        $randomKeys = (Get-Random -InputObject $($allEntries.Keys) -Count $Count)

        $randomKeys | ForEach-Object {
            Write-LogInfo "Generated random number: $_"
            $Script:Redmine.DB.Get($_).ToPSObject()
        }
    }
    catch {
        Write-LogError "Failed to generate random number" -Exception $_.Exception
        throw
    }
}
