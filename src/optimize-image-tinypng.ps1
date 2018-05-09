function TinifyImage($mediaItem) {
    $apiKey = "TODO REPLACE WITH API KEY" # https://tinypng.com/developers
    $apiAuthorization = "api:$apiKey"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($apiAuthorization))
    $basicAuthValue = "Basic $encodedCreds"
     
    $Headers = @{
        Authorization = $basicAuthValue
    }
     
    $blobField = $mediaItem.InnerItem.Fields["blob"]
    $blobStream = $blobField.GetBlobStream()
     
    Try {
        $request = Invoke-RestMethod -Method Post -Uri "https://api.tinify.com/shrink" -Headers $Headers -Body $blobStream
         
        if ($request.output.url) {
            return $request.output.url
        }
        else {
            Write-Error "TinyPNG request failed"
            Write-Host ($request | Format-List | Out-String)
        }
    }
    Catch {
        Write-Error "TinyPNG request failed"
        Break
    }
}
 
function SetMedia($mediaItem, $url, $extension) {
    # download file to temporary location
    $tempFolder = "$SitecoreDataFolder\temp"
 
    Test-Path $tempFolder
 
    if ((Test-Path $tempFolder) -eq 0) {
        New-Item -ItemType Directory -Force -Path $tempFolder
    }
 
    $filePath = "$tempFolder\temp.$extension"
    Invoke-WebRequest -Uri $url -OutFile $filePath
         
    # set the media stream to be the file system file
    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList $filePath, "Open", "Read"
    [Sitecore.Resources.Media.Media] $media = [Sitecore.Resources.Media.MediaManager]::GetMedia($mediaItem);
    $media.SetStream($stream, $extension);
    $stream.Close();
     
    # delete temporary file
    Remove-Item $filePath
}
 
$location = get-location
$scItem = Get-Item $location
$mediaItem = New-Object "Sitecore.Data.Items.MediaItem" $scItem
$extension = $mediaItem.Extension
 
$url = TinifyImage($mediaItem)
 
if ($location) {
    Write-Host "Tiny PNG optimized url: $url"
    SetMedia $mediaItem $url $extension
} else {
    Write-Error "Tiny PNG failed"
}