# ============================================================
# Folder Search Tool V11 Parallel Fast Edition
# Windows PowerShell 5.1 Compatible
# ============================================================


# ============================================================
# CONFIGURATION
# ============================================================

try {
    $Host.UI.RawUI.WindowTitle = "Folder Search Tool V11"
}
catch {
}


$AppName = "FolderSearchV83"

$IndexFolder = Join-Path `
    $env:LOCALAPPDATA `
    $AppName


# ------------------------------------------------------------
# General
# ------------------------------------------------------------

$StreamBufferSize = 16777216

$RetryCount = 3

$RetryDelayMs = 300

$AllowPartialIndex = $false


# ------------------------------------------------------------
# Full Build
# ------------------------------------------------------------

$EnableParallelFullBuild = $true

$FullBuildThrottleLimit = 32

if ($FullBuildThrottleLimit -lt 1) {
    $FullBuildThrottleLimit = 1
}

if ($FullBuildThrottleLimit -gt 32) {
    $FullBuildThrottleLimit = 32
}


$FullBuildBatchSize = 256

$FullBuildProgressInterval = 5000


# ------------------------------------------------------------
# Incremental
# ------------------------------------------------------------

$EnableParallelIncremental = $true

$IncrementalThrottleLimit = 32

if ($IncrementalThrottleLimit -lt 1) {
    $IncrementalThrottleLimit = 1
}

if ($IncrementalThrottleLimit -gt 32) {
    $IncrementalThrottleLimit = 32
}


$IncrementalCounterInterval = 250

$IncrementalProgressInterval = 10000

$MapProgressInterval = 500000

$RebuildProgressInterval = 500000


# ------------------------------------------------------------
# Search
# ------------------------------------------------------------

$MaxDisplayResults = 10000

$FastSearchStopAtLimit = $true

$ShowResultsImmediately = $true

$DefaultSearchMode = "Name"

$SearchProgressInterval = 500000

$EnableSearchPause = $true

$SearchKeyCheckInterval = 5000

$EnableParallelSearch = $true

$SearchThrottleLimit = 4

$SearchAllProgressInterval = 250

$SearchAllKeyCheckInterval = 100


# ============================================================
# CREATE INDEX FOLDER
# ============================================================

if (-not (Test-Path -LiteralPath $IndexFolder)) {

    try {

        New-Item `
            -ItemType Directory `
            -Path $IndexFolder `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }
    catch {

        Clear-Host

        Write-Host "============================================================"
        Write-Host " FATAL ERROR"
        Write-Host "============================================================"
        Write-Host ""

        Write-Host $_.Exception.Message

        Write-Host ""

        Read-Host "Press Enter to exit" |
            Out-Null

        exit 1
    }
}


# ============================================================
# BASIC FUNCTIONS
# ============================================================

function Pause-Tool {

    Write-Host ""

    Read-Host "Press Enter to continue" |
        Out-Null
}


function Show-Header {

    param(
        [string]$Title
    )

    Clear-Host

    Write-Host "============================================================"
    Write-Host " $Title"
    Write-Host "============================================================"
    Write-Host ""
}


function Format-Number {

    param(
        [long]$Number
    )

    return ("{0:N0}" -f $Number)
}


function Format-FileSize {

    param(
        [long]$Bytes
    )

    if ($Bytes -ge 1TB) {

        return (
            "{0:N2} TB" -f
            ($Bytes / 1TB)
        )
    }


    if ($Bytes -ge 1GB) {

        return (
            "{0:N2} GB" -f
            ($Bytes / 1GB)
        )
    }


    if ($Bytes -ge 1MB) {

        return (
            "{0:N2} MB" -f
            ($Bytes / 1MB)
        )
    }


    if ($Bytes -ge 1KB) {

        return (
            "{0:N2} KB" -f
            ($Bytes / 1KB)
        )
    }


    return "$Bytes Bytes"
}


function Format-Duration {

    param(
        [double]$Seconds
    )

    if ($Seconds -lt 0) {
        $Seconds = 0
    }


    $time = [TimeSpan]::FromSeconds(
        $Seconds
    )


    if ($time.TotalDays -ge 1) {

        return (
            "{0}d {1:00}:{2:00}:{3:00}" -f
            [math]::Floor($time.TotalDays),
            $time.Hours,
            $time.Minutes,
            $time.Seconds
        )
    }


    return (
        "{0:00}:{1:00}:{2:00}" -f
        [math]::Floor($time.TotalHours),
        $time.Minutes,
        $time.Seconds
    )
}


function ConvertTo-SafeIndexText {

    param(
        [string]$Text
    )

    if ($null -eq $Text) {
        return ""
    }


    return $Text.Replace(
        "`t",
        " "
    )
}


# ============================================================
# PROGRESS FUNCTIONS
# ============================================================

function Write-FullBuildProgress {

    param(
        [string]$Drive,

        [long]$Items,

        [long]$Directories,

        [long]$Queue,

        [long]$Failed,

        [double]$Speed,

        [int]$Workers
    )


    $itemsText = Format-Number `
        -Number $Items


    $dirsText = Format-Number `
        -Number $Directories


    $queueText = Format-Number `
        -Number $Queue


    $failedText = Format-Number `
        -Number $Failed


    $speedText = "{0:N0}" -f $Speed


    $statusText = (
        "Items " +
        $itemsText +
        " | Dirs " +
        $dirsText +
        " | Queue " +
        $queueText +
        " | Failed " +
        $failedText +
        " | " +
        $speedText +
        "/sec | Workers " +
        [string]$Workers
    )


    Write-Progress `
        -Activity (
            "Parallel Full Build " +
            $Drive
        ) `
        -Status $statusText
}


function Write-IncrementalProgress {

    param(
        [string]$Drive,

        [long]$Checked,

        [long]$Total,

        [long]$Changed,

        [long]$Deleted,

        [long]$Failed,

        [double]$Speed,

        [int]$Workers
    )


    [double]$percentage = 0


    if ($Total -gt 0) {

        $percentage = (
            $Checked /
            $Total *
            100
        )
    }


    if ($percentage -lt 0) {
        $percentage = 0
    }


    if ($percentage -gt 100) {
        $percentage = 100
    }


    $checkedText = Format-Number `
        -Number $Checked


    $totalText = Format-Number `
        -Number $Total


    $changedText = Format-Number `
        -Number $Changed


    $deletedText = Format-Number `
        -Number $Deleted


    $failedText = Format-Number `
        -Number $Failed


    $speedText = "{0:N0}" -f $Speed


    $statusText = (
        "Checked " +
        $checkedText +
        "/" +
        $totalText +
        " | Changed " +
        $changedText +
        " | Deleted " +
        $deletedText +
        " | Failed " +
        $failedText +
        " | " +
        $speedText +
        "/sec | Workers " +
        [string]$Workers
    )


    Write-Progress `
        -Activity (
            "Parallel Incremental Check " +
            $Drive
        ) `
        -Status $statusText `
        -PercentComplete $percentage
}
# ============================================================
# PATH FUNCTIONS
# ============================================================

function Normalize-DriveRoot {

    param(
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        return $null
    }


    $value = $Root.Trim()


    if ($value -match "^[A-Za-z]:$") {

        $value += "\"
    }


    return $value
}


function Normalize-ComparePath {

    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }


    return $Path.TrimEnd("\").ToUpperInvariant()
}


function Get-SafeDriveID {

    param(
        [string]$Root
    )

    $safe = $Root


    foreach (
        $char in
        [System.IO.Path]::GetInvalidFileNameChars()
    ) {

        $safe = $safe.Replace(
            [string]$char,
            "_"
        )
    }


    $safe = $safe.Replace(
        "\",
        "_"
    )


    $safe = $safe.Replace(
        "/",
        "_"
    )


    $safe = $safe.Replace(
        ":",
        ""
    )


    $safe = $safe.Trim("_")


    if ([string]::IsNullOrWhiteSpace($safe)) {

        $safe = "Drive"
    }


    return $safe
}


function Get-IndexPaths {

    param(
        [string]$Root
    )


    $safeID = Get-SafeDriveID `
        -Root $Root


    return @{

        IndexFile = Join-Path `
            $IndexFolder `
            "$safeID.index"

        DirFile = Join-Path `
            $IndexFolder `
            "$safeID.dirs"

        MetaFile = Join-Path `
            $IndexFolder `
            "$safeID.meta.json"

        TempIndexFile = Join-Path `
            $IndexFolder `
            "$safeID.index.tmp"

        TempDirFile = Join-Path `
            $IndexFolder `
            "$safeID.dirs.tmp"

        TempMetaFile = Join-Path `
            $IndexFolder `
            "$safeID.meta.tmp"

        FailureFile = Join-Path `
            $IndexFolder `
            "$safeID.failed.log"

        IndexBackup = Join-Path `
            $IndexFolder `
            "$safeID.index.bak"

        DirBackup = Join-Path `
            $IndexFolder `
            "$safeID.dirs.bak"

        MetaBackup = Join-Path `
            $IndexFolder `
            "$safeID.meta.bak"
    }
}


# ============================================================
# STREAM FUNCTIONS
# ============================================================

function New-Utf8NoBomEncoding {

    return (
        New-Object `
            -TypeName System.Text.UTF8Encoding `
            -ArgumentList $false
    )
}


function New-IndexWriter {

    param(
        [string]$Path
    )


    $encoding = New-Utf8NoBomEncoding


    return (
        New-Object `
            -TypeName System.IO.StreamWriter `
            -ArgumentList @(
                $Path,
                $false,
                $encoding,
                $StreamBufferSize
            )
    )
}


function New-IndexReader {

    param(
        [string]$Path
    )


    return (
        New-Object `
            -TypeName System.IO.StreamReader `
            -ArgumentList @(
                $Path,
                [System.Text.Encoding]::UTF8,
                $true,
                $StreamBufferSize
            )
    )
}


# ============================================================
# DRIVE DETECTION
# ============================================================

function Add-DriveEntry {

    param(
        [hashtable]$Dictionary,

        [string]$Root,

        [string]$Name = "",

        [string]$Label = "",

        [string]$Type = "Unknown",

        [string]$Provider = "",

        [string]$Serial = "",

        [long]$TotalSize = 0,

        [long]$FreeSpace = 0
    )


    $rootValue = Normalize-DriveRoot `
        -Root $Root


    if ([string]::IsNullOrWhiteSpace($rootValue)) {
        return
    }


    $key = $rootValue.ToUpperInvariant()


    if (-not $Dictionary.ContainsKey($key)) {

        $Dictionary[$key] = [PSCustomObject]@{

            Name = $Name

            Root = $rootValue

            Label = $Label

            Type = $Type

            Provider = $Provider

            Serial = $Serial

            TotalSize = $TotalSize

            FreeSpace = $FreeSpace

            Accessible = $false
        }


        return
    }


    $existing = $Dictionary[$key]


    if (
        [string]::IsNullOrWhiteSpace(
            $existing.Label
        ) -and
        -not [string]::IsNullOrWhiteSpace(
            $Label
        )
    ) {

        $existing.Label = $Label
    }


    if (
        $existing.Type -eq "Unknown" -and
        $Type -ne "Unknown"
    ) {

        $existing.Type = $Type
    }


    if (
        $existing.TotalSize -eq 0 -and
        $TotalSize -gt 0
    ) {

        $existing.TotalSize = $TotalSize
    }


    if (
        $existing.FreeSpace -eq 0 -and
        $FreeSpace -gt 0
    ) {

        $existing.FreeSpace = $FreeSpace
    }
}


