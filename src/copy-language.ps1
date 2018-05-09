# Install this script as a Context Menu script

function GetItemDatasources {
    [CmdletBinding()]
    param([Item]$Item)

	# grab all datasources that are not header and footer elements
    return Get-Rendering -Item $item -FinalLayout -Device (Get-LayoutDevice -Default) | 
		Where-Object { -not [string]::IsNullOrEmpty($_.Datasource)} | 
		Where-Object { $_.Placeholder -ne 'Above Page Content' } |
		Where-Object { $_.Placeholder -ne 'Below Page Content' } |
		ForEach-Object { Get-Item "$($item.Database):" -ID $_.Datasource }
}

$location = get-location

$languages = Get-ChildItem "master:\sitecore\system\Languages"
$currentLanguage = [Sitecore.Context]::Language.Name

$langOptions = @{};

foreach ($lang in $languages) {
	$langOptions[$lang.Name] = $lang.Name
}

$ifExists = @{};
$ifExists["Append"] = "Append";
$ifExists["Skip"] = "Skip";
$ifExists["Overwrite Latest"] = "OverwriteLatest";

$result = Read-Variable -Parameters `
	@{ Name = "originLanguage"; Value=$currentLanguage; Title="Origin Language"; Options=$langOptions; },
	@{ Name = "destinationLanguages"; Title="Destination Language(s)"; Options=$langOptions; Editor="checklist"; },
    @{ Name = "includeSubitems"; Value=$false; Title="Include Subitems"; Columns = 4;},
    @{ Name = "includeDatasources"; Value=$false; Title="Include Datasources"; Columns = 4 },
	@{ Name = "includeSnippets"; Value=$false; Title="Include Snippet Datasources"; Columns = 4 },
    @{ Name = "ifExists"; Value="Skip"; Title="If Exists"; Options=$ifExists; Tooltip="Append: Create new language version with copied content.<br>Skip: do nothing if destination has language version.<br>Overwrite Latest: overwrite latest language version with copied content."; } `
	-Description "Select an origin and destination language, with options on how to perform the copy" `
    -Title "Copy Language" -Width 650 -Height 660 -OkButtonName "Proceed" -CancelButtonName "Cancel" -ShowHints

if($result -ne "ok") {
    Exit
}

Write-Host "originLanguage = $originLanguage"
Write-Host "destinationLanguages = $destinationLanguages"

Write-Progress "Calculating items based on selected input..."

$items = @()

$items += Get-Item $location

# add optional subitems
if ($includeSubitems) {
	$items += Get-ChildItem $location -Recurse
}

# add optional datasources
if ($includeDatasources) {
	Foreach($item in $items) {
		$items += GetItemDatasources($item)
	}
}

# add optional datasource subitems
if ($includeSnippets) {
	$items += $items | Where-Object { $_.TemplateName -eq 'Snippet' } | ForEach-Object { GetItemDatasources($_) }
}

# Remove any duplicates, based on ID
$items = $items | Sort-Object -Property 'ID' -Unique

$message = "You are about to update <span style='font-weight: bold'>$($items.Count) item(s)</span> with the following options:<br>"
$message += "<br><table>"
$message += "<tr><td style='width: auto'>Origin Language:</td><td>$originLanguage</td></tr>"
$message += "<tr><td style='width: auto'>Destination Languages:</td><td>$destinationLanguages</td></tr>"
$message += "<tr><td style='width: auto'>Include Subitems:</td><td>$includeSubitems</td></tr>"
$message += "<tr><td style='width: auto'>Include Datasources:</td><td>$includeDatasources</td></tr>"
$message += "<tr><td style='width: auto'>Include Snippet Datasources:</td><td>$includeSnippets</td></tr>"
$message += "<tr><td style='width: auto'>Copy Method:</td><td>$ifExists</td></tr>"
$message += "</table>"
$message += "<br><p style='font-weight: bold'>Are you sure?</p>"


$proceed = Show-Confirm -Title $message

if ($proceed -ne 'yes') {
	Write-Host "Canceling"
	Exit
}

Write-Host "Proceeding with execution"

$total = $items.Count
$count = 1
$items | ForEach-Object { 
    Write-Progress "$count / $total : $($_.Paths.FullPath)"
    Add-ItemLanguage $_ -Language $originLanguage -TargetLanguage $destinationLanguages -IfExist $ifExists
    $count++
}
