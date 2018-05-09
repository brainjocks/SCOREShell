<#
    Move Layout from Final to Shared
    Install this as a context menu script.  Uncomment line 30 in favor of line 27 to make this recurse.
#>
 
Function Get-Layout ($item) {
    $fld = New-Object -TypeName Sitecore.Data.Fields.LayoutField -ArgumentList $item
    $fld.Value
}
Function Get-LayoutDelta ($item) {
    $itemLayout = Get-Layout $item
    $baseLayout = Get-Layout $item.Template.StandardValues
    [Sitecore.Data.Fields.XmlDeltas]::GetDelta($itemLayout, $baseLayout)
}
Function Move-FinalLayoutDeltaToShared {
    foreach ($item in $input) {
         
        if (![string]::IsNullOrEmpty($item."__Final Renderings")) {
            $delta = Get-LayoutDelta $item
            $item."__Renderings" = $delta
            $item | Reset-ItemField -Name "__Final Renderings" -IncludeStandardFields
        }
    }
}
 
# This will work for just one item
Get-Item -Path $location | Move-FinalLayoutDeltaToShared
 
# This will work for multiple items
# Get-ChildItem $location -Recurse | Move-FinalLayoutDeltaToShared