function Get-AvailableDrives {

    $driveTable = @{}


    # --------------------------------------------------------
    # PowerShell FileSystem Drives
    # --------------------------------------------------------

    try {

        $psDrives = @(
            Get-PSDrive `
                -PSProvider FileSystem `
                -ErrorAction SilentlyContinue
        )


        foreach ($drive in $psDrives) {

            if ([string]::IsNullOrWhiteSpace($drive.Root)) {
                continue
            }


            $provider = ""


            if (
                -not [string]::IsNullOrWhiteSpace(
                    $drive.DisplayRoot
                )
            ) {

                $provider = $drive.DisplayRoot
            }


            Add-DriveEntry `
                -Dictionary $driveTable `
                -Root $drive.Root `
                -Name $drive.Name `
                -Label $provider `
                -Provider $provider
        }
    }
    catch {
    }


    # --------------------------------------------------------
    # WMI Logical Disks
    # --------------------------------------------------------

    try {

        $logicalDisks = @(
            Get-WmiObject `
                -Class Win32_LogicalDisk `
                -ErrorAction SilentlyContinue
        )


        foreach ($disk in $logicalDisks) {

            if ([string]::IsNullOrWhiteSpace($disk.DeviceID)) {
                continue
            }


            $type = "Unknown"


            switch ($disk.DriveType) {

                2 {
                    $type = "Removable"
                }

                3 {
                    $type = "Local"
                }

                4 {
                    $type = "Network"
                }

                5 {
                    $type = "Optical"
                }

                default {
                    $type = "Other"
                }
            }


            $label = [string]$disk.VolumeName


            if (
                $disk.DriveType -eq 4 -and
                -not [string]::IsNullOrWhiteSpace(
                    $disk.ProviderName
                )
            ) {

                $label = [string]$disk.ProviderName
            }


            [long]$size = 0
            [long]$free = 0


            if ($null -ne $disk.Size) {

                $size = [long]$disk.Size
            }


            if ($null -ne $disk.FreeSpace) {

                $free = [long]$disk.FreeSpace
            }


            Add-DriveEntry `
                -Dictionary $driveTable `
                -Root (
                    $disk.DeviceID +
                    "\"
                ) `
                -Name (
                    $disk.DeviceID.TrimEnd(":")
                ) `
                -Label $label `
                -Type $type `
                -Provider (
                    [string]$disk.ProviderName
                ) `
                -Serial (
                    [string]$disk.VolumeSerialNumber
                ) `
                -TotalSize $size `
                -FreeSpace $free
        }
    }
    catch {
    }


    # --------------------------------------------------------
    # .NET DriveInfo
    # --------------------------------------------------------

    try {

        foreach (
            $info in
            [System.IO.DriveInfo]::GetDrives()
        ) {

            $label = ""

            [long]$size = 0
            [long]$free = 0


            try {

                if ($info.IsReady) {

                    $label = $info.VolumeLabel

                    $size = [long]$info.TotalSize

                    $free = [long]$info.AvailableFreeSpace
                }
            }
            catch {
            }


            Add-DriveEntry `
                -Dictionary $driveTable `
                -Root $info.Name `
                -Name (
                    $info.Name.TrimEnd("\").TrimEnd(":")
                ) `
                -Label $label `
                -Type (
                    [string]$info.DriveType
                ) `
                -TotalSize $size `
                -FreeSpace $free
        }
    }
    catch {
    }


    # --------------------------------------------------------
    # Accessibility Check
    # --------------------------------------------------------

    foreach (
        $key in
        @($driveTable.Keys)
    ) {

        $drive = $driveTable[$key]


        try {

            $drive.Accessible = Test-Path `
                -LiteralPath $drive.Root `
                -ErrorAction Stop
        }
        catch {

            $drive.Accessible = $false
        }


        if ([string]::IsNullOrWhiteSpace($drive.Label)) {

            $drive.Label = "Drive"
        }
    }


    return @(
        $driveTable.Values |
            Sort-Object Root
    )
}
# ============================================================
# METADATA
# ============================================================

function Get-IndexMetadata {

    param(
        [object]$Drive
    )


    $paths = Get-IndexPaths `
        -Root $Drive.Root


    if (
        -not (
            Test-Path `
                -LiteralPath $paths.IndexFile `
                -PathType Leaf
        )
    ) {

        return $null
    }


    if (
        -not (
            Test-Path `
                -LiteralPath $paths.DirFile `
                -PathType Leaf
        )
    ) {

        return $null
    }


    if (
        -not (
            Test-Path `
                -LiteralPath $paths.MetaFile `
                -PathType Leaf
        )
    ) {

        return $null
    }


    try {

        $json = Get-Content `
            -LiteralPath $paths.MetaFile `
            -Raw `
            -Encoding UTF8 `
            -ErrorAction Stop


        return (
            $json |
                ConvertFrom-Json
        )
    }
    catch {

        return $null
    }
}


# ============================================================
# DIRECTORY ACCESS
# ============================================================

function Get-DirectoryStamp {

    param(
        [string]$Path
    )


    for (
        $attempt = 1;
        $attempt -le $RetryCount;
        $attempt++
    ) {

        try {

            # ------------------------------------------------
            # Use DirectoryInfo directly.
            #
            # This is safer than Directory.Exists() for SMB,
            # because access errors should not be mistaken for
            # an actual deleted directory.
            # ------------------------------------------------

            $dir = New-Object `
                -TypeName System.IO.DirectoryInfo `
                -ArgumentList $Path


            # Force actual filesystem access.
            $attributes = $dir.Attributes

            $ticks = $dir.LastWriteTimeUtc.Ticks


            return [PSCustomObject]@{

                Success = $true

                Exists = $true

                Ticks = [long]$ticks

                Recovered = (
                    $attempt -gt 1
                )

                Error = ""
            }
        }
        catch [System.IO.DirectoryNotFoundException] {

            return [PSCustomObject]@{

                Success = $true

                Exists = $false

                Ticks = [long]0

                Recovered = (
                    $attempt -gt 1
                )

                Error = ""
            }
        }
        catch [System.IO.FileNotFoundException] {

            return [PSCustomObject]@{

                Success = $true

                Exists = $false

                Ticks = [long]0

                Recovered = (
                    $attempt -gt 1
                )

                Error = ""
            }
        }
        catch {

            if ($attempt -lt $RetryCount) {

                Start-Sleep `
                    -Milliseconds (
                        $RetryDelayMs *
                        $attempt
                    )
            }
            else {

                return [PSCustomObject]@{

                    Success = $false

                    Exists = $false

                    Ticks = [long]0

                    Recovered = $false

                    Error = $_.Exception.Message
                }
            }
        }
    }
}


function Get-DirectoryChildren {

    param(
        [string]$Path
    )


    for (
        $attempt = 1;
        $attempt -le $RetryCount;
        $attempt++
    ) {

        try {

            $dir = New-Object `
                -TypeName System.IO.DirectoryInfo `
                -ArgumentList $Path


            $items = @(
                $dir.GetFileSystemInfos()
            )


            return [PSCustomObject]@{

                Success = $true

                Items = $items

                Recovered = (
                    $attempt -gt 1
                )

                Error = ""
            }
        }
        catch [System.IO.DirectoryNotFoundException] {

            return [PSCustomObject]@{

                Success = $true

                Items = @()

                Recovered = (
                    $attempt -gt 1
                )

                Missing = $true

                Error = ""
            }
        }
        catch [System.IO.FileNotFoundException] {

            return [PSCustomObject]@{

                Success = $true

                Items = @()

                Recovered = (
                    $attempt -gt 1
                )

                Missing = $true

                Error = ""
            }
        }
        catch {

            if ($attempt -lt $RetryCount) {

                Start-Sleep `
                    -Milliseconds (
                        $RetryDelayMs *
                        $attempt
                    )
            }
            else {

                return [PSCustomObject]@{

                    Success = $false

                    Items = @()

                    Recovered = $false

                    Missing = $false

                    Error = $_.Exception.Message
                }
            }
        }
    }
}


# ============================================================
# DIRECTORY STATE
# ============================================================

function Load-DirectoryStates {

    param(
        [string]$File
    )


    $states = @{}


    if (
        -not (
            Test-Path `
                -LiteralPath $File `
                -PathType Leaf
        )
    ) {

        return $states
    }


    $reader = $null


    try {

        $reader = New-IndexReader `
            -Path $File


        while (-not $reader.EndOfStream) {

            $line = $reader.ReadLine()


            if (
                [string]::IsNullOrWhiteSpace(
                    $line
                )
            ) {

                continue
            }


            $parts = $line -split "`t", 2


            if ($parts.Count -ne 2) {
                continue
            }


            [long]$ticks = 0


            if (
                [long]::TryParse(
                    $parts[1],
                    [ref]$ticks
                )
            ) {

                $key = Normalize-ComparePath `
                    -Path $parts[0]


                $states[$key] = [PSCustomObject]@{

                    Path = $parts[0]

                    Ticks = [long]$ticks
                }
            }
        }
    }
    finally {

        if ($null -ne $reader) {

            $reader.Close()

            $reader.Dispose()
        }
    }


    return $states
}


function Save-DirectoryStates {

    param(
        [hashtable]$States,

        [string]$File
    )


    $writer = $null


    try {

        $writer = New-IndexWriter `
            -Path $File


        foreach (
            $state in
            (
                $States.Values |
                    Sort-Object Path
            )
        ) {

            # ------------------------------------------------
            # PowerShell 5.1 safe:
            # precompute function result before .Write()
            # ------------------------------------------------

            $safePath = ConvertTo-SafeIndexText `
                -Text $state.Path


            $ticksText = [string]$state.Ticks


            $writer.Write(
                $safePath
            )


            $writer.Write(
                "`t"
            )


            $writer.WriteLine(
                $ticksText
            )
        }


        $writer.Flush()
    }
    finally {

        if ($null -ne $writer) {

            $writer.Close()

            $writer.Dispose()
        }
    }
}


# ============================================================
# SAFE FILE HELPERS
# ============================================================

function Remove-IfExists {

    param(
        [string]$Path
    )


    if (
        Test-Path `
            -LiteralPath $Path
    ) {

        Remove-Item `
            -LiteralPath $Path `
            -Force `
            -ErrorAction SilentlyContinue
    }
}


function Copy-BackupIfExists {

    param(
        [string]$Source,

        [string]$Backup
    )


    Remove-IfExists `
        -Path $Backup


    if (
        Test-Path `
            -LiteralPath $Source `
            -PathType Leaf
    ) {

        Copy-Item `
            -LiteralPath $Source `
            -Destination $Backup `
            -Force `
            -ErrorAction Stop
    }
}


function Restore-BackupIfExists {

    param(
        [string]$Backup,

        [string]$Destination
    )


    if (
        Test-Path `
            -LiteralPath $Backup `
            -PathType Leaf
    ) {

        Copy-Item `
            -LiteralPath $Backup `
            -Destination $Destination `
            -Force `
            -ErrorAction SilentlyContinue
    }
}


# ============================================================
# SAFE COMMIT
# ============================================================

function Commit-IndexSet {

    param(
        [hashtable]$Paths
    )


    if (
        -not (
            Test-Path `
                -LiteralPath $Paths.TempIndexFile `
                -PathType Leaf
        )
    ) {

        throw "Temporary index file missing."
    }


    if (
        -not (
            Test-Path `
                -LiteralPath $Paths.TempDirFile `
                -PathType Leaf
        )
    ) {

        throw "Temporary directory state file missing."
    }


    if (
        -not (
            Test-Path `
                -LiteralPath $Paths.TempMetaFile `
                -PathType Leaf
        )
    ) {

        throw "Temporary metadata file missing."
    }


    try {

        # ----------------------------------------------------
        # Backup current valid set
        # ----------------------------------------------------

        Copy-BackupIfExists `
            -Source $Paths.IndexFile `
            -Backup $Paths.IndexBackup


        Copy-BackupIfExists `
            -Source $Paths.DirFile `
            -Backup $Paths.DirBackup


        Copy-BackupIfExists `
            -Source $Paths.MetaFile `
            -Backup $Paths.MetaBackup


        # ----------------------------------------------------
        # Replace current set
        # ----------------------------------------------------

        Move-Item `
            -LiteralPath $Paths.TempIndexFile `
            -Destination $Paths.IndexFile `
            -Force `
            -ErrorAction Stop


        Move-Item `
            -LiteralPath $Paths.TempDirFile `
            -Destination $Paths.DirFile `
            -Force `
            -ErrorAction Stop


        Move-Item `
            -LiteralPath $Paths.TempMetaFile `
            -Destination $Paths.MetaFile `
            -Force `
            -ErrorAction Stop


        # ----------------------------------------------------
        # Commit successful, remove backups
        # ----------------------------------------------------

        Remove-IfExists `
            -Path $Paths.IndexBackup


        Remove-IfExists `
            -Path $Paths.DirBackup


        Remove-IfExists `
            -Path $Paths.MetaBackup
    }
    catch {

        # ----------------------------------------------------
        # Restore previous valid files
        # ----------------------------------------------------

        Restore-BackupIfExists `
            -Backup $Paths.IndexBackup `
            -Destination $Paths.IndexFile


        Restore-BackupIfExists `
            -Backup $Paths.DirBackup `
            -Destination $Paths.DirFile


        Restore-BackupIfExists `
            -Backup $Paths.MetaBackup `
            -Destination $Paths.MetaFile


        throw
    }
}


# ============================================================
# SAFE METADATA WRITE
# ============================================================

function Write-MetadataFile {

    param(
        [object]$Metadata,

        [string]$Path
    )


    $jsonText = $Metadata |
        ConvertTo-Json


    Set-Content `
        -LiteralPath $Path `
        -Value $jsonText `
        -Encoding UTF8 `
        -Force `
        -ErrorAction Stop
}


# ============================================================
# UPDATE ONLY METADATA SAFELY
# Used when Incremental finds no file-system changes.
# ============================================================

function Commit-MetadataOnly {

    param(
        [object]$Metadata,

        [hashtable]$Paths
    )


    Remove-IfExists `
        -Path $Paths.TempMetaFile


    Write-MetadataFile `
        -Metadata $Metadata `
        -Path $Paths.TempMetaFile


    try {

        Copy-BackupIfExists `
            -Source $Paths.MetaFile `
            -Backup $Paths.MetaBackup


        Move-Item `
            -LiteralPath $Paths.TempMetaFile `
            -Destination $Paths.MetaFile `
            -Force `
            -ErrorAction Stop


        Remove-IfExists `
            -Path $Paths.MetaBackup
    }
    catch {

        Restore-BackupIfExists `
            -Backup $Paths.MetaBackup `
            -Destination $Paths.MetaFile


        throw
    }
}
# ============================================================
# PARALLEL FULL BUILD ENUMERATOR
# ============================================================

function Invoke-ParallelDirectoryEnumeration {

    param(
        [array]$Directories,

        [int]$ThrottleLimit,

        [int]$RetryCountValue,

        [int]$RetryDelayMsValue
    )


    if ($Directories.Count -eq 0) {
        return @()
    }


    if ($ThrottleLimit -lt 1) {
        $ThrottleLimit = 1
    }


    if ($ThrottleLimit -gt 32) {
        $ThrottleLimit = 32
    }


    $workerScript = {

        param(
            $DirectoryPath,

            $RetryCountValue,

            $RetryDelayMsValue
        )


        for (
            $attempt = 1;
            $attempt -le $RetryCountValue;
            $attempt++
        ) {

            try {

                $dir = New-Object `
                    -TypeName System.IO.DirectoryInfo `
                    -ArgumentList $DirectoryPath


                # Force actual filesystem access.
                $attributes = $dir.Attributes


                $ticks = (
                    $dir.LastWriteTimeUtc
                ).Ticks


                $items = @(
                    $dir.GetFileSystemInfos()
                )


                return [PSCustomObject]@{

                    Success = $true

                    Exists = $true

                    Path = $DirectoryPath

                    Ticks = [long]$ticks

                    Items = $items

                    Recovered = (
                        $attempt -gt 1
                    )

                    Error = ""
                }
            }
            catch [System.IO.DirectoryNotFoundException] {

                return [PSCustomObject]@{

                    Success = $true

                    Exists = $false

                    Path = $DirectoryPath

                    Ticks = [long]0

                    Items = @()

                    Recovered = (
                        $attempt -gt 1
                    )

                    Error = ""
                }
            }
            catch [System.IO.FileNotFoundException] {

                return [PSCustomObject]@{

                    Success = $true

                    Exists = $false

                    Path = $DirectoryPath

                    Ticks = [long]0

                    Items = @()

                    Recovered = (
                        $attempt -gt 1
                    )

                    Error = ""
                }
            }
            catch {

                $errorText = (
                    $_.Exception.Message
                )


                if ($attempt -lt $RetryCountValue) {

                    Start-Sleep `
                        -Milliseconds (
                            $RetryDelayMsValue *
                            $attempt
                        )
                }
                else {

                    return [PSCustomObject]@{

                        Success = $false

                        Exists = $false

                        Path = $DirectoryPath

                        Ticks = [long]0

                        Items = @()

                        Recovered = $false

                        Error = $errorText
                    }
                }
            }
        }
    }


    $pool = $null


    $workers = New-Object `
        'System.Collections.Generic.List[object]'


    try {

        $pool = [RunspaceFactory]::CreateRunspacePool(
            1,
            $ThrottleLimit
        )


        $pool.Open()


        foreach (
            $directoryPath in
            $Directories
        ) {

            $ps = [PowerShell]::Create()


            $ps.RunspacePool = $pool


            [void]$ps.AddScript(
                $workerScript
            )


            [void]$ps.AddArgument(
                $directoryPath
            )


            [void]$ps.AddArgument(
                $RetryCountValue
            )


            [void]$ps.AddArgument(
                $RetryDelayMsValue
            )


            $async = $ps.BeginInvoke()


            $workers.Add(
                [PSCustomObject]@{

                    PowerShell = $ps

                    Async = $async
                }
            )
        }


        $resultList = New-Object `
            'System.Collections.Generic.List[object]'


        foreach ($worker in $workers) {

            try {

                $workerResults = @(
                    $worker.PowerShell.EndInvoke(
                        $worker.Async
                    )
                )


                foreach (
                    $result in
                    $workerResults
                ) {

                    if ($null -ne $result) {

                        $resultList.Add(
                            $result
                        )
                    }
                }
            }
            finally {

                $worker.PowerShell.Dispose()
            }
        }


        # ----------------------------------------------------
        # Convert Generic.List to normal PowerShell array
        # explicitly for PowerShell 5.1 safety.
        # ----------------------------------------------------

        $resultArray = @()


        foreach (
            $resultItem in
            $resultList
        ) {

            $resultArray += $resultItem
        }


        return $resultArray
    }
    finally {

        foreach ($worker in $workers) {

            try {

                if (
                    $null -ne
                    $worker.PowerShell
                ) {

                    $worker.PowerShell.Dispose()
                }
            }
            catch {
            }
        }


        if ($null -ne $pool) {

            try {

                $pool.Close()

                $pool.Dispose()
            }
            catch {
            }
        }
    }
}


# ============================================================
# FULL BUILD
# ============================================================

