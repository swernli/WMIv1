class wmi {
    # Inner CimInstance
    hidden [CimInstance] $ciminstance

    # Path.Path should return underlying Cim Instance for compatibility.
    hidden $Path

    wmi([CimInstance]$instance) {
        $this.ciminstance = $instance
        $this.Path = @{"Path" = $this.ciminstance }
        $this.Init()
    }

    wmi([string]$wmiPath) {
        $namespace = $wmiPath.split(":")[0].substring($wmiPath.indexof("root")).replace("\", "/")
        $spec = $wmiPath.substring($wmiPath.split(":")[0].length + 1)
        $classname = $spec.split(".")[0]
        $keyproperties = Invoke-Expression ("@{" + `
                $spec.substring($classname.length + 1).replace("`",", "`";").replace("\\", "\") + "}")
        $this.ciminstance = Get-CimClass -Namespace $namespace -ClassName $classname |`
            New-CimInstance -Property $keyproperties -ClientOnly | Get-CimInstance
        $this.Init()
    }

    hidden Init() {
        # __Path property (readonly)
        $this.psobject.members.Add((new-object management.automation.PSScriptProperty "__Path", {
                    $keys = ($this.ciminstance.cimclass.CimClassProperties | Where-Object { $_.flags -like "*Key*" } | Select-Object -ExpandProperty name)
                    $keystrings = ($keys | ForEach-Object { "$_=`"$($this.ciminstance.ciminstanceproperties[$_].value)`"" })
                    return "\\$($this.ciminstance.cimsystemproperties.servername)\$($this.ciminstance.cimsystemproperties.namespace.replace("/","\")):$($this.ciminstance.cimsystemproperties.classname).$([string]::Join(",",$keystrings))"
                }, { }))

        # Create the default Cim Instance property wrappers.
        foreach ($p in $this.ciminstance.CimInstanceProperties) {
            $this.psobject.members.Add((new-object management.automation.PSScriptProperty `
                        $p.name, `
                    (Invoke-Expression "{`$this.ciminstance.$($p.name)}"), `
                    (Invoke-Expression "{
                    param(`$in)
                    if(`$this.ciminstance.CimInstanceProperties[`"$($p.name)`"].CimType -like `"*Array`" -and
                        `$in -isnot [Object[]]){
                        `$this.ciminstance.CimInstanceProperties[`"$($p.name)`"].value = @(`$in)
                    }else{
                        `$this.ciminstance.CimInstanceProperties[`"$($p.name)`"].value = `$in
                    }
                    }")))
        }

        # Create dynamic method wrappers.
        foreach ($m in $this.ciminstance.CimClass.CimClassMethods) {
            # Sort the parameter names by Qualifier "ID" to make sure they match the order
            # defined in the mof.
            $keys = foreach ($i in (0..($m.parameters.count - 1))) {
                foreach ($p in $m.parameters) {
                    if ($p.qualifiers["id"].value -ne $i) {
                        continue
                    }
                    $p.name
                }
            }
            $this.psobject.members.Add((new-object management.automation.PSScriptMethod `
                        $m.name, `
                    (Invoke-Expression "{
# METHOD NAME: $($m.name)
# METHOD PARAMETERS: $(`
    if ($keys) {[String]::Join(", ", $keys)} else {"---"})

                `$method = `$this.ciminstance.cimclass.cimclassmethods[`"$($m.name)`"]
                `$keys = $(if ($keys) {[String]::Join(",", ($keys|ForEach-Object{"'$_'"}))} else {"`$null"})
                `$methodArgs = @{}
                if (`$args) {
                    foreach (`$i in (0..(`$args.count - 1))) {
                        if(`$args[`$i].ciminstance -is [CimInstance]) {
                            if(`$method.parameters[`$keys[`$i]].cimtype -eq [cimtype]::ReferenceArray){
                                `$methodArgs.Add(`$keys[`$i],[CimInstance[]]@(`$args[`$i].ciminstance))
                            } else {
                                `$methodArgs.Add(`$keys[`$i],`$args[`$i].ciminstance)
                            }
                        } elseif (`$args[`$i] -is [Object[]] -and `$args[`$i][0] -is [String]) {
                            `$methodArgs.Add(`$keys[`$i],[String[]]`$args[`$i])
                        } elseif(`$method.parameters[`$keys[`$i]].qualifiers[`"ArrayType`"] -and `$args[`$i] -isnot [Object[]]) {
                            `$methodArgs.Add(`$keys[`$i],@(`$args[`$i]))
                        } elseif(`$args[`$i] -is [switch]) {
                            `$methodArgs.Add(`$keys[`$i],`$args[`$i].tobool())
                        } else {
                            `$methodArgs.Add(`$keys[`$i],`$args[`$i])
                        }
                    }
                }
                `$this.ciminstance | Invoke-CimMethod -MethodName $($m.name) -Arguments `$methodArgs -ErrorAction Stop
            }")))
        }
    }

    # Refresh the object based on the current cim instance.
    Get() {
        $this.ciminstance = $this.ciminstance | Get-CimInstance
        $this.Path = @{"Path" = [string]$this.ciminstance }
    }

    [string] GetText($type) {
        if ($type -ne 1) { throw "Unexpected 'type' value: $type" }
        $CimSerializer = `
            [Microsoft.Management.Infrastructure.Serialization.CimSerializer]::Create()
        $SerializedInstance = `
            $CimSerializer.Serialize(
            $this.ciminstance, 
            [Microsoft.Management.Infrastructure.Serialization.InstanceSerializationOptions]::None)
        return [System.Text.Encoding]::Unicode.GetString($SerializedInstance)
    }

    [wmi[]] GetRelated() {
        return $this.ciminstance | Get-CimAssociatedInstance | ForEach-Object { [wmi]$_ }
    }

    [wmi[]] GetRelated([string] $relatedClass) {
        return $this.ciminstance | Get-CimAssociatedInstance -ResultClassName $relatedClass | ForEach-Object { [wmi]$_ }
    }

    [wmi[]] GetRelated([string] $relatedClass, [string] $relationshipClass) {
        return $this.ciminstance | Get-CimAssociatedInstance -ResultClassName $relatedClass -Association $relationshipClass | ForEach-Object { [wmi]$_ }
    }

    [wmi[]] GetRelated([string] $relatedClass, [string] $relationshipClass, [string] $relationshipQualifier, [string] $relatedQualifier, [string] $relatedRole, [string] $thisRole, [bool] $classDefinitionsOnly, [string] $options) {
        return $this.GetRelated($relatedClass, $relationshipClass)
    }
}

class wmiclass {
    hidden [CimClass] $cimclass

    wmiclass([string] $path) {
        $this.cimclass = Get-CimClass $path
    }

    wmiclass([CimClass] $cimclass) {
        $this.cimclass = $cimclass
    }

    [wmi] CreateInstance() {
        return [wmi] ($this.cimclass | New-CimInstance -ClientOnly)
    }
}

function Get-WmiObject {
    [CmdletBinding(DefaultParameterSetName = "Class")]
    [OutputType([wmi[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Class")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Class,

        [Parameter(ParameterSetName = "Class")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Filter,

        [Parameter(ParameterSetName = "Class")]
        [string[]]
        $Property,

        [Parameter(ParameterSetName = "Query")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Namespace = "\\.\root\cimv2"
    )

    if ($Filter.Length -and $Property.Count) {
        Get-CimInstance -Namespace $Namespace -ClassName $Class -Filter $Filter -Property $Property | ForEach-Object { [wmi]$_ }
    }
    elseif ($Filter.Length) {
        Get-CimInstance -Namespace $Namespace -ClassName $Class -Filter $Filter | ForEach-Object { [wmi]$_ }
    }
    elseif ($Property.Count) {
        Get-CimInstance -Namespace $Namespace -ClassName $Class -Property $Property | ForEach-Object { [wmi]$_ }
    }
    elseif ($Class) {
        Get-CimInstance -Namespace $Namespace -ClassName $Class | ForEach-Object { [wmi]$_ }
    }
    else {
        Get-CimInstance -Namespace $Namespace -Query $Query | ForEach-Object { [wmi]$_ }
    }
}

Set-Alias gwmi Get-WmiObject