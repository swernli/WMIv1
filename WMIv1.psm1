function Get-WmiObject {
    [CmdletBinding(DefaultParameterSetName="Class")]
    [OutputType([wmi[]])]
    param(
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Class")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Class,

        [Parameter(ParameterSetName="Class")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Filter,

        [Parameter(ParameterSetName="Class")]
        [string[]]
        $Property,

        [Parameter(ParameterSetName="Query")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Namespace = "\\.\root\cimv2"
    )

    if ($Filter.Length -and $Property.Count){
        Get-CimInstance -Namespace $Namespace -ClassName $Class -Filter $Filter -Property $Property | ForEach-Object {[wmi]$_}
    } elseif ($Filter.Length) {
        Get-CimInstance -Namespace $Namespace -ClassName $Class -Filter $Filter | ForEach-Object {[wmi]$_}
    } elseif ($Property.Count) {
        Get-CimInstance -Namespace $Namespace -ClassName $Class -Property $Property | ForEach-Object {[wmi]$_}
    } elseif ($Class) {
        Get-CimInstance -Namespace $Namespace -ClassName $Class | ForEach-Object {[wmi]$_}
    } else {
        Get-CimInstance -Namespace $Namespace -Query $Query | ForEach-Object {[wmi]$_}
    }
}

Set-Alias gwmi Get-WmiObject