function Build-FullIndex {

    param(
        [object]$Drive,

        [switch]$NoPause
    )


    Show-Header (
        "Parallel Full Build - " +
        $Drive.Root
    )


    Write-Host "Drive    : $($Drive.Root)"
    Write-Host "Workers  : $FullBuildThrottleLimit"
    Write-Host "Batch    : $FullBuildBatchSize"
    Write-Host "Parallel : $EnableParallelFullBuild"
    Write-Host ""


    $paths = Get-IndexPaths `
        -Root $Drive.Root


    # --------------------------------------------------------
    # Clean temporary files only.
    # Existing valid index remains untouched until commit.
    # --------------------------------------------------------

    Remove-IfExists `
        -Path $paths.TempIndexFile


    Remove-IfExists `
        -Path $paths.TempDirFile


    Remove-IfExists `
        -Path $paths.TempMetaFile


    Remove-IfExists `
        -Path $paths.FailureFile


    # --------------------------------------------------------
    # Directory state table
    # --------------------------------------------------------

    $states = @{}


    # --------------------------------------------------------
    # Pending directory queue
    # --------------------------------------------------------

    $pendingDirectories = New-Object `
        'System.Collections.Generic.Queue[string]'


    $pendingDirectories.Enqueue(
        $Drive.Root
    )


    # --------------------------------------------------------
    # Counters
    # --------------------------------------------------------

    [long]$fileCount = 0

    [long]$folderCount = 0

    [long]$totalCount = 0

    [long]$processedDirectories = 0

    [long]$retryRecovered = 0

    [long]$finalFailed = 0


    [long]$nextProgressAt = (
        $FullBuildProgressInterval
    )


    $startTime = Get-Date

           # =================================================
           # BUILD DIRECTORY BATCH
           # =================================================
	   [long]$liveResultNumber = 0


    $writer = $null


    try {

        $writer = New-IndexWriter `
            -Path $paths.TempIndexFile


        while (
            $pendingDirectories.Count -gt 0
        ) {

            # =================================================
            # BUILD DIRECTORY BATCH
            # =================================================

            $batch = New-Object `
                'System.Collections.Generic.List[string]'


            while (
                $pendingDirectories.Count -gt 0 -and
                $batch.Count -lt $FullBuildBatchSize
            ) {

                $nextDirectory = (
                    $pendingDirectories.Dequeue()
                )


                $batch.Add(
                    $nextDirectory
                )
            }


            # =================================================
            # ENUMERATE BATCH
            # =================================================

            if ($EnableParallelFullBuild) {

                # --------------------------------------------
                # Explicitly convert Generic.List to array.
                # Avoid passing the list object itself as one
                # argument under PowerShell 5.1.
                # --------------------------------------------

                $batchArray = @()


                foreach (
                    $directoryPath in
                    $batch
                ) {

                    $batchArray += $directoryPath
                }


                $batchResults = @(
                    Invoke-ParallelDirectoryEnumeration `
                        -Directories $batchArray `
                        -ThrottleLimit $FullBuildThrottleLimit `
                        -RetryCountValue $RetryCount `
                        -RetryDelayMsValue $RetryDelayMs
                )
            }
            else {

                # =============================================
                # SEQUENTIAL FALLBACK
                # =============================================

                $batchResults = @()


                foreach (
                    $directoryPath in
                    $batch
                ) {

                    $stamp = Get-DirectoryStamp `
                        -Path $directoryPath


                    if (-not $stamp.Success) {

                        $batchResults += (
                            [PSCustomObject]@{

                                Success = $false

                                Exists = $false

                                Path = $directoryPath

                                Ticks = [long]0

                                Items = @()

                                Recovered = $false

                                Error = $stamp.Error
                            }
                        )


                        continue
                    }


                    if (-not $stamp.Exists) {

                        $batchResults += (
                            [PSCustomObject]@{

                                Success = $true

                                Exists = $false

                                Path = $directoryPath

                                Ticks = [long]0

                                Items = @()

                                Recovered = $stamp.Recovered

                                Error = ""
                            }
                        )


                        continue
                    }


                    $children = Get-DirectoryChildren `
                        -Path $directoryPath


                    $batchResults += (
                        [PSCustomObject]@{

                            Success = (
                                $children.Success
                            )

                            Exists = $true

                            Path = $directoryPath

                            Ticks = (
                                [long]$stamp.Ticks
                            )

                            Items = (
                                $children.Items
                            )

                            Recovered = (
                                $stamp.Recovered -or
                                $children.Recovered
                            )

                            Error = (
                                $children.Error
                            )
                        }
                    )
                }
            }


            # =================================================
            # SINGLE WRITER / STATE UPDATE
            # =================================================

            foreach (
                $result in
                $batchResults
            ) {

                $processedDirectories++


                if ($result.Recovered) {

                    $retryRecovered++
                }


                # ------------------------------------------------
                # Directory enumeration failure
                # ------------------------------------------------

                if (-not $result.Success) {

                    $finalFailed++


                    $failureTime = Get-Date `
                        -Format s


                    $failureText = (
                        "{0}`tFULL_BUILD`t{1}`t{2}" -f
                        $failureTime,
                        $result.Path,
                        $result.Error
                    )


                    Add-Content `
                        -LiteralPath $paths.FailureFile `
                        -Encoding UTF8 `
                        -Value $failureText


                    continue
                }


                # ------------------------------------------------
                # Directory disappeared during build
                # ------------------------------------------------

                if (-not $result.Exists) {

                    continue
                }


                # ------------------------------------------------
                # Save directory state
                # ------------------------------------------------

                $stateKey = Normalize-ComparePath `
                    -Path $result.Path


                $states[$stateKey] = (
                    [PSCustomObject]@{

                        Path = $result.Path

                        Ticks = (
                            [long]$result.Ticks
                        )
                    }
                )


                # ------------------------------------------------
                # Write items
                # ------------------------------------------------

                foreach (
                    $entry in
                    $result.Items
                ) {

                    try {

                        $attributes = (
                            $entry.Attributes
                        )


                        $isDirectory = (
                            (
                                $attributes -band
                                [System.IO.FileAttributes]::Directory
                            ) -ne 0
                        )


                        $isReparse = (
                            (
                                $attributes -band
                                [System.IO.FileAttributes]::ReparsePoint
                            ) -ne 0
                        )


                        if ($isDirectory) {

                            $type = "D"

                            $folderCount++


                            # ------------------------------------
                            # Index reparse directory itself,
                            # but do not descend into it.
                            # ------------------------------------

                            if (-not $isReparse) {

                                $pendingDirectories.Enqueue(
                                    $entry.FullName
                                )
                            }
                        }
                        else {

                            $type = "F"

                            $fileCount++
                        }


                        # ----------------------------------------
                        # PowerShell 5.1 safe:
                        # precompute values before .Write()
                        # ----------------------------------------

                        $safeName = ConvertTo-SafeIndexText `
                            -Text $entry.Name


                        $safePath = ConvertTo-SafeIndexText `
                            -Text $entry.FullName


                        $writer.Write(
                            $type
                        )


                        $writer.Write(
                            "`t"
                        )


                        $writer.Write(
                            $safeName
                        )


                        $writer.Write(
                            "`t"
                        )


                        $writer.WriteLine(
                            $safePath
                        )


                        $totalCount++
                    }
                    catch {

                        $finalFailed++


                        $badPath = ""


                        try {

                            $badPath = (
                                $entry.FullName
                            )
                        }
                        catch {
                        }


                        $failureTime = Get-Date `
                            -Format s


                        $failureMessage = (
                            $_.Exception.Message
                        )


                        $failureText = (
                            "{0}`tITEM`t{1}`t{2}" -f
                            $failureTime,
                            $badPath,
                            $failureMessage
                        )


                        Add-Content `
                            -LiteralPath $paths.FailureFile `
                            -Encoding UTF8 `
                            -Value $failureText
                    }
                }


                # =================================================
                # PROGRESS
                # =================================================

                if (
                    $totalCount -ge
                    $nextProgressAt
                ) {

                    $elapsedNow = (
                        Get-Date
                    ) - $startTime


                    [double]$speed = 0


                    if (
                        $elapsedNow.TotalSeconds -gt 0
                    ) {

                        $speed = (
                            $totalCount /
                            $elapsedNow.TotalSeconds
                        )
                    }


                    Write-FullBuildProgress `
                        -Drive $Drive.Root `
                        -Items $totalCount `
                        -Directories $processedDirectories `
                        -Queue $pendingDirectories.Count `
                        -Failed $finalFailed `
                        -Speed $speed `
                        -Workers $FullBuildThrottleLimit


                    $nextProgressAt = (
                        $totalCount +
                        $FullBuildProgressInterval
                    )
                }
            }
        }


        $writer.Flush()
    }
    finally {

        if ($null -ne $writer) {

            $writer.Close()

            $writer.Dispose()
        }
    }


    # --------------------------------------------------------
    # Final progress state
    # --------------------------------------------------------

    $finalElapsedForProgress = (
        Get-Date
    ) - $startTime


    [double]$finalProgressSpeed = 0


    if (
        $finalElapsedForProgress.TotalSeconds -gt 0
    ) {

        $finalProgressSpeed = (
            $totalCount /
            $finalElapsedForProgress.TotalSeconds
        )
    }


    Write-FullBuildProgress `
        -Drive $Drive.Root `
        -Items $totalCount `
        -Directories $processedDirectories `
        -Queue 0 `
        -Failed $finalFailed `
        -Speed $finalProgressSpeed `
        -Workers $FullBuildThrottleLimit


    Write-Progress `
        -Activity (
            "Parallel Full Build " +
            $Drive.Root
        ) `
        -Completed


    # ========================================================
    # FAILURE PROTECTION
    # ========================================================

    if (
        $finalFailed -gt 0 -and
        -not $AllowPartialIndex
    ) {

        Remove-IfExists `
            -Path $paths.TempIndexFile


        Remove-IfExists `
            -Path $paths.TempDirFile


        Remove-IfExists `
            -Path $paths.TempMetaFile


        Show-Header "Full Build NOT Committed"


        Write-Host "Drive      : $($Drive.Root)"
        Write-Host "Files      : $(Format-Number -Number $fileCount)"
        Write-Host "Folders    : $(Format-Number -Number $folderCount)"
        Write-Host "Items      : $(Format-Number -Number $totalCount)"
        Write-Host "Failed     : $(Format-Number -Number $finalFailed)"
        Write-Host ""
        Write-Host "Previous valid index was retained."
        Write-Host ""
        Write-Host "Failure log:"
        Write-Host $paths.FailureFile


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # SAVE DIRECTORY STATE
    # ========================================================

    Show-Header "Full Build - Saving Directory State"


    Write-Host "Drive       : $($Drive.Root)"
    Write-Host "Directories : $(Format-Number -Number $states.Count)"
    Write-Host ""


    Save-DirectoryStates `
        -States $states `
        -File $paths.TempDirFile


    # ========================================================
    # BUILD METADATA
    # ========================================================

    $finishTime = Get-Date


    $elapsed = (
        $finishTime -
        $startTime
    )


    [double]$averageSpeed = 0


    if ($elapsed.TotalSeconds -gt 0) {

        $averageSpeed = (
            $totalCount /
            $elapsed.TotalSeconds
        )
    }


    [long]$indexSize = 0


    try {

        $indexItem = Get-Item `
            -LiteralPath $paths.TempIndexFile `
            -ErrorAction Stop


        $indexSize = (
            [long]$indexItem.Length
        )
    }
    catch {
    }


    $buildTimeText = (
        $finishTime.ToString(
            "yyyy-MM-dd HH:mm:ss"
        )
    )


    $metadata = [PSCustomObject]@{

        Version = "10.4"

        IndexMode = "FullParallel"

        DriveRoot = $Drive.Root

        DriveLabel = $Drive.Label

        DriveType = $Drive.Type

        Serial = $Drive.Serial

        BuildTime = $buildTimeText

        LastSuccessfulUpdate = $buildTimeText

        TotalItems = [long]$totalCount

        Files = [long]$fileCount

        Folders = [long]$folderCount

        IndexedDirectories = [long]$states.Count

        RetryRecovered = [long]$retryRecovered

        FinalFailed = [long]$finalFailed

        ElapsedSeconds = (
            [double]$elapsed.TotalSeconds
        )

        AverageSpeed = (
            [double]$averageSpeed
        )

        IndexSize = [long]$indexSize

        FullBuildWorkers = (
            [int]$FullBuildThrottleLimit
        )
    }


    Write-MetadataFile `
        -Metadata $metadata `
        -Path $paths.TempMetaFile


    # ========================================================
    # COMMIT
    # ========================================================

    try {

        Commit-IndexSet `
            -Paths $paths
    }
    catch {

        Show-Header "Full Build - Commit Error"


        Write-Host $_.Exception.Message
        Write-Host ""
        Write-Host "Previous valid index was retained."


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # COMPLETE
    # ========================================================

    Show-Header "Parallel Full Build Completed"


    Write-Host "Drive       : $($Drive.Root)"
    Write-Host "Files       : $(Format-Number -Number $fileCount)"
    Write-Host "Folders     : $(Format-Number -Number $folderCount)"
    Write-Host "Total       : $(Format-Number -Number $totalCount)"
    Write-Host "Directories : $(Format-Number -Number $states.Count)"
    Write-Host "Workers     : $FullBuildThrottleLimit"
    Write-Host "Recovered   : $(Format-Number -Number $retryRecovered)"
    Write-Host "Failed      : $(Format-Number -Number $finalFailed)"
    Write-Host "Elapsed     : $(Format-Duration -Seconds $elapsed.TotalSeconds)"
    Write-Host "Speed       : $("{0:N0}" -f $averageSpeed) items/sec"
    Write-Host "Index Size  : $(Format-FileSize -Bytes $indexSize)"


    if (-not $NoPause) {

        Pause-Tool
    }


    return $true
}
# ============================================================
# PARALLEL INCREMENTAL PROBE
# ============================================================

function Invoke-ParallelDirectoryProbe {

    param(
        [hashtable]$States,

        [int]$ThrottleLimit,

        [int]$RetryCountValue,

        [int]$RetryDelayMsValue,

        [int]$CounterInterval,

        [string]$DriveRoot
    )


    if ($ThrottleLimit -lt 1) {
        $ThrottleLimit = 1
    }


    if ($ThrottleLimit -gt 32) {
        $ThrottleLimit = 32
    }


    if ($CounterInterval -lt 1) {
        $CounterInterval = 250
    }


    # ========================================================
    # CONVERT STATES TO ARRAY
    # ========================================================

    $stateArray = @(
        $States.Values
    )


    [long]$totalDirectories = (
        $stateArray.Count
    )


    if ($totalDirectories -eq 0) {

        return [PSCustomObject]@{

            Changed = @()

            Deleted = @()

            Failures = @()

            Checked = [long]0

            RetryRecovered = [long]0

            ElapsedSeconds = [double]0
        }
    }


    if ($ThrottleLimit -gt $totalDirectories) {

        $ThrottleLimit = (
            [int]$totalDirectories
        )
    }


    # ========================================================
    # DISTRIBUTE STATES INTO WORKER BUCKETS
    # ========================================================

    $buckets = @()


    for (
        $i = 0;
        $i -lt $ThrottleLimit;
        $i++
    ) {

        $bucket = New-Object `
            'System.Collections.Generic.List[object]'


        $buckets += ,$bucket
    }


    for (
        $i = 0;
        $i -lt $stateArray.Count;
        $i++
    ) {

        $bucketNumber = (
            $i %
            $ThrottleLimit
        )


        $buckets[$bucketNumber].Add(
            $stateArray[$i]
        )
    }


    # Free large duplicate reference array
    $stateArray = $null


    # ========================================================
    # SHARED PROGRESS COUNTERS
    # ========================================================

    $shared = [hashtable]::Synchronized(
        @{

            Checked = [long]0

            Changed = [long]0

            Deleted = [long]0

            Failed = [long]0
        }
    )


    # ========================================================
    # WORKER SCRIPT
    # ========================================================

    $workerScript = {

        param(
            $Bucket,

            $RetryCountValue,

            $RetryDelayMsValue,

            $CounterInterval,

            $Shared
        )


        $changed = New-Object `
            'System.Collections.Generic.List[object]'


        $deleted = New-Object `
            'System.Collections.Generic.List[string]'


        $failures = New-Object `
            'System.Collections.Generic.List[object]'


        [long]$recovered = 0


        [long]$pendingChecked = 0

        [long]$pendingChanged = 0

        [long]$pendingDeleted = 0

        [long]$pendingFailed = 0


        foreach (
            $state in
            $Bucket
        ) {

            $pendingChecked++


            [bool]$success = $false

            [bool]$exists = $false

            [long]$ticks = 0

            $errorText = ""


            # =================================================
            # RETRY DIRECTORY PROBE
            # =================================================

            for (
                $attempt = 1;
                $attempt -le $RetryCountValue;
                $attempt++
            ) {

                try {

                    # -----------------------------------------
                    # Do NOT use Directory.Exists().
                    #
                    # DirectoryInfo forces real access and
                    # allows network / SMB failures to remain
                    # failures instead of being misclassified
                    # as deleted directories.
                    # -----------------------------------------

                    $dir = New-Object `
                        -TypeName System.IO.DirectoryInfo `
                        -ArgumentList $state.Path


                    $attributes = (
                        $dir.Attributes
                    )


                    $ticks = (
                        $dir.LastWriteTimeUtc
                    ).Ticks


                    $success = $true

                    $exists = $true


                    if ($attempt -gt 1) {

                        $recovered++
                    }


                    break
                }
                catch [System.IO.DirectoryNotFoundException] {

                    $success = $true

                    $exists = $false


                    if ($attempt -gt 1) {

                        $recovered++
                    }


                    break
                }
                catch [System.IO.FileNotFoundException] {

                    $success = $true

                    $exists = $false


                    if ($attempt -gt 1) {

                        $recovered++
                    }


                    break
                }
                catch {

                    $errorText = (
                        $_.Exception.Message
                    )


                    if ($attempt -lt $RetryCountValue) {

                        Start-Sleep `
                            -Milliseconds (
                                $RetryDelayMsValue *
                                $attempt
                            )
                    }
                }
            }


            # =================================================
            # RESULT CLASSIFICATION
            # =================================================

            if (-not $success) {

                $pendingFailed++


                $failures.Add(
                    [PSCustomObject]@{

                        Path = $state.Path

                        Error = $errorText
                    }
                )
            }
            elseif (-not $exists) {

                $pendingDeleted++


                $deleted.Add(
                    $state.Path
                )
            }
            elseif (
                [long]$ticks -ne
                [long]$state.Ticks
            ) {

                $pendingChanged++


                $changed.Add(
                    [PSCustomObject]@{

                        Path = $state.Path

                        Ticks = [long]$ticks
                    }
                )
            }


            # =================================================
            # PERIODIC SHARED COUNTER FLUSH
            # =================================================

            if (
                $pendingChecked -ge
                $CounterInterval
            ) {

                [System.Threading.Monitor]::Enter(
                    $Shared.SyncRoot
                )


                try {

                    $Shared["Checked"] = (
                        [long]$Shared["Checked"] +
                        $pendingChecked
                    )


                    $Shared["Changed"] = (
                        [long]$Shared["Changed"] +
                        $pendingChanged
                    )


                    $Shared["Deleted"] = (
                        [long]$Shared["Deleted"] +
                        $pendingDeleted
                    )


                    $Shared["Failed"] = (
                        [long]$Shared["Failed"] +
                        $pendingFailed
                    )
                }
                finally {

                    [System.Threading.Monitor]::Exit(
                        $Shared.SyncRoot
                    )
                }


                $pendingChecked = 0

                $pendingChanged = 0

                $pendingDeleted = 0

                $pendingFailed = 0
            }
        }


        # ====================================================
        # FINAL COUNTER FLUSH
        # ====================================================

        if (
            $pendingChecked -gt 0 -or
            $pendingChanged -gt 0 -or
            $pendingDeleted -gt 0 -or
            $pendingFailed -gt 0
        ) {

            [System.Threading.Monitor]::Enter(
                $Shared.SyncRoot
            )


            try {

                $Shared["Checked"] = (
                    [long]$Shared["Checked"] +
                    $pendingChecked
                )


                $Shared["Changed"] = (
                    [long]$Shared["Changed"] +
                    $pendingChanged
                )


                $Shared["Deleted"] = (
                    [long]$Shared["Deleted"] +
                    $pendingDeleted
                )


                $Shared["Failed"] = (
                    [long]$Shared["Failed"] +
                    $pendingFailed
                )
            }
            finally {

                [System.Threading.Monitor]::Exit(
                    $Shared.SyncRoot
                )
            }
        }


        # ====================================================
        # EXPLICIT ARRAY CONVERSION
        # ====================================================

        $changedArray = @()

        foreach (
            $item in
            $changed
        ) {

            $changedArray += $item
        }


        $deletedArray = @()

        foreach (
            $item in
            $deleted
        ) {

            $deletedArray += (
                [string]$item
            )
        }


        $failureArray = @()

        foreach (
            $item in
            $failures
        ) {

            $failureArray += $item
        }


        return [PSCustomObject]@{

            Changed = $changedArray

            Deleted = $deletedArray

            Failures = $failureArray

            RetryRecovered = (
                [long]$recovered
            )
        }
    }


    # ========================================================
    # RUNSPACE POOL
    # ========================================================

    $pool = $null


    $workers = New-Object `
        'System.Collections.Generic.List[object]'


    $startTime = Get-Date


    try {

        $pool = [RunspaceFactory]::CreateRunspacePool(
            1,
            $ThrottleLimit
        )


        $pool.Open()


        foreach (
            $bucket in
            $buckets
        ) {

            if ($bucket.Count -eq 0) {
                continue
            }


            $ps = [PowerShell]::Create()


            $ps.RunspacePool = $pool


            [void]$ps.AddScript(
                $workerScript
            )


            [void]$ps.AddArgument(
                $bucket
            )


            [void]$ps.AddArgument(
                $RetryCountValue
            )


            [void]$ps.AddArgument(
                $RetryDelayMsValue
            )


            [void]$ps.AddArgument(
                $CounterInterval
            )


            [void]$ps.AddArgument(
                $shared
            )


            $async = $ps.BeginInvoke()


            $workers.Add(
                [PSCustomObject]@{

                    PowerShell = $ps

                    Async = $async
                }
            )
        }


        # ====================================================
        # LIVE PROGRESS LOOP
        # ====================================================

        while ($true) {

            [int]$finished = 0


            foreach (
                $worker in
                $workers
            ) {

                if (
                    $worker.Async.IsCompleted
                ) {

                    $finished++
                }
            }


            [long]$checked = 0

            [long]$changedCount = 0

            [long]$deletedCount = 0

            [long]$failedCount = 0


            [System.Threading.Monitor]::Enter(
                $shared.SyncRoot
            )


            try {

                $checked = (
                    [long]$shared["Checked"]
                )


                $changedCount = (
                    [long]$shared["Changed"]
                )


                $deletedCount = (
                    [long]$shared["Deleted"]
                )


                $failedCount = (
                    [long]$shared["Failed"]
                )
            }
            finally {

                [System.Threading.Monitor]::Exit(
                    $shared.SyncRoot
                )
            }


            $elapsedNow = (
                Get-Date
            ) - $startTime


            [double]$speed = 0


            if (
                $elapsedNow.TotalSeconds -gt 0
            ) {

                $speed = (
                    $checked /
                    $elapsedNow.TotalSeconds
                )
            }


            Write-IncrementalProgress `
                -Drive $DriveRoot `
                -Checked $checked `
                -Total $totalDirectories `
                -Changed $changedCount `
                -Deleted $deletedCount `
                -Failed $failedCount `
                -Speed $speed `
                -Workers $ThrottleLimit


            if (
                $finished -eq
                $workers.Count
            ) {

                break
            }


            Start-Sleep `
                -Milliseconds 250
        }


        Write-Progress `
            -Activity (
                "Parallel Incremental Check " +
                $DriveRoot
            ) `
            -Completed


        # ====================================================
        # COLLECT WORKER RESULTS
        # ====================================================

        $allChanged = New-Object `
            'System.Collections.Generic.List[object]'


        $allDeleted = New-Object `
            'System.Collections.Generic.List[string]'


        $allFailures = New-Object `
            'System.Collections.Generic.List[object]'


        [long]$totalRecovered = 0


        foreach (
            $worker in
            $workers
        ) {

            try {

                $workerResults = @(
                    $worker.PowerShell.EndInvoke(
                        $worker.Async
                    )
                )


                foreach (
                    $result in
                    $workerResults
                ) {

                    if ($null -eq $result) {
                        continue
                    }


                    foreach (
                        $item in
                        $result.Changed
                    ) {

                        $allChanged.Add(
                            $item
                        )
                    }


                    foreach (
                        $item in
                        $result.Deleted
                    ) {

                        $allDeleted.Add(
                            [string]$item
                        )
                    }


                    foreach (
                        $item in
                        $result.Failures
                    ) {

                        $allFailures.Add(
                            $item
                        )
                    }


                    $totalRecovered += (
                        [long]$result.RetryRecovered
                    )
                }
            }
            finally {

                $worker.PowerShell.Dispose()
            }
        }


        # ====================================================
        # EXPLICIT FINAL ARRAY CONVERSION
        # ====================================================

        $changedArray = @()

        foreach (
            $item in
            $allChanged
        ) {

            $changedArray += $item
        }


        $deletedArray = @()

        foreach (
            $item in
            $allDeleted
        ) {

            $deletedArray += (
                [string]$item
            )
        }


        $failureArray = @()

        foreach (
            $item in
            $allFailures
        ) {

            $failureArray += $item
        }


        $finishTime = Get-Date


        $elapsed = (
            $finishTime -
            $startTime
        )


        # ====================================================
        # FINAL RETURN
        # ====================================================

        return [PSCustomObject]@{

            Changed = $changedArray

            Deleted = $deletedArray

            Failures = $failureArray

            Checked = (
                [long]$totalDirectories
            )

            RetryRecovered = (
                [long]$totalRecovered
            )

            ElapsedSeconds = (
                [double]$elapsed.TotalSeconds
            )
        }
    }
    finally {

        foreach (
            $worker in
            $workers
        ) {

            try {

                if (
                    $null -ne
                    $worker.PowerShell
                ) {

                    $worker.PowerShell.Dispose()
                }
            }
            catch {
            }
        }


        if ($null -ne $pool) {

            try {

                $pool.Close()

                $pool.Dispose()
            }
            catch {
            }
        }
    }
}
# ============================================================
# PART 6
# FAST INCREMENTAL UPDATE
# ============================================================


# ============================================================
# SCAN NEW SUBTREE
# ============================================================

function Scan-NewSubtree {

    param(
        [string]$Root,

        [System.IO.StreamWriter]$Writer,

        [hashtable]$States,

        [ref]$AddedFiles,

        [ref]$AddedFolders,

        [ref]$RetryRecovered,

        [ref]$Failures,

        [string]$FailureFile
    )


    $stack = New-Object `
        'System.Collections.Generic.Stack[string]'


    $stack.Push(
        $Root
    )


    while ($stack.Count -gt 0) {

        $current = $stack.Pop()


        # ----------------------------------------------------
        # Read directory timestamp
        # ----------------------------------------------------

        $stamp = Get-DirectoryStamp `
            -Path $current


        if ($stamp.Recovered) {

            $RetryRecovered.Value++
        }


        if (-not $stamp.Success) {

            $Failures.Value++


            $failureTime = Get-Date `
                -Format s


            $failureText = (
                "{0}`tNEW_DIR_STAMP`t{1}`t{2}" -f
                $failureTime,
                $current,
                $stamp.Error
            )


            Add-Content `
                -LiteralPath $FailureFile `
                -Encoding UTF8 `
                -Value $failureText


            continue
        }


        if (-not $stamp.Exists) {

            continue
        }


        # ----------------------------------------------------
        # Save directory state
        # ----------------------------------------------------

        $stateKey = Normalize-ComparePath `
            -Path $current


        $States[$stateKey] = [PSCustomObject]@{

            Path = $current

            Ticks = [long]$stamp.Ticks
        }


        # ----------------------------------------------------
        # Enumerate children
        # ----------------------------------------------------

        $children = Get-DirectoryChildren `
            -Path $current


        if ($children.Recovered) {

            $RetryRecovered.Value++
        }


        if (-not $children.Success) {

            $Failures.Value++


            $failureTime = Get-Date `
                -Format s


            $failureText = (
                "{0}`tNEW_DIR_ENUM`t{1}`t{2}" -f
                $failureTime,
                $current,
                $children.Error
            )


            Add-Content `
                -LiteralPath $FailureFile `
                -Encoding UTF8 `
                -Value $failureText


            continue
        }


        # ----------------------------------------------------
        # Write new subtree records
        # ----------------------------------------------------

        foreach ($entry in $children.Items) {

            try {

                $attributes = $entry.Attributes


                $isDirectory = (
                    (
                        $attributes -band
                        [System.IO.FileAttributes]::Directory
                    ) -ne 0
                )


                $isReparse = (
                    (
                        $attributes -band
                        [System.IO.FileAttributes]::ReparsePoint
                    ) -ne 0
                )


                if ($isDirectory) {

                    $type = "D"

                    $AddedFolders.Value++


                    if (-not $isReparse) {

                        $stack.Push(
                            $entry.FullName
                        )
                    }
                }
                else {

                    $type = "F"

                    $AddedFiles.Value++
                }


                $safeName = ConvertTo-SafeIndexText `
                    -Text $entry.Name


                $safePath = ConvertTo-SafeIndexText `
                    -Text $entry.FullName


                $Writer.Write(
                    $type
                )


                $Writer.Write(
                    "`t"
                )


                $Writer.Write(
                    $safeName
                )


                $Writer.Write(
                    "`t"
                )


                $Writer.WriteLine(
                    $safePath
                )
            }
            catch {

                $Failures.Value++


                $badPath = ""


                try {

                    $badPath = $entry.FullName
                }
                catch {
                }


                $failureTime = Get-Date `
                    -Format s


                $failureText = (
                    "{0}`tNEW_ITEM`t{1}`t{2}" -f
                    $failureTime,
                    $badPath,
                    $_.Exception.Message
                )


                Add-Content `
                    -LiteralPath $FailureFile `
                    -Encoding UTF8 `
                    -Value $failureText
            }
        }
    }
}


# ============================================================
# OPTIMIZED INCREMENTAL UPDATE
# ============================================================

function Update-IncrementalIndex {

    param(
        [object]$Drive,

        [switch]$NoPause
    )


    Show-Header (
        "Incremental Update - " +
        $Drive.Root
    )


    $paths = Get-IndexPaths `
        -Root $Drive.Root


    $metadata = Get-IndexMetadata `
        -Drive $Drive


    if ($null -eq $metadata) {

        Write-Host "No valid index."
        Write-Host "Run Full Build first."


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # LOAD DIRECTORY STATES
    # ========================================================

    Write-Host "Loading directory states..."
    Write-Host ""


    $states = Load-DirectoryStates `
        -File $paths.DirFile


    $directoryCountText = Format-Number `
        -Number $states.Count


    Write-Host (
        "Directories : " +
        $directoryCountText
    )


    Write-Host (
        "Workers     : " +
        [string]$IncrementalThrottleLimit
    )


    Write-Host ""


    if ($states.Count -eq 0) {

        Write-Host "Directory state is empty."


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # CLEAN TEMP FILES
    # ========================================================

    Remove-IfExists `
        -Path $paths.FailureFile


    Remove-IfExists `
        -Path $paths.TempIndexFile


    Remove-IfExists `
        -Path $paths.TempDirFile


    Remove-IfExists `
        -Path $paths.TempMetaFile


    $startTime = Get-Date


    $changedExisting = @{}

    $deletedDirectories = @{}


    [long]$checkedDirectories = 0

    [long]$retryRecovered = 0

    [long]$probeFailures = 0


    # ========================================================
    # STAGE 1
    # DIRECTORY CHANGE CHECK
    # ========================================================

    if ($EnableParallelIncremental) {

        $probe = Invoke-ParallelDirectoryProbe `
            -States $states `
            -ThrottleLimit $IncrementalThrottleLimit `
            -RetryCountValue $RetryCount `
            -RetryDelayMsValue $RetryDelayMs `
            -CounterInterval $IncrementalCounterInterval `
            -DriveRoot $Drive.Root


        $checkedDirectories = [long]$probe.Checked

        $retryRecovered = [long]$probe.RetryRecovered

        $probeFailures = [long]$probe.Failures.Count


        foreach ($changed in $probe.Changed) {

            if ($null -eq $changed) {
                continue
            }


            if (
                [string]::IsNullOrWhiteSpace(
                    $changed.Path
                )
            ) {
                continue
            }


            $key = Normalize-ComparePath `
                -Path $changed.Path


            $changedExisting[$key] = [PSCustomObject]@{

                Path = $changed.Path

                Ticks = [long]$changed.Ticks
            }
        }


        foreach ($deletedPath in $probe.Deleted) {

            if (
                [string]::IsNullOrWhiteSpace(
                    $deletedPath
                )
            ) {
                continue
            }


            $key = Normalize-ComparePath `
                -Path $deletedPath


            $deletedDirectories[$key] = [string]$deletedPath
        }


        foreach ($failure in $probe.Failures) {

            $failureTime = Get-Date `
                -Format s


            $failureText = (
                "{0}`tPROBE`t{1}`t{2}" -f
                $failureTime,
                $failure.Path,
                $failure.Error
            )


            Add-Content `
                -LiteralPath $paths.FailureFile `
                -Encoding UTF8 `
                -Value $failureText
        }
    }
    else {

        # ====================================================
        # SEQUENTIAL FALLBACK
        # ====================================================

        foreach ($state in $states.Values) {

            $checkedDirectories++


            $stamp = Get-DirectoryStamp `
                -Path $state.Path


            if ($stamp.Recovered) {

                $retryRecovered++
            }


            if (-not $stamp.Success) {

                $probeFailures++


                $failureTime = Get-Date `
                    -Format s


                $failureText = (
                    "{0}`tPROBE`t{1}`t{2}" -f
                    $failureTime,
                    $state.Path,
                    $stamp.Error
                )


                Add-Content `
                    -LiteralPath $paths.FailureFile `
                    -Encoding UTF8 `
                    -Value $failureText


                continue
            }


            if (-not $stamp.Exists) {

                $key = Normalize-ComparePath `
                    -Path $state.Path


                $deletedDirectories[$key] = $state.Path


                continue
            }


            if (
                [long]$stamp.Ticks -ne
                [long]$state.Ticks
            ) {

                $key = Normalize-ComparePath `
                    -Path $state.Path


                $changedExisting[$key] = [PSCustomObject]@{

                    Path = $state.Path

                    Ticks = [long]$stamp.Ticks
                }
            }


            if (
                (
                    $checkedDirectories %
                    $IncrementalProgressInterval
                ) -eq 0
            ) {

                $probeElapsed = (
                    Get-Date
                ) - $startTime


                [double]$probeSpeed = 0


                if ($probeElapsed.TotalSeconds -gt 0) {

                    $probeSpeed = (
                        $checkedDirectories /
                        $probeElapsed.TotalSeconds
                    )
                }


                Write-IncrementalProgress `
                    -Drive $Drive.Root `
                    -Checked $checkedDirectories `
                    -Total $states.Count `
                    -Changed $changedExisting.Count `
                    -Deleted $deletedDirectories.Count `
                    -Failed $probeFailures `
                    -Speed $probeSpeed `
                    -Workers 1
            }
        }


        Write-Progress `
            -Activity (
                "Incremental Check " +
                $Drive.Root
            ) `
            -Completed
    }


    # ========================================================
    # FAILURE PROTECTION
    # ========================================================

    if (
        $probeFailures -gt 0 -and
        -not $AllowPartialIndex
    ) {

        Show-Header "Incremental Update Aborted"


        $failureCountText = Format-Number `
            -Number $probeFailures


        Write-Host (
            "Drive    : " +
            $Drive.Root
        )


        Write-Host (
            "Failures : " +
            $failureCountText
        )


        Write-Host ""
        Write-Host "Existing index retained."
        Write-Host ""
        Write-Host "Failure log:"
        Write-Host $paths.FailureFile


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # SHOW PROBE RESULT
    # ========================================================

    Show-Header "Incremental Check Completed"


    $checkedText = Format-Number `
        -Number $checkedDirectories


    $changedText = Format-Number `
        -Number $changedExisting.Count


    $deletedText = Format-Number `
        -Number $deletedDirectories.Count


    $failedText = Format-Number `
        -Number $probeFailures


    Write-Host "Checked : $checkedText"
    Write-Host "Changed : $changedText"
    Write-Host "Deleted : $deletedText"
    Write-Host "Failed  : $failedText"
    Write-Host ""


    # ========================================================
    # NOTHING CHANGED
    # ========================================================

    if (
        $changedExisting.Count -eq 0 -and
        $deletedDirectories.Count -eq 0
    ) {

        $finishTime = Get-Date


        $elapsed = (
            $finishTime -
            $startTime
        )


        [long]$oldIndexSize = 0


        try {

            $indexItem = Get-Item `
                -LiteralPath $paths.IndexFile `
                -ErrorAction Stop


            $oldIndexSize = [long]$indexItem.Length
        }
        catch {
        }


        $serialValue = ""


        if ($null -ne $metadata.Serial) {

            $serialValue = [string]$metadata.Serial
        }
        elseif ($null -ne $Drive.Serial) {

            $serialValue = [string]$Drive.Serial
        }


        $buildTimeValue = ""


        if ($null -ne $metadata.BuildTime) {

            $buildTimeValue = [string]$metadata.BuildTime
        }


        $updateTimeText = (
            $finishTime.ToString(
                "yyyy-MM-dd HH:mm:ss"
            )
        )


        $newMetadata = [PSCustomObject]@{

            Version = "10.4"

            IndexMode = "IncrementalParallelFast"

            DriveRoot = $Drive.Root

            DriveLabel = $Drive.Label

            DriveType = $Drive.Type

            Serial = $serialValue

            BuildTime = $buildTimeValue

            LastSuccessfulUpdate = $updateTimeText

            TotalItems = [long]$metadata.TotalItems

            Files = [long]$metadata.Files

            Folders = [long]$metadata.Folders

            IndexedDirectories = [long]$states.Count

            LastCheckedDirectories = [long]$checkedDirectories

            LastChangedDirectories = [long]0

            LastDeletedDirectories = [long]0

            LastAddedFiles = [long]0

            LastAddedFolders = [long]0

            LastRemovedItems = [long]0

            RetryRecovered = [long]$retryRecovered

            FinalFailed = [long]0

            LastIncrementalSeconds = [double]$elapsed.TotalSeconds

            IndexSize = [long]$oldIndexSize

            IncrementalWorkers = [int]$IncrementalThrottleLimit
        }


        try {

            Commit-MetadataOnly `
                -Metadata $newMetadata `
                -Paths $paths
        }
        catch {

            Show-Header "Metadata Update Failed"


            Write-Host $_.Exception.Message
            Write-Host ""
            Write-Host "Existing metadata retained."


            if (-not $NoPause) {

                Pause-Tool
            }


            return $false
        }


        Show-Header "Incremental Update Completed"


        $totalText = Format-Number `
            -Number ([long]$metadata.TotalItems)


        $elapsedText = Format-Duration `
            -Seconds $elapsed.TotalSeconds


        Write-Host "Drive   : $($Drive.Root)"
        Write-Host "Checked : $checkedText"
        Write-Host "Changed : 0"
        Write-Host "Deleted : 0"
        Write-Host "Total   : $totalText"
        Write-Host "Workers : $IncrementalThrottleLimit"
        Write-Host "Updated : $updateTimeText"
        Write-Host "Elapsed : $elapsedText"


        if (-not $NoPause) {

            Pause-Tool
        }


        return $true
    }


    # ========================================================
    # STAGE 2
    # FAST OLD CHILD MAP
    # ========================================================

    Show-Header "Incremental Update - Fast Index Map"


    Write-Host "Drive        : $($Drive.Root)"
    Write-Host "Changed dirs : $changedText"
    Write-Host "Deleted dirs : $deletedText"
    Write-Host ""
    Write-Host "Scanning existing index..."
    Write-Host ""


    $oldChildren = @{}


    foreach ($changed in $changedExisting.Values) {

        if ($null -eq $changed) {
            continue
        }


        $lookupDirectory = (
            $changed.Path.TrimEnd("\")
        )


        if (
            -not $oldChildren.ContainsKey(
                $lookupDirectory
            )
        ) {

            $oldChildren[$lookupDirectory] = @{}
        }
    }


    $reader = $null


    [long]$mapScanned = 0

    [long]$mapRelevant = 0

    [long]$mapInvalid = 0


    $mapStartTime = Get-Date


    [long]$nextMapProgress = (
        $MapProgressInterval
    )


    try {

        $reader = New-IndexReader `
            -Path $paths.IndexFile


        while (-not $reader.EndOfStream) {

            $line = $reader.ReadLine()


            $mapScanned++


            if ($null -eq $line) {
                continue
            }


            if ($line.Length -lt 5) {

                $mapInvalid++

                continue
            }


            $firstTab = $line.IndexOf("`t")


            if ($firstTab -lt 0) {

                $mapInvalid++

                continue
            }


            $secondTab = $line.IndexOf(
                "`t",
                $firstTab + 1
            )


            if ($secondTab -lt 0) {

                $mapInvalid++

                continue
            }


            $pathStart = (
                $secondTab +
                1
            )


            if ($pathStart -ge $line.Length) {

                $mapInvalid++

                continue
            }


            $path = $line.Substring(
                $pathStart
            )


            $lastSlash = $path.LastIndexOf("\")


            if ($lastSlash -le 0) {

                continue
            }


            $parent = $path.Substring(
                0,
                $lastSlash
            )


            if (
                $oldChildren.ContainsKey(
                    $parent
                )
            ) {

                $mapRelevant++


                $type = $line.Substring(
                    0,
                    $firstTab
                )


                $nameLength = (
                    $secondTab -
                    $firstTab -
                    1
                )


                if ($nameLength -gt 0) {

                    $name = $line.Substring(
                        $firstTab + 1,
                        $nameLength
                    )
                }
                else {

                    $name = ""
                }


                $oldChildren[$parent][$path] = [PSCustomObject]@{

                    Type = $type

                    Name = $name

                    Path = $path
                }
            }


            if ($mapScanned -ge $nextMapProgress) {

                $mapElapsedNow = (
                    Get-Date
                ) - $mapStartTime


                [double]$mapSpeedNow = 0


                if ($mapElapsedNow.TotalSeconds -gt 0) {

                    $mapSpeedNow = (
                        $mapScanned /
                        $mapElapsedNow.TotalSeconds
                    )
                }


                $scanText = Format-Number `
                    -Number $mapScanned


                $relevantText = Format-Number `
                    -Number $mapRelevant


                $invalidText = Format-Number `
                    -Number $mapInvalid


                $speedText = (
                    "{0:N0}" -f
                    $mapSpeedNow
                )


                $statusText = (
                    "Scanned " +
                    $scanText +
                    " | Relevant " +
                    $relevantText +
                    " | Invalid " +
                    $invalidText +
                    " | " +
                    $speedText +
                    "/sec"
                )


                Write-Progress `
                    -Activity (
                        "Fast Index Map " +
                        $Drive.Root
                    ) `
                    -Status $statusText


                $nextMapProgress = (
                    $mapScanned +
                    $MapProgressInterval
                )
            }
        }
    }
    finally {

        if ($null -ne $reader) {

            $reader.Close()

            $reader.Dispose()
        }
    }


    Write-Progress `
        -Activity (
            "Fast Index Map " +
            $Drive.Root
        ) `
        -Completed


    $mapElapsed = (
        Get-Date
    ) - $mapStartTime


    [double]$finalMapSpeed = 0


    if ($mapElapsed.TotalSeconds -gt 0) {

        $finalMapSpeed = (
            $mapScanned /
            $mapElapsed.TotalSeconds
        )
    }


    # ========================================================
    # STAGE 3
    # CALCULATE DELTA
    # ========================================================

    Show-Header "Incremental Update - Calculating Delta"


    $exactRemovals = @{}

    $removedDirectoryRoots = @{}


    $additions = New-Object `
        'System.Collections.Generic.List[object]'


    [long]$syncFailures = 0

    [long]$deltaProcessed = 0


    foreach ($deletedPath in $deletedDirectories.Values) {

        if (
            [string]::IsNullOrWhiteSpace(
                $deletedPath
            )
        ) {
            continue
        }


        $cleanDeletedPath = (
            $deletedPath.TrimEnd("\")
        )


        $exactRemovals[$cleanDeletedPath] = $true

        $removedDirectoryRoots[$cleanDeletedPath] = $true
    }


    foreach ($changed in $changedExisting.Values) {

        $deltaProcessed++


        $lookupDirectory = (
            $changed.Path.TrimEnd("\")
        )


        $childrenResult = Get-DirectoryChildren `
            -Path $changed.Path


        if ($childrenResult.Recovered) {

            $retryRecovered++
        }


        if (-not $childrenResult.Success) {

            $syncFailures++


            $failureTime = Get-Date `
                -Format s


            $failureText = (
                "{0}`tSYNC`t{1}`t{2}" -f
                $failureTime,
                $changed.Path,
                $childrenResult.Error
            )


            Add-Content `
                -LiteralPath $paths.FailureFile `
                -Encoding UTF8 `
                -Value $failureText


            continue
        }


        $currentChildren = @{}


        foreach ($entry in $childrenResult.Items) {

            try {

                $attributes = $entry.Attributes


                $isDirectory = (
                    (
                        $attributes -band
                        [System.IO.FileAttributes]::Directory
                    ) -ne 0
                )


                if ($isDirectory) {

                    $type = "D"
                }
                else {

                    $type = "F"
                }


                $entryPath = $entry.FullName


                $currentChildren[$entryPath] = [PSCustomObject]@{

                    Type = $type

                    Name = $entry.Name

                    Path = $entryPath

                    Info = $entry
                }
            }
            catch {

                $syncFailures++


                $badPath = ""


                try {

                    $badPath = $entry.FullName
                }
                catch {
                }


                $failureTime = Get-Date `
                    -Format s


                $failureText = (
                    "{0}`tDELTA_ITEM`t{1}`t{2}" -f
                    $failureTime,
                    $badPath,
                    $_.Exception.Message
                )


                Add-Content `
                    -LiteralPath $paths.FailureFile `
                    -Encoding UTF8 `
                    -Value $failureText
            }
        }


        if (
            $oldChildren.ContainsKey(
                $lookupDirectory
            )
        ) {

            $previous = $oldChildren[$lookupDirectory]
        }
        else {

            $previous = @{}
        }


        # ----------------------------------------------------
        # Removed direct children
        # ----------------------------------------------------

        foreach ($oldKey in @($previous.Keys)) {

            if (
                -not $currentChildren.ContainsKey(
                    $oldKey
                )
            ) {

                $oldItem = $previous[$oldKey]


                $exactRemovals[$oldKey] = $true


                if ($oldItem.Type -eq "D") {

                    $cleanRoot = (
                        $oldKey.TrimEnd("\")
                    )


                    $removedDirectoryRoots[$cleanRoot] = $true
                }
            }
        }


        # ----------------------------------------------------
        # Added direct children
        # ----------------------------------------------------

        foreach ($newKey in @($currentChildren.Keys)) {

            if (
                -not $previous.ContainsKey(
                    $newKey
                )
            ) {

                $additions.Add(
                    $currentChildren[$newKey]
                )
            }
        }


        # ----------------------------------------------------
        # Update changed directory timestamp
        # ----------------------------------------------------

        $stateKey = Normalize-ComparePath `
            -Path $changed.Path


        $states[$stateKey] = [PSCustomObject]@{

            Path = $changed.Path

            Ticks = [long]$changed.Ticks
        }


        if (
            (
                $deltaProcessed %
                100
            ) -eq 0
        ) {

            $processedText = Format-Number `
                -Number $deltaProcessed


            $totalChangedText = Format-Number `
                -Number $changedExisting.Count


            $additionText = Format-Number `
                -Number $additions.Count


            $removalText = Format-Number `
                -Number $exactRemovals.Count


            $statusText = (
                "Processed " +
                $processedText +
                "/" +
                $totalChangedText +
                " | Additions " +
                $additionText +
                " | Removals " +
                $removalText
            )


            Write-Progress `
                -Activity "Calculating Incremental Delta" `
                -Status $statusText
        }
    }


    Write-Progress `
        -Activity "Calculating Incremental Delta" `
        -Completed


    # ========================================================
    # SYNC FAILURE PROTECTION
    # ========================================================

    if (
        $syncFailures -gt 0 -and
        -not $AllowPartialIndex
    ) {

        Show-Header "Incremental Update Aborted"


        $syncFailureText = Format-Number `
            -Number $syncFailures


        Write-Host (
            "Sync failures : " +
            $syncFailureText
        )


        Write-Host ""
        Write-Host "Existing index retained."
        Write-Host ""
        Write-Host "Failure log:"
        Write-Host $paths.FailureFile


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # REMOVE OLD DIRECTORY STATES
    # ========================================================

    $normalizedRemovedRoots = @{}


    foreach ($removedRoot in $removedDirectoryRoots.Keys) {

        $normalizedRoot = Normalize-ComparePath `
            -Path $removedRoot


        $normalizedRemovedRoots[$normalizedRoot] = $true
    }


    foreach ($stateKey in @($states.Keys)) {

        [bool]$removeState = $false


        if (
            $normalizedRemovedRoots.ContainsKey(
                $stateKey
            )
        ) {

            $removeState = $true
        }
        else {

            $probePath = (
                $stateKey.TrimEnd("\")
            )


            while (-not $removeState) {

                $slash = $probePath.LastIndexOf("\")


                if ($slash -le 2) {

                    break
                }


                $probePath = $probePath.Substring(
                    0,
                    $slash
                )


                if (
                    $normalizedRemovedRoots.ContainsKey(
                        $probePath
                    )
                ) {

                    $removeState = $true

                    break
                }
            }
        }


        if ($removeState) {

            [void]$states.Remove(
                $stateKey
            )
        }
    }


    # ========================================================
    # STAGE 4
    # FAST REBUILD + COUNT
    # ========================================================

    Show-Header "Incremental Update - Fast Index Rebuild"


    $additionCountText = Format-Number `
        -Number $additions.Count


    $exactRemovalText = Format-Number `
        -Number $exactRemovals.Count


    $removedRootText = Format-Number `
        -Number $removedDirectoryRoots.Count


    Write-Host "Drive         : $($Drive.Root)"
    Write-Host "Additions     : $additionCountText"
    Write-Host "Exact removal : $exactRemovalText"
    Write-Host "Removed roots : $removedRootText"
    Write-Host ""
    Write-Host "Rebuilding index..."
    Write-Host ""


    $reader = $null

    $writer = $null


    [long]$rebuildScanned = 0

    [long]$removed = 0


    [long]$retainedFiles = 0

    [long]$retainedFolders = 0


    [long]$addedFiles = 0

    [long]$addedFolders = 0


    [long]$addFailures = 0


    $rebuildStart = Get-Date


    [long]$nextRebuildProgress = (
        $RebuildProgressInterval
    )


    try {

        $reader = New-IndexReader `
            -Path $paths.IndexFile


        $writer = New-IndexWriter `
            -Path $paths.TempIndexFile


        # ----------------------------------------------------
        # Copy retained old records
        # ----------------------------------------------------

        while (-not $reader.EndOfStream) {

            $line = $reader.ReadLine()


            $rebuildScanned++


            if ($null -eq $line) {
                continue
            }


            if ($line.Length -lt 5) {
                continue
            }


            $firstTab = $line.IndexOf("`t")


            if ($firstTab -lt 0) {
                continue
            }


            $secondTab = $line.IndexOf(
                "`t",
                $firstTab + 1
            )


            if ($secondTab -lt 0) {
                continue
            }


            $pathStart = (
                $secondTab +
                1
            )


            if ($pathStart -ge $line.Length) {
                continue
            }


            $path = $line.Substring(
                $pathStart
            )


            [bool]$remove = $false


            # ------------------------------------------------
            # Exact removal
            # ------------------------------------------------

            if (
                $exactRemovals.ContainsKey(
                    $path
                )
            ) {

                $remove = $true
            }
            elseif (
                $removedDirectoryRoots.Count -gt 0
            ) {

                # --------------------------------------------
                # Walk ancestor chain
                # --------------------------------------------

                $slash = $path.LastIndexOf("\")


                while ($slash -gt 2) {

                    $ancestor = $path.Substring(
                        0,
                        $slash
                    )


                    if (
                        $removedDirectoryRoots.ContainsKey(
                            $ancestor
                        )
                    ) {

                        $remove = $true

                        break
                    }


                    $slash = $ancestor.LastIndexOf("\")
                }
            }


            if ($remove) {

                $removed++

                continue
            }


            # ------------------------------------------------
            # Keep record
            # ------------------------------------------------

            $writer.WriteLine(
                $line
            )


            # ------------------------------------------------
            # Count during rebuild
            # ------------------------------------------------

            if ($line[0] -eq "F") {

                $retainedFiles++
            }
            elseif ($line[0] -eq "D") {

                $retainedFolders++
            }


            if (
                $rebuildScanned -ge
                $nextRebuildProgress
            ) {

                $rebuildElapsedNow = (
                    Get-Date
                ) - $rebuildStart


                [double]$rebuildSpeedNow = 0


                if ($rebuildElapsedNow.TotalSeconds -gt 0) {

                    $rebuildSpeedNow = (
                        $rebuildScanned /
                        $rebuildElapsedNow.TotalSeconds
                    )
                }


                $kept = (
                    $retainedFiles +
                    $retainedFolders
                )


                $scanText = Format-Number `
                    -Number $rebuildScanned


                $keptText = Format-Number `
                    -Number $kept


                $removedText = Format-Number `
                    -Number $removed


                $speedText = (
                    "{0:N0}" -f
                    $rebuildSpeedNow
                )


                $statusText = (
                    "Scanned " +
                    $scanText +
                    " | Kept " +
                    $keptText +
                    " | Removed " +
                    $removedText +
                    " | " +
                    $speedText +
                    "/sec"
                )


                Write-Progress `
                    -Activity (
                        "Fast Index Rebuild " +
                        $Drive.Root
                    ) `
                    -Status $statusText


                $nextRebuildProgress = (
                    $rebuildScanned +
                    $RebuildProgressInterval
                )
            }
        }


        # ----------------------------------------------------
        # Append new items
        # ----------------------------------------------------

        foreach ($item in $additions) {

            $safeName = ConvertTo-SafeIndexText `
                -Text $item.Name


            $safePath = ConvertTo-SafeIndexText `
                -Text $item.Path


            $writer.Write(
                $item.Type
            )


            $writer.Write(
                "`t"
            )


            $writer.Write(
                $safeName
            )


            $writer.Write(
                "`t"
            )


            $writer.WriteLine(
                $safePath
            )


            if ($item.Type -eq "F") {

                $addedFiles++
            }
            else {

                $addedFolders++


                [bool]$isReparse = $false

                [bool]$attributeReadOK = $true


                try {

                    $itemAttributes = $item.Info.Attributes


                    $isReparse = (
                        (
                            $itemAttributes -band
                            [System.IO.FileAttributes]::ReparsePoint
                        ) -ne 0
                    )
                }
                catch {

                    $attributeReadOK = $false

                    $addFailures++


                    $failureTime = Get-Date `
                        -Format s


                    $failureText = (
                        "{0}`tNEW_DIR_ATTR`t{1}`t{2}" -f
                        $failureTime,
                        $item.Path,
                        $_.Exception.Message
                    )


                    Add-Content `
                        -LiteralPath $paths.FailureFile `
                        -Encoding UTF8 `
                        -Value $failureText
                }


                if (
                    $attributeReadOK -and
                    -not $isReparse
                ) {

                    Scan-NewSubtree `
                        -Root $item.Path `
                        -Writer $writer `
                        -States $states `
                        -AddedFiles ([ref]$addedFiles) `
                        -AddedFolders ([ref]$addedFolders) `
                        -RetryRecovered ([ref]$retryRecovered) `
                        -Failures ([ref]$addFailures) `
                        -FailureFile $paths.FailureFile
                }
            }
        }


        $writer.Flush()
    }
    finally {

        if ($null -ne $reader) {

            $reader.Close()

            $reader.Dispose()
        }


        if ($null -ne $writer) {

            $writer.Close()

            $writer.Dispose()
        }
    }


    Write-Progress `
        -Activity (
            "Fast Index Rebuild " +
            $Drive.Root
        ) `
        -Completed


    # ========================================================
    # NEW SUBTREE FAILURE PROTECTION
    # ========================================================

    if (
        $addFailures -gt 0 -and
        -not $AllowPartialIndex
    ) {

        Remove-IfExists `
            -Path $paths.TempIndexFile


        Show-Header "Incremental Update Aborted"


        $addFailureText = Format-Number `
            -Number $addFailures


        Write-Host (
            "New subtree failures : " +
            $addFailureText
        )


        Write-Host ""
        Write-Host "Existing index retained."
        Write-Host ""
        Write-Host "Failure log:"
        Write-Host $paths.FailureFile


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # FINAL COUNTS
    # ========================================================

    [long]$newFiles = (
        $retainedFiles +
        $addedFiles
    )


    [long]$newFolders = (
        $retainedFolders +
        $addedFolders
    )


    [long]$newTotal = (
        $newFiles +
        $newFolders
    )


    $rebuildElapsed = (
        Get-Date
    ) - $rebuildStart


    [double]$finalRebuildSpeed = 0


    if ($rebuildElapsed.TotalSeconds -gt 0) {

        $finalRebuildSpeed = (
            $rebuildScanned /
            $rebuildElapsed.TotalSeconds
        )
    }


    # ========================================================
    # SAVE DIRECTORY STATE
    # ========================================================

    Show-Header "Incremental Update - Saving State"


    $stateCountText = Format-Number `
        -Number $states.Count


    Write-Host "Drive       : $($Drive.Root)"
    Write-Host "Directories : $stateCountText"
    Write-Host ""


    try {

        Save-DirectoryStates `
            -States $states `
            -File $paths.TempDirFile
    }
    catch {

        Remove-IfExists `
            -Path $paths.TempIndexFile


        Remove-IfExists `
            -Path $paths.TempDirFile


        Remove-IfExists `
            -Path $paths.TempMetaFile


        Show-Header "Incremental Update Aborted"


        Write-Host "Unable to save directory state."
        Write-Host ""
        Write-Host $_.Exception.Message
        Write-Host ""
        Write-Host "Existing index retained."


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # METADATA
    # ========================================================

    $finishTime = Get-Date


    $elapsed = (
        $finishTime -
        $startTime
    )


    [long]$indexSize = 0


    try {

        $indexItem = Get-Item `
            -LiteralPath $paths.TempIndexFile `
            -ErrorAction Stop


        $indexSize = [long]$indexItem.Length
    }
    catch {
    }


    $serialValue = ""


    if ($null -ne $metadata.Serial) {

        $serialValue = [string]$metadata.Serial
    }
    elseif ($null -ne $Drive.Serial) {

        $serialValue = [string]$Drive.Serial
    }


    $buildTimeValue = ""


    if ($null -ne $metadata.BuildTime) {

        $buildTimeValue = [string]$metadata.BuildTime
    }


    $updateTimeText = (
        $finishTime.ToString(
            "yyyy-MM-dd HH:mm:ss"
        )
    )


    $newMetadata = [PSCustomObject]@{

        Version = "10.4"

        IndexMode = "IncrementalParallelFast"

        DriveRoot = $Drive.Root

        DriveLabel = $Drive.Label

        DriveType = $Drive.Type

        Serial = $serialValue

        BuildTime = $buildTimeValue

        LastSuccessfulUpdate = $updateTimeText

        TotalItems = [long]$newTotal

        Files = [long]$newFiles

        Folders = [long]$newFolders

        IndexedDirectories = [long]$states.Count

        LastCheckedDirectories = [long]$checkedDirectories

        LastChangedDirectories = [long]$changedExisting.Count

        LastDeletedDirectories = [long]$deletedDirectories.Count

        LastAddedFiles = [long]$addedFiles

        LastAddedFolders = [long]$addedFolders

        LastRemovedItems = [long]$removed

        RetryRecovered = [long]$retryRecovered

        FinalFailed = [long]0

        LastIncrementalSeconds = [double]$elapsed.TotalSeconds

        FastMapSeconds = [double]$mapElapsed.TotalSeconds

        FastMapSpeed = [double]$finalMapSpeed

        FastRebuildSeconds = [double]$rebuildElapsed.TotalSeconds

        FastRebuildSpeed = [double]$finalRebuildSpeed

        IndexSize = [long]$indexSize

        IncrementalWorkers = [int]$IncrementalThrottleLimit
    }


    try {

        Write-MetadataFile `
            -Metadata $newMetadata `
            -Path $paths.TempMetaFile
    }
    catch {

        Remove-IfExists `
            -Path $paths.TempIndexFile


        Remove-IfExists `
            -Path $paths.TempDirFile


        Remove-IfExists `
            -Path $paths.TempMetaFile


        Show-Header "Incremental Update Aborted"


        Write-Host "Unable to write metadata."
        Write-Host ""
        Write-Host $_.Exception.Message
        Write-Host ""
        Write-Host "Existing index retained."


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # SAFE COMMIT
    # ========================================================

    Show-Header "Incremental Update - Commit"


    Write-Host "Drive : $($Drive.Root)"
    Write-Host ""
    Write-Host "Committing updated index..."
    Write-Host ""


    try {

        Commit-IndexSet `
            -Paths $paths
    }
    catch {

        Show-Header "Incremental Update - Commit Error"


        Write-Host $_.Exception.Message
        Write-Host ""
        Write-Host "Existing index restoration was attempted."


        if (-not $NoPause) {

            Pause-Tool
        }


        return $false
    }


    # ========================================================
    # COMPLETE
    # ========================================================

    Show-Header "Incremental Update Completed"


    $addedFilesText = Format-Number `
        -Number $addedFiles


    $addedFoldersText = Format-Number `
        -Number $addedFolders


    $removedText = Format-Number `
        -Number $removed


    $filesText = Format-Number `
        -Number $newFiles


    $foldersText = Format-Number `
        -Number $newFolders


    $totalText = Format-Number `
        -Number $newTotal


    $mapSpeedText = (
        "{0:N0}" -f
        $finalMapSpeed
    )


    $buildSpeedText = (
        "{0:N0}" -f
        $finalRebuildSpeed
    )


    $mapTimeText = Format-Duration `
        -Seconds $mapElapsed.TotalSeconds


    $buildTimeText = Format-Duration `
        -Seconds $rebuildElapsed.TotalSeconds


    $totalTimeText = Format-Duration `
        -Seconds $elapsed.TotalSeconds


    $indexSizeText = Format-FileSize `
        -Bytes $indexSize


    Write-Host "Drive       : $($Drive.Root)"
    Write-Host ""
    Write-Host "Checked     : $checkedText"
    Write-Host "Changed     : $changedText"
    Write-Host "Deleted     : $deletedText"
    Write-Host ""
    Write-Host "Files +     : $addedFilesText"
    Write-Host "Folders +   : $addedFoldersText"
    Write-Host "Removed     : $removedText"
    Write-Host ""
    Write-Host "Files       : $filesText"
    Write-Host "Folders     : $foldersText"
    Write-Host "Total       : $totalText"
    Write-Host ""
    Write-Host "Workers     : $IncrementalThrottleLimit"
    Write-Host "Map Speed   : $mapSpeedText records/sec"
    Write-Host "Build Speed : $buildSpeedText records/sec"
    Write-Host ""
    Write-Host "Map Time    : $mapTimeText"
    Write-Host "Build Time  : $buildTimeText"
    Write-Host "Total Time  : $totalTimeText"
    Write-Host ""
    Write-Host "Updated     : $updateTimeText"
    Write-Host "Index Size  : $indexSizeText"


    if (-not $NoPause) {

        Pause-Tool
    }


    return $true
}
# ============================================================
# PART 7
# SEARCH FUNCTIONS
# ============================================================


# ============================================================
# OPEN RESULT HELPERS
# ============================================================

function Open-Folder {

    param(
        [string]$Path
    )


    try {

        Start-Process `
            -FilePath "explorer.exe" `
            -ArgumentList "`"$Path`""
    }
    catch {

        Write-Host $_.Exception.Message

        Pause-Tool
    }
}


function Open-File {

    param(
        [string]$Path
    )


    try {

        Start-Process `
            -FilePath $Path
    }
    catch {

        Write-Host $_.Exception.Message

        Pause-Tool
    }
}


function Select-FileInExplorer {

    param(
        [string]$Path
    )


    try {

        Start-Process `
            -FilePath "explorer.exe" `
            -ArgumentList "/select,`"$Path`""
    }
    catch {

        Write-Host $_.Exception.Message

        Pause-Tool
    }
}


# ============================================================
# SEARCH KEYWORDS
# ============================================================

function Get-SearchKeywords {

    param(
        [string]$InputText
    )


    if (
        [string]::IsNullOrWhiteSpace(
            $InputText
        )
    ) {

        return @()
    }


    return @(
        $InputText.Trim() -split "\s+" |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
    )
}


# ============================================================
# SEARCH PAUSE / STOP
# ============================================================

function Test-SearchControlKey {

    param(
        [ref]$Paused,

        [ref]$StopRequested
    )


    if (-not $EnableSearchPause) {
        return
    }


    try {

        if (-not [Console]::KeyAvailable) {
            return
        }


        $key = [Console]::ReadKey(
            $true
        )


        # ----------------------------------------------------
        # P = Pause
        # ----------------------------------------------------

        if (
            $key.Key -eq
            [ConsoleKey]::P
        ) {

            $Paused.Value = $true


            Write-Host ""
            Write-Host "============================================================"
            Write-Host " SEARCH PAUSED"
            Write-Host "============================================================"
            Write-Host ""
            Write-Host "P = Resume"
            Write-Host "Q = Stop"
            Write-Host ""


            while ($Paused.Value) {

                Start-Sleep `
                    -Milliseconds 100


                if ([Console]::KeyAvailable) {

                    $pauseKey = [Console]::ReadKey(
                        $true
                    )


                    if (
                        $pauseKey.Key -eq
                        [ConsoleKey]::P
                    ) {

                        $Paused.Value = $false
                    }
                    elseif (
                        $pauseKey.Key -eq
                        [ConsoleKey]::Q
                    ) {

                        $StopRequested.Value = $true

                        $Paused.Value = $false
                    }
                }
            }


            return
        }


        # ----------------------------------------------------
        # Q = Stop current search
        # ----------------------------------------------------

        if (
            $key.Key -eq
            [ConsoleKey]::Q
        ) {

            $StopRequested.Value = $true
        }
    }
    catch {
    }
}


# ============================================================
# SINGLE INDEX SEARCH
# ============================================================

function Search-OneIndex {

    param(
        [object]$Drive,

        [string]$SearchText,

        [string]$SearchMode,

        [string]$MatchMode,

        [bool]$EnableKeyboardControl = $true
    )


    $paths = Get-IndexPaths `
        -Root $Drive.Root


    if (
        -not (
            Test-Path `
                -LiteralPath $paths.IndexFile `
                -PathType Leaf
        )
    ) {

        return [PSCustomObject]@{

            Results = @()

            TotalMatches = [long]0

            TotalScanned = [long]0

            ElapsedSeconds = [double]0

            Limited = $false

            StoppedByUser = $false
        }
    }


    $results = New-Object `
        'System.Collections.Generic.List[object]'


    $keywords = @(
        Get-SearchKeywords `
            -InputText $SearchText
    )


    [long]$totalScanned = 0

    [long]$totalMatches = 0


    [bool]$paused = $false

    [bool]$stopRequested = $false

    [bool]$limited = $false


    $startTime = Get-Date


    $reader = $null


    try {

        $reader = New-IndexReader `
            -Path $paths.IndexFile


        while (-not $reader.EndOfStream) {

            $line = $reader.ReadLine()


            $totalScanned++


            # =================================================
            # KEYBOARD CONTROL
            # =================================================

            if (
                $EnableKeyboardControl -and
                (
                    $totalScanned %
                    $SearchKeyCheckInterval
                ) -eq 0
            ) {

                Test-SearchControlKey `
                    -Paused ([ref]$paused) `
                    -StopRequested ([ref]$stopRequested)


                if ($stopRequested) {

                    break
                }
            }


            if (
                [string]::IsNullOrWhiteSpace(
                    $line
                )
            ) {

                continue
            }


            # =================================================
            # PARSE INDEX RECORD
            # =================================================

            $firstTab = $line.IndexOf("`t")


            if ($firstTab -lt 0) {
                continue
            }


            $secondTab = $line.IndexOf(
                "`t",
                $firstTab + 1
            )


            if ($secondTab -lt 0) {
                continue
            }


            $nameLength = (
                $secondTab -
                $firstTab -
                1
            )


            if ($nameLength -lt 0) {
                continue
            }


            $name = $line.Substring(
                $firstTab + 1,
                $nameLength
            )


            if ($SearchMode -eq "Path") {

                $target = $line.Substring(
                    $secondTab + 1
                )
            }
            else {

                $target = $name
            }


            # =================================================
            # MATCH
            # =================================================

            [bool]$matched = $false


            if ($MatchMode -eq "Exact") {

                if ($keywords.Count -eq 1) {

                    $matched = [string]::Equals(
                        $target,
                        $keywords[0],
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
            }
            elseif ($MatchMode -eq "StartsWith") {

                if ($keywords.Count -gt 0) {

                    $matched = $target.StartsWith(
                        $keywords[0],
                        [System.StringComparison]::OrdinalIgnoreCase
                    )


                    if (
                        $matched -and
                        $keywords.Count -gt 1
                    ) {

                        for (
                            $k = 1;
                            $k -lt $keywords.Count;
                            $k++
                        ) {

                            if (
                                $target.IndexOf(
                                    $keywords[$k],
                                    [System.StringComparison]::OrdinalIgnoreCase
                                ) -lt 0
                            ) {

                                $matched = $false

                                break
                            }
                        }
                    }
                }
            }
            else {

                # ------------------------------------------------
                # Contains
                # ------------------------------------------------

                $matched = $true


                foreach ($keyword in $keywords) {

                    if (
                        $target.IndexOf(
                            $keyword,
                            [System.StringComparison]::OrdinalIgnoreCase
                        ) -lt 0
                    ) {

                        $matched = $false

                        break
                    }
                }
            }


            # =================================================
            # PERIODIC SEARCH PROGRESS
            # =================================================

            if (
                (
                    $totalScanned %
                    $SearchProgressInterval
                ) -eq 0
            ) {

                $searchElapsed = (
                    Get-Date
                ) - $startTime


                [double]$searchSpeed = 0


                if (
                    $searchElapsed.TotalSeconds -gt 0
                ) {

                    $searchSpeed = (
                        $totalScanned /
                        $searchElapsed.TotalSeconds
                    )
                }


                $scanText = Format-Number `
                    -Number $totalScanned


                $foundText = Format-Number `
                    -Number $totalMatches


                $speedText = (
                    "{0:N0}" -f
                    $searchSpeed
                )


                $statusText = (
                    "Scanned " +
                    $scanText +
                    " | Found " +
                    $foundText +
                    " | " +
                    $speedText +
                    "/sec"
                )


                if ($EnableKeyboardControl) {

                    $statusText += (
                        " | P Pause | Q Stop"
                    )
                }


                Write-Progress `
                    -Activity (
                        "Fast Search " +
                        $Drive.Root
                    ) `
                    -Status $statusText
            }


            if (-not $matched) {
                continue
            }


            # =================================================
            # MATCH FOUND
            # =================================================

            $totalMatches++


            $type = $line.Substring(
                0,
                $firstTab
            )


            $path = $line.Substring(
                $secondTab + 1
            )


            $resultObject = [PSCustomObject]@{

                Drive = $Drive.Root

                Type = $type

                Name = $name

                FullName = $path

                PSIsContainer = (
                    $type -eq "D"
                )
            }


            $results.Add(
                $resultObject
            )


            # =================================================
            # LIVE RESULT OUTPUT
            # =================================================

            if (
                $EnableKeyboardControl -and
                $ShowResultsImmediately
            ) {

                if ($type -eq "D") {

                    $typeText = "FOLDER"
                }
                else {

                    $typeText = "FILE"
                }


                Write-Host ""

                Write-Host (
                    "[" +
                    [string]$results.Count +
                    "] [" +
                    $typeText +
                    "]"
                )


                Write-Host $path


                Test-SearchControlKey `
                    -Paused ([ref]$paused) `
                    -StopRequested ([ref]$stopRequested)


                if ($stopRequested) {

                    break
                }
            }


            # =================================================
            # RESULT LIMIT
            # =================================================

            if (
                $FastSearchStopAtLimit -and
                $results.Count -ge $MaxDisplayResults
            ) {

                $limited = $true

                break
            }
        }
    }
    finally {

        if ($null -ne $reader) {

            $reader.Close()

            $reader.Dispose()
        }
    }


    Write-Progress `
        -Activity (
            "Fast Search " +
            $Drive.Root
        ) `
        -Completed


    $elapsed = (
        Get-Date
    ) - $startTime


    # --------------------------------------------------------
    # Explicit Generic.List -> PowerShell array conversion
    # --------------------------------------------------------

    $resultArray = @()


    foreach ($item in $results) {

        $resultArray += $item
    }


    return [PSCustomObject]@{

        Results = $resultArray

        TotalMatches = [long]$totalMatches

        TotalScanned = [long]$totalScanned

        ElapsedSeconds = [double]$elapsed.TotalSeconds

        Limited = [bool]$limited

        StoppedByUser = [bool]$stopRequested
    }
}


# ============================================================
# SEARCH INDEXES FAST
#
# Search ONE:
# - Use Search-OneIndex
#
# Search ALL:
# - Parallel search
# - Live result queue
# - Global result numbering
# - Result number = final selectable result number
# - P = Pause
# - Q = Stop
# ============================================================

function Search-IndexesFast {

    param(
        [array]$Drives,

        [string]$SearchText,

        [string]$SearchMode,

        [string]$MatchMode
    )


    # ========================================================
    # NO DRIVE
    # ========================================================

    if ($Drives.Count -eq 0) {

        return [PSCustomObject]@{

            Results = @()

            TotalMatches = [long]0

            TotalScanned = [long]0

            DrivesSearched = [int]0

            ElapsedSeconds = [double]0

            AverageSpeed = [double]0

            Limited = $false

            StoppedByUser = $false
        }
    }


    # ========================================================
    # SEARCH ONE
    # ========================================================

    if ($Drives.Count -eq 1) {

        $single = Search-OneIndex `
            -Drive $Drives[0] `
            -SearchText $SearchText `
            -SearchMode $SearchMode `
            -MatchMode $MatchMode `
            -EnableKeyboardControl $true


        [double]$singleSpeed = 0


        if ($single.ElapsedSeconds -gt 0) {

            $singleSpeed = (
                $single.TotalScanned /
                $single.ElapsedSeconds
            )
        }


        return [PSCustomObject]@{

            Results = $single.Results

            TotalMatches = [long]$single.TotalMatches

            TotalScanned = [long]$single.TotalScanned

            DrivesSearched = [int]1

            ElapsedSeconds = [double]$single.ElapsedSeconds

            AverageSpeed = [double]$singleSpeed

            Limited = [bool]$single.Limited

            StoppedByUser = [bool]$single.StoppedByUser
        }
    }


    # ========================================================
    # SHARED LIVE RESULT QUEUE
    # ========================================================

    $resultQueue = New-Object `
        'System.Collections.Concurrent.ConcurrentQueue[object]'


    $shared = [hashtable]::Synchronized(
        @{
            Pause = $false

            Stop = $false

            DisplayCount = [long]0

            Limited = $false
        }
    )


    # ========================================================
    # SEARCH ALL WORKER
    # ========================================================

    $workerScript = {

        param(
            $IndexFile,

            $DriveRoot,

            $SearchText,

            $SearchMode,

            $MatchMode,

            $MaxDisplayResults,

            $BufferSize,

            $Shared,

            $WorkerID,

            $ResultQueue
        )


        # ====================================================
        # KEYWORDS
        # ====================================================

        $keywords = @(
            $SearchText.Trim() -split "\s+" |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
        )


        [long]$scanned = 0

        [long]$matches = 0


        [bool]$stopped = $false


        $reader = $null


        try {

            $reader = New-Object `
                -TypeName System.IO.StreamReader `
                -ArgumentList @(
                    $IndexFile,
                    [System.Text.Encoding]::UTF8,
                    $true,
                    $BufferSize
                )


            while (-not $reader.EndOfStream) {

                # =============================================
                # STOP
                # =============================================

                if ([bool]$Shared["Stop"]) {

                    $stopped = $true

                    break
                }


                # =============================================
                # PAUSE
                # =============================================

                while ([bool]$Shared["Pause"]) {

                    if ([bool]$Shared["Stop"]) {

                        $stopped = $true

                        break
                    }


                    Start-Sleep `
                        -Milliseconds 100
                }


                if ($stopped) {

                    break
                }


                # =============================================
                # READ
                # =============================================

                $line = $reader.ReadLine()


                $scanned++


                if (
                    [string]::IsNullOrWhiteSpace(
                        $line
                    )
                ) {

                    continue
                }


                # =============================================
                # PARSE
                # =============================================

                $firstTab = $line.IndexOf("`t")


                if ($firstTab -lt 0) {

                    continue
                }


                $secondTab = $line.IndexOf(
                    "`t",
                    $firstTab + 1
                )


                if ($secondTab -lt 0) {

                    continue
                }


                $nameLength = (
                    $secondTab -
                    $firstTab -
                    1
                )


                if ($nameLength -lt 0) {

                    continue
                }


                $name = $line.Substring(
                    $firstTab + 1,
                    $nameLength
                )


                if ($SearchMode -eq "Path") {

                    $target = $line.Substring(
                        $secondTab + 1
                    )
                }
                else {

                    $target = $name
                }


                # =============================================
                # MATCH
                # =============================================

                [bool]$matched = $false


                # ---------------------------------------------
                # EXACT
                # ---------------------------------------------

                if ($MatchMode -eq "Exact") {

                    if ($keywords.Count -eq 1) {

                        $matched = [string]::Equals(
                            $target,
                            $keywords[0],
                            [System.StringComparison]::OrdinalIgnoreCase
                        )
                    }
                }

                # ---------------------------------------------
                # STARTS WITH
                # ---------------------------------------------

                elseif ($MatchMode -eq "StartsWith") {

                    if ($keywords.Count -gt 0) {

                        $matched = $target.StartsWith(
                            $keywords[0],
                            [System.StringComparison]::OrdinalIgnoreCase
                        )


                        if (
                            $matched -and
                            $keywords.Count -gt 1
                        ) {

                            for (
                                $k = 1;
                                $k -lt $keywords.Count;
                                $k++
                            ) {

                                if (
                                    $target.IndexOf(
                                        $keywords[$k],
                                        [System.StringComparison]::OrdinalIgnoreCase
                                    ) -lt 0
                                ) {

                                    $matched = $false

                                    break
                                }
                            }
                        }
                    }
                }

                # ---------------------------------------------
                # CONTAINS
                # ---------------------------------------------

                else {

                    $matched = $true


                    foreach ($keyword in $keywords) {

                        if (
                            $target.IndexOf(
                                $keyword,
                                [System.StringComparison]::OrdinalIgnoreCase
                            ) -lt 0
                        ) {

                            $matched = $false

                            break
                        }
                    }
                }


                # =============================================
                # PERIODIC COUNTER UPDATE
                # =============================================

                if (
                    (
                        $scanned %
                        5000
                    ) -eq 0
                ) {

                    $Shared[
                        "Scan_$WorkerID"
                    ] = [long]$scanned


                    $Shared[
                        "Match_$WorkerID"
                    ] = [long]$matches
                }


                if (-not $matched) {

                    continue
                }


                # =============================================
                # FOUND
                # =============================================

                $matches++


                $type = $line.Substring(
                    0,
                    $firstTab
                )


                $path = $line.Substring(
                    $secondTab + 1
                )


                # =============================================
                # GLOBAL RESULT NUMBER
                #
                # Lock ensures:
                #
                # number order
                # =
                # queue order
                # =
                # final selectable order
                # =============================================

                [System.Threading.Monitor]::Enter(
                    $Shared.SyncRoot
                )


                try {

                    [long]$currentDisplayCount = (
                        [long]$Shared["DisplayCount"]
                    )


                    if (
                        $currentDisplayCount -lt
                        $MaxDisplayResults
                    ) {

                        $currentDisplayCount++


                        $Shared["DisplayCount"] = (
                            [long]$currentDisplayCount
                        )


                        $resultObject = [PSCustomObject]@{

                            Number = (
                                [long]$currentDisplayCount
                            )

                            Drive = $DriveRoot

                            Type = $type

                            Name = $name

                            FullName = $path

                            PSIsContainer = (
                                $type -eq "D"
                            )
                        }


                        $ResultQueue.Enqueue(
                            $resultObject
                        )
                    }
                    else {

                        $Shared["Limited"] = $true
                    }
                }
                finally {

                    [System.Threading.Monitor]::Exit(
                        $Shared.SyncRoot
                    )
                }


                $Shared[
                    "Scan_$WorkerID"
                ] = [long]$scanned


                $Shared[
                    "Match_$WorkerID"
                ] = [long]$matches
            }
        }
        finally {

            if ($null -ne $reader) {

                $reader.Close()

                $reader.Dispose()
            }
        }


        # ====================================================
        # FINAL COUNTERS
        # ====================================================

        $Shared[
            "Scan_$WorkerID"
        ] = [long]$scanned


        $Shared[
            "Match_$WorkerID"
        ] = [long]$matches


        $Shared[
            "Done_$WorkerID"
        ] = $true


        return [PSCustomObject]@{

            Drive = $DriveRoot

            TotalMatches = [long]$matches

            TotalScanned = [long]$scanned

            Stopped = [bool]$stopped
        }
    }


    # ========================================================
    # RUNSPACE POOL
    # ========================================================

    $workerCount = [math]::Min(
        $SearchThrottleLimit,
        $Drives.Count
    )


    if ($workerCount -lt 1) {

        $workerCount = 1
    }


    $pool = $null


    $workers = New-Object `
        'System.Collections.Generic.List[object]'


    # Final result order follows live displayed order.
    $liveResults = New-Object `
        'System.Collections.Generic.List[object]'


    $startTime = Get-Date


    try {

        $pool = [RunspaceFactory]::CreateRunspacePool(
            1,
            $workerCount
        )


        $pool.Open()


        [int]$workerID = 0


        foreach ($drive in $Drives) {

            $paths = Get-IndexPaths `
                -Root $drive.Root


            if (
                -not (
                    Test-Path `
                        -LiteralPath $paths.IndexFile `
                        -PathType Leaf
                )
            ) {

                continue
            }


            $workerID++


            $scanKey = (
                "Scan_" +
                [string]$workerID
            )


            $matchKey = (
                "Match_" +
                [string]$workerID
            )


            $doneKey = (
                "Done_" +
                [string]$workerID
            )


            $shared[$scanKey] = [long]0

            $shared[$matchKey] = [long]0

            $shared[$doneKey] = $false


            $ps = [PowerShell]::Create()


            $ps.RunspacePool = $pool


            [void]$ps.AddScript(
                $workerScript
            )


            [void]$ps.AddArgument(
                $paths.IndexFile
            )


            [void]$ps.AddArgument(
                $drive.Root
            )


            [void]$ps.AddArgument(
                $SearchText
            )


            [void]$ps.AddArgument(
                $SearchMode
            )


            [void]$ps.AddArgument(
                $MatchMode
            )


            [void]$ps.AddArgument(
                $MaxDisplayResults
            )


            [void]$ps.AddArgument(
                $StreamBufferSize
            )


            [void]$ps.AddArgument(
                $shared
            )


            [void]$ps.AddArgument(
                $workerID
            )


            [void]$ps.AddArgument(
                $resultQueue
            )


            $async = $ps.BeginInvoke()


            $workers.Add(
                [PSCustomObject]@{

                    ID = $workerID

                    Drive = $drive.Root

                    PowerShell = $ps

                    Async = $async
                }
            )
        }


        # ====================================================
        # LIVE LOOP
        # ========================================================

        [bool]$paused = $false

        [bool]$stoppedByUser = $false


        while ($true) {

            # =================================================
            # LIVE RESULTS
            # =================================================

            [bool]$printedResult = $false


            $queuedResult = $null


            while (
                $resultQueue.TryDequeue(
                    [ref]$queuedResult
                )
            ) {

                if ($null -eq $queuedResult) {

                    continue
                }


                # ---------------------------------------------
                # Store in exact same order as display
                # ---------------------------------------------

                $liveResults.Add(
                    $queuedResult
                )


                if ($ShowResultsImmediately) {

                    # -----------------------------------------
                    # Important:
                    # temporarily close progress display before
                    # writing normal console output.
                    # -----------------------------------------

                    if (-not $printedResult) {

                        Write-Progress `
                            -Activity "Fast Search ALL Indexed Drives" `
                            -Completed


                        $printedResult = $true
                    }


                    if ($queuedResult.Type -eq "D") {

                        $typeText = "FOLDER"
                    }
                    else {

                        $typeText = "FILE"
                    }


                    Write-Host ""


                    Write-Host (
                        "[" +
                        [string]$queuedResult.Number +
                        "] [" +
                        [string]$queuedResult.Drive +
                        "] [" +
                        $typeText +
                        "]"
                    )


                    Write-Host (
                        $queuedResult.FullName
                    )
                }


                $queuedResult = $null
            }


            # =================================================
            # WORKER STATUS
            # =================================================

            [int]$finishedWorkers = 0


            [long]$liveScanned = 0

            [long]$liveMatches = 0


            foreach ($worker in $workers) {

                if ($worker.Async.IsCompleted) {

                    $finishedWorkers++
                }


                $scanKey = (
                    "Scan_" +
                    [string]$worker.ID
                )


                $matchKey = (
                    "Match_" +
                    [string]$worker.ID
                )


                $liveScanned += (
                    [long]$shared[$scanKey]
                )


                $liveMatches += (
                    [long]$shared[$matchKey]
                )
            }


            # =================================================
            # SPEED
            # =================================================

            $elapsedNow = (
                Get-Date
            ) - $startTime


            [double]$liveSpeed = 0


            if ($elapsedNow.TotalSeconds -gt 0) {

                $liveSpeed = (
                    $liveScanned /
                    $elapsedNow.TotalSeconds
                )
            }


            $scanText = Format-Number `
                -Number $liveScanned


            $matchText = Format-Number `
                -Number $liveMatches


            $speedText = (
                "{0:N0}" -f
                $liveSpeed
            )


            $statusText = (
                "Scanned " +
                $scanText +
                " | Found " +
                $matchText +
                " | " +
                $speedText +
                "/sec | Drives " +
                [string]$finishedWorkers +
                "/" +
                [string]$workers.Count +
                " | P Pause | Q Stop"
            )


            # =================================================
            # REDRAW PROGRESS
            # =================================================

            Write-Progress `
                -Activity "Fast Search ALL Indexed Drives" `
                -Status $statusText


            # =================================================
            # KEYBOARD
            # =================================================

            try {

                if ([Console]::KeyAvailable) {

                    $key = [Console]::ReadKey(
                        $true
                    )


                    # -----------------------------------------
                    # P
                    # -----------------------------------------

                    if (
                        $key.Key -eq
                        [ConsoleKey]::P
                    ) {

                        if ($paused) {

                            $paused = $false

                            $shared["Pause"] = $false
                        }
                        else {

                            $paused = $true

                            $shared["Pause"] = $true


                            Write-Progress `
                                -Activity "Fast Search ALL Indexed Drives" `
                                -Completed


                            Write-Host ""
                            Write-Host "============================================================"
                            Write-Host " SEARCH ALL PAUSED"
                            Write-Host "============================================================"
                            Write-Host ""
                            Write-Host "P = Resume"
                            Write-Host "Q = Stop"
                            Write-Host ""
                        }
                    }

                    # -----------------------------------------
                    # Q
                    # -----------------------------------------

                    elseif (
                        $key.Key -eq
                        [ConsoleKey]::Q
                    ) {

                        $stoppedByUser = $true

                        $shared["Stop"] = $true

                        $shared["Pause"] = $false

                        $paused = $false
                    }
                }
            }
            catch {
            }


            # =================================================
            # COMPLETE?
            # =================================================

            if (
                $finishedWorkers -eq
                $workers.Count
            ) {

                break
            }


            Start-Sleep `
                -Milliseconds 100
        }


        # ====================================================
        # FINAL QUEUE FLUSH
        # ====================================================

        Write-Progress `
            -Activity "Fast Search ALL Indexed Drives" `
            -Completed


        $queuedResult = $null


        while (
            $resultQueue.TryDequeue(
                [ref]$queuedResult
            )
        ) {

            if ($null -eq $queuedResult) {

                continue
            }


            $liveResults.Add(
                $queuedResult
            )


            if ($ShowResultsImmediately) {

                if ($queuedResult.Type -eq "D") {

                    $typeText = "FOLDER"
                }
                else {

                    $typeText = "FILE"
                }


                Write-Host ""


                Write-Host (
                    "[" +
                    [string]$queuedResult.Number +
                    "] [" +
                    [string]$queuedResult.Drive +
                    "] [" +
                    $typeText +
                    "]"
                )


                Write-Host (
                    $queuedResult.FullName
                )
            }


            $queuedResult = $null
        }


        # ====================================================
        # COLLECT COUNTS
        # ====================================================

        [long]$totalScanned = 0

        [long]$totalMatches = 0


        foreach ($worker in $workers) {

            try {

                $workerResults = @(
                    $worker.PowerShell.EndInvoke(
                        $worker.Async
                    )
                )


                foreach ($workerResult in $workerResults) {

                    if ($null -eq $workerResult) {

                        continue
                    }


                    $totalScanned += (
                        [long]$workerResult.TotalScanned
                    )


                    $totalMatches += (
                        [long]$workerResult.TotalMatches
                    )
                }
            }
            finally {

                $worker.PowerShell.Dispose()
            }
        }


        # ====================================================
        # FINAL ARRAY
        # ====================================================

        $resultArray = @()


        foreach ($item in $liveResults) {

            $resultArray += $item
        }


        $elapsed = (
            Get-Date
        ) - $startTime


        [double]$speed = 0


        if ($elapsed.TotalSeconds -gt 0) {

            $speed = (
                $totalScanned /
                $elapsed.TotalSeconds
            )
        }


        [bool]$limited = (
            [bool]$shared["Limited"]
        )


        return [PSCustomObject]@{

            Results = $resultArray

            TotalMatches = [long]$totalMatches

            TotalScanned = [long]$totalScanned

            DrivesSearched = [int]$workers.Count

            ElapsedSeconds = [double]$elapsed.TotalSeconds

            AverageSpeed = [double]$speed

            Limited = [bool]$limited

            StoppedByUser = [bool]$stoppedByUser
        }
    }
    finally {

        foreach ($worker in $workers) {

            try {

                if ($null -ne $worker.PowerShell) {

                    if (
                        -not $worker.Async.IsCompleted
                    ) {

                        $worker.PowerShell.Stop()
                    }


                    $worker.PowerShell.Dispose()
                }
            }
            catch {
            }
        }


        if ($null -ne $pool) {

            try {

                $pool.Close()

                $pool.Dispose()
            }
            catch {
            }
        }
    }
}

# ============================================================
# PART 8
# UI / MENU / MAIN
# ============================================================


# ============================================================
# SEARCH UI
# ============================================================

function Start-Search {

    param(
        [array]$Drives,

        [string]$Title
    )


    $searchMode = $DefaultSearchMode

    $matchMode = "Contains"


    while ($true) {

        Show-Header $Title


        Write-Host (
            "Search Mode : " +
            $searchMode
        )


        Write-Host (
            "Match Mode  : " +
            $matchMode
        )


        Write-Host ""

        Write-Host "[1] Contains"
        Write-Host "[2] StartsWith"
        Write-Host "[3] Exact"
        Write-Host "[T] Toggle Name / Path"
        Write-Host "[M] Main Menu"
        Write-Host "[Q] Quit"
        Write-Host ""


        $searchText = Read-Host "Keyword"


        if ($searchText -match "^[Qq]$") {

            return "Quit"
        }


        if ($searchText -match "^[Mm]$") {

            return "MainMenu"
        }


        if ($searchText -match "^[Tt]$") {

            if ($searchMode -eq "Name") {

                $searchMode = "Path"
            }
            else {

                $searchMode = "Name"
            }


            continue
        }


        if ($searchText -eq "1") {

            $matchMode = "Contains"

            continue
        }


        if ($searchText -eq "2") {

            $matchMode = "StartsWith"

            continue
        }


        if ($searchText -eq "3") {

            $matchMode = "Exact"

            continue
        }


        if (
            [string]::IsNullOrWhiteSpace(
                $searchText
            )
        ) {

            continue
        }


        Show-Header "Search Results"


        Write-Host (
            "Keyword : " +
            $searchText
        )


        Write-Host (
            "Target  : " +
            $searchMode
        )


        Write-Host (
            "Match   : " +
            $matchMode
        )


        Write-Host ""


        if ($Drives.Count -eq 1) {

            Write-Host "P = Pause / Resume"

            Write-Host "Q = Stop current search"

            Write-Host ""
        }


        $search = Search-IndexesFast `
            -Drives $Drives `
            -SearchText $searchText `
            -SearchMode $searchMode `
            -MatchMode $matchMode


        $results = @(
            $search.Results
        )


        Write-Host ""
        Write-Host "============================================================"
        Write-Host " SEARCH COMPLETE"
        Write-Host "============================================================"
        Write-Host ""


        $drivesText = [string]$search.DrivesSearched


        $scannedText = Format-Number `
            -Number $search.TotalScanned


        $matchesText = Format-Number `
            -Number $search.TotalMatches


        $displayText = Format-Number `
            -Number $results.Count


        $timeText = (
            "{0:N3}" -f
            $search.ElapsedSeconds
        )


        $speedText = (
            "{0:N0}" -f
            $search.AverageSpeed
        )


        Write-Host (
            "Drives searched : " +
            $drivesText
        )


        Write-Host (
            "Records scanned : " +
            $scannedText
        )


        Write-Host (
            "Matches found   : " +
            $matchesText
        )


        Write-Host (
            "Displayed       : " +
            $displayText
        )


        Write-Host (
            "Search time     : " +
            $timeText +
            " sec"
        )


        Write-Host (
            "Search speed    : " +
            $speedText +
            " records/sec"
        )


        if ($search.Limited) {

            Write-Host ""

            Write-Host (
                "Result limit reached: " +
                [string]$MaxDisplayResults
            )
        }


        if ($search.StoppedByUser) {

            Write-Host ""

            Write-Host "Search stopped by user."
        }


        Write-Host ""


        if ($results.Count -eq 0) {

            Write-Host "No results."


            Pause-Tool


            continue
        }


        # ----------------------------------------------------
        # When single-drive live output is enabled, results
        # were already printed during scanning.
        #
        # Multi-drive search prints results here.
        # ----------------------------------------------------

        if (-not $ShowResultsImmediately) {

    		for (
        		$i = 0;
        		$i -lt $results.Count;
        		$i++
    	) {

        		$result = $results[$i]


        if ($result.Type -eq "D") {

            $typeText = "FOLDER"
        }
        else {

            $typeText = "FILE"
        }


        $resultNumber = (
            $i +
            1
        )


        Write-Host (
            "[" +
            [string]$resultNumber +
            "] [" +
            $typeText +
            "]"
        )


        Write-Host (
            $result.FullName
        )


        Write-Host ""
    }
}


        Write-Host "Number    : Open result"
        Write-Host "F<number> : Open containing folder"
        Write-Host "Enter     : New search"
        Write-Host "M         : Main menu"
        Write-Host "Q         : Quit"
        Write-Host ""


        while ($true) {

            $choice = Read-Host "Choice"


            if (
                [string]::IsNullOrWhiteSpace(
                    $choice
                )
            ) {

                break
            }


            if ($choice -match "^[Qq]$") {

                return "Quit"
            }


            if ($choice -match "^[Mm]$") {

                return "MainMenu"
            }


            # =================================================
            # F<number>
            # =================================================

            if (
                $choice -match
                "^[Ff](\d+)$"
            ) {

                $number = (
                    [int]$Matches[1]
                )


                if (
                    $number -ge 1 -and
                    $number -le $results.Count
                ) {

                    $selected = (
                        $results[
                            $number - 1
                        ]
                    )


                    if ($selected.PSIsContainer) {

                        Open-Folder `
                            -Path $selected.FullName
                    }
                    else {

                        Select-FileInExplorer `
                            -Path $selected.FullName
                    }
                }


                continue
            }


            # =================================================
            # NUMBER
            # =================================================

            [int]$number = 0


            if (
                [int]::TryParse(
                    $choice,
                    [ref]$number
                )
            ) {

                if (
                    $number -ge 1 -and
                    $number -le $results.Count
                ) {

                    $selected = (
                        $results[
                            $number - 1
                        ]
                    )


                    if ($selected.PSIsContainer) {

                        Open-Folder `
                            -Path $selected.FullName
                    }
                    else {

                        Open-File `
                            -Path $selected.FullName
                    }
                }
            }
        }
    }
}


# ============================================================
# DRIVE SELECTION
# ============================================================

function Select-Drive {

    param(
        [array]$Drives,

        [string]$Title
    )


    while ($true) {

        Show-Header $Title


        for (
            $i = 0;
            $i -lt $Drives.Count;
            $i++
        ) {

            $drive = $Drives[$i]


            $meta = Get-IndexMetadata `
                -Drive $drive


            if (-not $drive.Accessible) {

                $status = "UNAVAILABLE"
            }
            elseif ($null -eq $meta) {

                $status = "MISSING"
            }
            else {

                $status = "READY"
            }


            $driveNumber = (
                $i +
                1
            )


            Write-Host (
                "[" +
                [string]$driveNumber +
                "] " +
                $drive.Root +
                " [" +
                $status +
                "]"
            )


            Write-Host (
                "    Name : " +
                $drive.Label
            )


            Write-Host (
                "    Type : " +
                $drive.Type
            )


            if ($drive.TotalSize -gt 0) {

                $sizeText = Format-FileSize `
                    -Bytes $drive.TotalSize


                Write-Host (
                    "    Size : " +
                    $sizeText
                )
            }


            if ($null -ne $meta) {

                $itemText = Format-Number `
                    -Number (
                        [long]$meta.TotalItems
                    )


                Write-Host (
                    "    Items: " +
                    $itemText
                )


                Write-Host (
                    "    Last : " +
                    [string]$meta.LastSuccessfulUpdate
                )
            }


            Write-Host ""
        }


        Write-Host "[00] Back"
        Write-Host ""


        $choice = Read-Host "Drive"


        if ($choice -eq "00") {

            return $null
        }


        [int]$number = 0


        if (
            [int]::TryParse(
                $choice,
                [ref]$number
            )
        ) {

            if (
                $number -ge 1 -and
                $number -le $Drives.Count
            ) {

                return (
                    $Drives[
                        $number - 1
                    ]
                )
            }
        }
    }
}


# ============================================================
# INDEX STATISTICS
# ============================================================

function Show-IndexStatistics {

    param(
        [array]$Drives
    )


    Show-Header "Index Statistics"


    [long]$grandTotal = 0


    foreach ($drive in $Drives) {

        $meta = Get-IndexMetadata `
            -Drive $drive


        Write-Host (
            $drive.Root
        )


        if ($null -eq $meta) {

            Write-Host "  Status : MISSING"

            Write-Host ""

            continue
        }


        $itemsText = Format-Number `
            -Number (
                [long]$meta.TotalItems
            )


        $filesText = Format-Number `
            -Number (
                [long]$meta.Files
            )


        $foldersText = Format-Number `
            -Number (
                [long]$meta.Folders
            )


        Write-Host "  Status : READY"

        Write-Host (
            "  Items  : " +
            $itemsText
        )


        Write-Host (
            "  Files  : " +
            $filesText
        )


        Write-Host (
            "  Folders: " +
            $foldersText
        )


        Write-Host (
            "  Last   : " +
            [string]$meta.LastSuccessfulUpdate
        )


        if ($null -ne $meta.IndexMode) {

            Write-Host (
                "  Mode   : " +
                [string]$meta.IndexMode
            )
        }


        if ($null -ne $meta.IndexSize) {

            $indexSizeText = Format-FileSize `
                -Bytes (
                    [long]$meta.IndexSize
                )


            Write-Host (
                "  Size   : " +
                $indexSizeText
            )
        }


        if ($null -ne $meta.FullBuildWorkers) {

            Write-Host (
                "  Full Workers : " +
                [string]$meta.FullBuildWorkers
            )
        }


        if ($null -ne $meta.IncrementalWorkers) {

            Write-Host (
                "  Inc Workers  : " +
                [string]$meta.IncrementalWorkers
            )
        }


        if ($null -ne $meta.FastMapSpeed) {

            $mapSpeedText = (
                "{0:N0}" -f
                [double]$meta.FastMapSpeed
            )


            Write-Host (
                "  Map/sec      : " +
                $mapSpeedText
            )
        }


        if ($null -ne $meta.FastRebuildSpeed) {

            $rebuildSpeedText = (
                "{0:N0}" -f
                [double]$meta.FastRebuildSpeed
            )


            Write-Host (
                "  Rebuild/sec  : " +
                $rebuildSpeedText
            )
        }


        Write-Host ""


        $grandTotal += (
            [long]$meta.TotalItems
        )
    }


    Write-Host "============================================================"


    $grandTotalText = Format-Number `
        -Number $grandTotal


    Write-Host (
        "Total indexed items: " +
        $grandTotalText
    )


    Pause-Tool
}


# ============================================================
# MAIN MENU
# ============================================================

function Show-MainMenu {

    while ($true) {

        try {

            $Host.UI.RawUI.WindowTitle = (
                "Folder Search Tool V10.4"
            )
        }
        catch {
        }


        $drives = @(
            Get-AvailableDrives
        )


        Show-Header "Folder Search Tool V10.4 Parallel Fast Edition"


        # ====================================================
        # DRIVE OVERVIEW
        # ====================================================

        for (
            $i = 0;
            $i -lt $drives.Count;
            $i++
        ) {

            $drive = $drives[$i]


            $meta = Get-IndexMetadata `
                -Drive $drive


            if (-not $drive.Accessible) {

                $status = "UNAVAILABLE"
            }
            elseif ($null -eq $meta) {

                $status = "MISSING"
            }
            else {

                $status = "READY"
            }


            $driveNumber = (
                $i +
                1
            )


            Write-Host (
                "[" +
                [string]$driveNumber +
                "] " +
                $drive.Root +
                " [" +
                $status +
                "]"
            )


            Write-Host (
                "    Name : " +
                $drive.Label
            )


            Write-Host (
                "    Type : " +
                $drive.Type
            )


            if ($drive.TotalSize -gt 0) {

                $sizeText = Format-FileSize `
                    -Bytes $drive.TotalSize


                Write-Host (
                    "    Size : " +
                    $sizeText
                )
            }


            if ($null -ne $meta) {

                $itemText = Format-Number `
                    -Number (
                        [long]$meta.TotalItems
                    )


                Write-Host (
                    "    Items: " +
                    $itemText
                )


                Write-Host (
                    "    Last : " +
                    [string]$meta.LastSuccessfulUpdate
                )
            }


            Write-Host ""
        }


        Write-Host "============================================================"
        Write-Host ""

        Write-Host "[A] Search ALL indexed drives"
        Write-Host "[B] Incremental Update ALL indexed drives"
        Write-Host "[C] Incremental Update ONE drive"
        Write-Host "[D] Parallel Full Build / Rebuild ONE drive"
        Write-Host "[E] Parallel Build MISSING drives"
        Write-Host "[F] Index Statistics"
        Write-Host "[S] Search ONE drive"
        Write-Host "[R] Refresh"
        Write-Host "[Q] Quit"
        Write-Host ""


        $choice = Read-Host "Choice"


        # ====================================================
        # QUIT
        # ====================================================

        if ($choice -match "^[Qq]$") {

            return
        }


        # ====================================================
        # REFRESH
        # ====================================================

        if ($choice -match "^[Rr]$") {

            continue
        }


        # ====================================================
        # A - SEARCH ALL
        # ====================================================

        if ($choice -match "^[Aa]$") {

            $indexed = @()


            foreach ($drive in $drives) {

                $meta = Get-IndexMetadata `
                    -Drive $drive


                if ($null -ne $meta) {

                    $indexed += $drive
                }
            }


            if ($indexed.Count -eq 0) {

                Write-Host ""
                Write-Host "No indexed drives."


                Pause-Tool


                continue
            }


            $result = Start-Search `
                -Drives $indexed `
                -Title "Parallel Search ALL Indexed Drives"


            if ($result -eq "Quit") {

                return
            }


            continue
        }


        # ====================================================
        # B - INCREMENTAL UPDATE ALL
        # ====================================================

        if ($choice -match "^[Bb]$") {

            Show-Header "Incremental Update ALL"


            Write-Host (
                "Workers per drive : " +
                [string]$IncrementalThrottleLimit
            )


            Write-Host ""


            $confirm = Read-Host "Type YES to continue"


            if ($confirm -ne "YES") {

                continue
            }


            [int]$successCount = 0

            [int]$failedCount = 0

            [int]$skippedCount = 0


            foreach ($drive in $drives) {

                if (-not $drive.Accessible) {

                    $skippedCount++

                    continue
                }


                $meta = Get-IndexMetadata `
                    -Drive $drive


                if ($null -eq $meta) {

                    $skippedCount++

                    continue
                }


                $ok = Update-IncrementalIndex `
                    -Drive $drive `
                    -NoPause


                if ($ok) {

                    $successCount++
                }
                else {

                    $failedCount++
                }
            }


            Show-Header "Incremental Update ALL Completed"


            Write-Host (
                "Successful : " +
                [string]$successCount
            )


            Write-Host (
                "Failed     : " +
                [string]$failedCount
            )


            Write-Host (
                "Skipped    : " +
                [string]$skippedCount
            )


            Pause-Tool


            continue
        }


        # ====================================================
        # C - INCREMENTAL UPDATE ONE
        # ====================================================

        if ($choice -match "^[Cc]$") {

            $drive = Select-Drive `
                -Drives $drives `
                -Title "Incremental Update ONE Drive"


            if ($null -eq $drive) {

                continue
            }


            if (-not $drive.Accessible) {

                Write-Host ""
                Write-Host "Drive unavailable."


                Pause-Tool


                continue
            }


            $meta = Get-IndexMetadata `
                -Drive $drive


            if ($null -eq $meta) {

                Write-Host ""
                Write-Host "No valid index."
                Write-Host "Run Full Build first."


                Pause-Tool


                continue
            }


            Update-IncrementalIndex `
                -Drive $drive |
                Out-Null


            continue
        }


        # ====================================================
        # D - FULL BUILD / REBUILD ONE
        # ====================================================

        if ($choice -match "^[Dd]$") {

            $drive = Select-Drive `
                -Drives $drives `
                -Title "Parallel Full Build / Rebuild"


            if ($null -eq $drive) {

                continue
            }


            if (-not $drive.Accessible) {

                Write-Host ""
                Write-Host "Drive unavailable."


                Pause-Tool


                continue
            }


            $existing = Get-IndexMetadata `
                -Drive $drive


            if ($null -ne $existing) {

                Write-Host ""
                Write-Host "Existing index found."
                Write-Host ""
                Write-Host "Normal daily use should use Incremental Update."
                Write-Host ""


                $confirm = Read-Host "Type REBUILD to continue"


                if ($confirm -ne "REBUILD") {

                    continue
                }
            }


            Build-FullIndex `
                -Drive $drive |
                Out-Null


            continue
        }


        # ====================================================
        # E - BUILD MISSING
        # ====================================================

        if ($choice -match "^[Ee]$") {

            Show-Header "Parallel Build MISSING Drives"


            Write-Host (
                "Workers per drive : " +
                [string]$FullBuildThrottleLimit
            )


            Write-Host ""


            $confirm = Read-Host "Type YES to build missing drives"


            if ($confirm -ne "YES") {

                continue
            }


            [int]$builtCount = 0

            [int]$failedCount = 0

            [int]$skippedCount = 0


            foreach ($drive in $drives) {

                if (-not $drive.Accessible) {

                    $skippedCount++

                    continue
                }


                $existing = Get-IndexMetadata `
                    -Drive $drive


                if ($null -ne $existing) {

                    $skippedCount++

                    continue
                }


                $ok = Build-FullIndex `
                    -Drive $drive `
                    -NoPause


                if ($ok) {

                    $builtCount++
                }
                else {

                    $failedCount++
                }
            }


            Show-Header "Build MISSING Completed"


            Write-Host (
                "Built   : " +
                [string]$builtCount
            )


            Write-Host (
                "Failed  : " +
                [string]$failedCount
            )


            Write-Host (
                "Skipped : " +
                [string]$skippedCount
            )


            Pause-Tool


            continue
        }


        # ====================================================
        # F - STATISTICS
        # ====================================================

        if ($choice -match "^[Ff]$") {

            Show-IndexStatistics `
                -Drives $drives


            continue
        }


        # ====================================================
        # S - SEARCH ONE
        # ====================================================

        if ($choice -match "^[Ss]$") {

            $drive = Select-Drive `
                -Drives $drives `
                -Title "Search ONE Drive"


            if ($null -eq $drive) {

                continue
            }


            $meta = Get-IndexMetadata `
                -Drive $drive


            if ($null -eq $meta) {

                Write-Host ""
                Write-Host "No valid index."


                Pause-Tool


                continue
            }


            $searchTitle = (
                "Search " +
                $drive.Root
            )


            $result = Start-Search `
                -Drives @($drive) `
                -Title $searchTitle


            if ($result -eq "Quit") {

                return
            }


            continue
        }
    }
}


# ============================================================
# MAIN ENTRY
# ============================================================

if (-not $Script:FolderSearchLibraryMode) {

    try {

        Show-MainMenu
    }
    catch {

        Show-Header "Fatal Error"


        Write-Host "Unexpected program error:"
        Write-Host ""

        Write-Host $_.Exception.Message
        Write-Host ""


        Write-Host "Line:"

        Write-Host (
            $_.InvocationInfo.ScriptLineNumber
        )

        Write-Host ""


        Write-Host "Script:"

        Write-Host (
            $_.InvocationInfo.Line
        )

        Write-Host ""


        Write-Host "Position:"

        Write-Host (
            $_.InvocationInfo.PositionMessage
        )

        Write-Host ""


        Read-Host "Press Enter to exit" |
            Out-Null
    }


    try {

        $Host.UI.RawUI.WindowTitle = (
            "Folder Search Tool V10.4"
        )
    }
    catch {
    }


    Show-Header "Folder Search Tool V10.4"

    Write-Host "Program closed."
    Write-Host ""
}
