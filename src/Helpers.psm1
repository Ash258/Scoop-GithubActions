function Expand-Property {
    <#
    .SYNOPSIS
        Shortcut for expanding property of object.
    .PARAMETER Object
        Base object.
    .PARAMETER Property
        Property to be expanded.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Hashtable] $Object,
        [Parameter(Mandatory)]
        [String] $Property
    )

    return $Object | Select-Object -ExpandProperty $Property
}

Export-ModuleMember -Function Expand-Property
