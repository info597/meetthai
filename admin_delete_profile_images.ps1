param(
    [Parameter(Mandatory = $true)]
    [string[]]$UserIds,

    [string]$SupabaseUrl = "https://kmcykmpimhyculcnshmp.supabase.co",

    [string]$ProfilePhotosTable = "profile_photos",
    [string]$ProfilesTable = "profiles",

    [string]$PhotoBucket = "profile-photos",
    [string]$AvatarBucket = "avatars",

    [string[]]$PhotoPathColumns = @("storage_path", "path", "file_path", "photo_path", "image_path", "url", "photo_url", "image_url", "public_url"),
    [string[]]$AvatarColumns = @("avatar_path", "avatar_url"),

    [switch]$IncludeAvatar,
    [switch]$Execute
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Green
}

function Get-ServiceRoleKey {
    $key = $env:SUPABASE_SERVICE_ROLE_KEY

    if ([string]::IsNullOrWhiteSpace($key)) {
        throw "SUPABASE_SERVICE_ROLE_KEY fehlt. Setze ihn mit: `$env:SUPABASE_SERVICE_ROLE_KEY='DEIN_KEY'"
    }

    return $key.Trim()
}

function New-Headers {
    param([string]$ServiceRoleKey)

    return @{
        "apikey"        = $ServiceRoleKey
        "Authorization" = "Bearer $ServiceRoleKey"
        "Content-Type"  = "application/json"
        "Prefer"        = "return=representation"
    }
}

function Invoke-SupaGet {
    param([string]$Url, [hashtable]$Headers)
    return Invoke-RestMethod -Method Get -Uri $Url -Headers $Headers
}

function Invoke-SupaDelete {
    param([string]$Url, [hashtable]$Headers)
    return Invoke-RestMethod -Method Delete -Uri $Url -Headers $Headers
}

function Invoke-SupaPatch {
    param([string]$Url, [hashtable]$Headers, [object]$Body)
    $json = $Body | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method Patch -Uri $Url -Headers $Headers -Body $json
}

function Get-StoragePathFromValue {
    param([string]$RawValue, [string[]]$CandidateBuckets)

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return $null
    }

    $value = $RawValue.Trim()

    foreach ($bucket in $CandidateBuckets) {
        $marker = "/storage/v1/object/public/$bucket/"
        $index = $value.IndexOf($marker)

        if ($index -ge 0) {
            return @{
                bucket = $bucket
                path   = [uri]::UnescapeDataString($value.Substring($index + $marker.Length))
            }
        }

        $markerSigned = "/storage/v1/object/sign/$bucket/"
        $indexSigned = $value.IndexOf($markerSigned)

        if ($indexSigned -ge 0) {
            $rest = $value.Substring($indexSigned + $markerSigned.Length)
            $q = $rest.IndexOf("?")
            if ($q -ge 0) { $rest = $rest.Substring(0, $q) }

            return @{
                bucket = $bucket
                path   = [uri]::UnescapeDataString($rest)
            }
        }
    }

    if ($value.StartsWith("http")) {
        return $null
    }

    return @{
        bucket = $PhotoBucket
        path   = $value.TrimStart("/")
    }
}

function Get-PathsFromRow {
    param($Row, $Columns, $Buckets)

    $paths = @()

    foreach ($col in $Columns) {
        if ($Row.PSObject.Properties.Name -contains $col) {
            $val = $Row.$col

            if ($val) {
                $parsed = Get-StoragePathFromValue $val $Buckets
                if ($parsed) { $paths += $parsed }
            }
        }
    }

    return $paths
}

function Remove-StorageObject {
    param($Url, $Headers, $Bucket, $Path, $Execute)

    if (-not $Path) { return }

    $encoded = [uri]::EscapeDataString($Path).Replace("%2F", "/")
    $fullUrl = "$Url/storage/v1/object/$Bucket/$encoded"

    if ($Execute) {
        Invoke-SupaDelete $fullUrl $Headers | Out-Null
        Write-Ok "Gelöscht: $Bucket/$Path"
    } else {
        Write-Warn "Würde löschen: $Bucket/$Path"
    }
}

$serviceKey = Get-ServiceRoleKey
$headers = New-Headers $serviceKey

foreach ($userId in $UserIds) {
    Write-Step "Bearbeite User: $userId"

    $photosUrl = "$SupabaseUrl/rest/v1/$ProfilePhotosTable?user_id=eq.$userId&select=*"
    $rows = Invoke-SupaGet $photosUrl $headers

    foreach ($row in $rows) {
        $paths = Get-PathsFromRow $row $PhotoPathColumns @($PhotoBucket, $AvatarBucket)

        foreach ($p in $paths) {
            Remove-StorageObject $SupabaseUrl $headers $p.bucket $p.path $Execute
        }
    }

    if ($Execute) {
        $deleteUrl = "$SupabaseUrl/rest/v1/$ProfilePhotosTable?user_id=eq.$userId"
        Invoke-SupaDelete $deleteUrl $headers | Out-Null
        Write-Ok "DB Fotos gelöscht"
    }

    if ($IncludeAvatar) {
        $profileUrl = "$SupabaseUrl/rest/v1/$ProfilesTable?user_id=eq.$userId&select=*"
        $profiles = Invoke-SupaGet $profileUrl $headers

        foreach ($p in $profiles) {
            $avatarPaths = Get-PathsFromRow $p $AvatarColumns @($AvatarBucket)

            foreach ($a in $avatarPaths) {
                Remove-StorageObject $SupabaseUrl $headers $a.bucket $a.path $Execute
            }
        }

        if ($Execute) {
            $clear = @{}
            foreach ($c in $AvatarColumns) { $clear[$c] = $null }

            $clearUrl = "$SupabaseUrl/rest/v1/$ProfilesTable?user_id=eq.$userId"
            Invoke-SupaPatch $clearUrl $headers $clear | Out-Null

            Write-Ok "Avatar entfernt"
        }
    }
}

Write-Host ""
Write-Host "FERTIG"