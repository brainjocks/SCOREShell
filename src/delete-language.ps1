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

$result = Read-Variable -Parameters `
	@{ Name = "language"; Value=$currentLanguage; Title="Language to Remove"; Options=$langOptions; },
    @{ Name = "includeSubitems"; Value=$false; Title="Include Subitems"; Columns = 4;},
    @{ Name = "includeDatasources"; Value=$false; Title="Include Datasources"; Columns = 4 },
	@{ Name = "includeSnippets"; Value=$false; Title="Include Snippet Datasources"; Columns = 4 } `
	-Description "Select the language to remove, with options on handling related content" `
    -Title "Remove Language" -Width 600 -Height 300 -OkButtonName "Proceed" -CancelButtonName "Cancel" -ShowHints

if($result -ne "ok") {
    Exit
}

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

$message = "Remove the <span style='font-weight: bold'>$language</span> language from <span style='font-weight: bold'>$($items.Count) item(s)</span> with the following options:<br>"
$message += "<br><table>"
$message += "<tr><td style='width: auto'>Language to Remove:</td><td>$language</td></tr>"
$message += "<tr><td style='width: auto'>Include Subitems:</td><td>$includeSubitems</td></tr>"
$message += "<tr><td style='width: auto'>Include Datasources:</td><td>$includeDatasources</td></tr>"
$message += "<tr><td style='width: auto'>Include Snippet Datasources:</td><td>$includeSnippets</td></tr>"
$message += "</table>"
$message += "<br><p style='font-weight: bold'>Are you sure?</p>"

$proceed = Show-Confirm -Title $message

if ($proceed -ne 'yes') {
	Exit
}

$valid = $FALSE
$title = "Confirm your password to continue."
while ($valid -ne $TRUE) {
	$finalConfirmation = Read-Variable -Parameters `
		@{ Name = "password"; Value=""; Title="Password"; Editor="password"; } `
		-Description "Please confirm that you want to remove the $language language from $($items.Count) items" `
		-Title $title `
		-Width 400 -Height 200 -OkButtonName "Proceed" -CancelButtonName "Cancel" -ShowHints
	
	if ($finalConfirmation -ne 'ok') {
		Exit
	}
	
	$username = [Sitecore.Context]::User.Name
	$valid = [System.Web.Security.Membership]::ValidateUser($username, $password)
	
	if ($valid -ne $TRUE) {
		$title = "Invalid Password. Please try again."
	}
}

$items | ForEach-Object { Remove-ItemLanguage $_ -Language $language }