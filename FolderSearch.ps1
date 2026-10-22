# ==========================================
# Folder Search Tool
# Windows PowerShell 5.1 Compatible
# ==========================================

$Host.UI.RawUI.WindowTitle = "Folder Search Tool"

$MaxSearchResults = 1000


# ==========================================
# Pause
# ==========================================

function Pause-Tool {

    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
}


# ==========================================
# Header
# ==========================================

function Show-Header {

    param(
        [string]$Title
    )

    Clear-Host

    Write-Host "=========================================="
    Write-Host " $Title"
    Write-Host "=========================================="
    Write-Host ""
}


# ==========================================
# Open Folder
# ==========================================

function Open-Folder {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {

        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$Path`""
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] Unable to open folder:"
        Write-Host $Path
        Write-Host ""
        Write-Host $_.Exception.Message

        Pause-Tool
    }
}


# ==========================================
# Open File
# ==========================================

function Open-File {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {

        # Select file in Explorer
        Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$Path`""

        # Open file with default program
        Start-Process -FilePath $Path
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] Unable to open file:"
        Write-Host $Path
        Write-Host ""
        Write-Host $_.Exception.Message

        Pause-Tool
    }
}


# ==========================================
# Get Available Drives
# ==========================================

function Get-AvailableDrives {

    $drives = @()

    # IMPORTANT:
    # Do not use backtick line continuation here
    $fileSystemDrives = @(
        Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue
    )

    foreach ($drive in $fileSystemDrives) {

        $root = $drive.Root

        $displayName = "LocalDrive"
        $driveType   = "Local"
        $provider    = ""

        # ======================================
        # Detect drive information
        # ======================================

        try {

            $deviceID = "$($drive.Name):"

            $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$deviceID'" -ErrorAction Stop

            if ($null -ne $disk) {

                switch ($disk.DriveType) {

                    2 {

                        $displayName = "Removable"
                        $driveType   = "Removable"
                    }

                    3 {

                        $driveType = "Local"

                        if (-not [string]::IsNullOrWhiteSpace($disk.VolumeName)) {

                            $displayName = $disk.VolumeName
                        }
                        else {

                            $displayName = "LocalDrive"
                        }
                    }

                    4 {

                        $driveType = "Network"

                        if (-not [string]::IsNullOrWhiteSpace($disk.ProviderName)) {

                            $displayName = $disk.ProviderName
                            $provider    = $disk.ProviderName
                        }
                        elseif (-not [string]::IsNullOrWhiteSpace($drive.DisplayRoot)) {

                            $displayName = $drive.DisplayRoot
                            $provider    = $drive.DisplayRoot
                        }
                        else {

                            $displayName = "NetworkDrive"
                        }
                    }

                    5 {

                        $displayName = "CD/DVD"
                        $driveType   = "Optical"
                    }

                    default {

                        $displayName = "Drive"
                    }
                }
            }
        }
        catch {

            # CIM failed.
            # Try PSDrive DisplayRoot instead.

            if (-not [string]::IsNullOrWhiteSpace($drive.DisplayRoot)) {

                $displayName = $drive.DisplayRoot
                $provider    = $drive.DisplayRoot
                $driveType   = "Network"
            }
        }


        # ======================================
        # Check accessibility
        # ======================================

        $accessible = $false

        try {

            $accessible = Test-Path -LiteralPath $root -ErrorAction Stop
        }
        catch {

            $accessible = $false
        }


        # ======================================
        # Add drive
        # ======================================

        $drives += [PSCustomObject]@{

            Name       = $drive.Name
            Root       = $root
            Label      = $displayName
            Type       = $driveType
            Provider   = $provider
            Accessible = $accessible
        }
    }

    return @(
        $drives | Sort-Object Name
    )
}


# ==========================================
# Select Drive
# ==========================================

function Select-Drive {

    while ($true) {

        Show-Header "Folder Search Tool"

        Write-Host "Available Drives"
        Write-Host "------------------------------------------"

        $drives = @(Get-AvailableDrives)

        if ($drives.Count -eq 0) {

            Write-Host ""
            Write-Host "No available drives found."

            Pause-Tool
            continue
        }


        # ======================================
        # Show Drives
        # ======================================

        for ($i = 0; $i -lt $drives.Count; $i++) {

            if ($drives[$i].Accessible) {

                $status = "OK"
            }
            else {

                $status = "Unavailable"
            }

            Write-Host "$($i + 1). $($drives[$i].Name): [$($drives[$i].Type)] $($drives[$i].Label) [$status]"
        }

        Write-Host ""
        Write-Host "Q. Quit"
        Write-Host ""

        $selection = Read-Host "Select Drive Number"


        # ======================================
        # Quit
        # ======================================

        if ($selection -match "^[Qq]$") {

            return $null
        }


        # ======================================
        # Validate Selection
        # ======================================

        $number = 0

        if ([int]::TryParse($selection, [ref]$number)) {

            if ($number -ge 1 -and $number -le $drives.Count) {

                $selectedDrive = $drives[$number - 1]

                if (-not $selectedDrive.Accessible) {

                    Write-Host ""
                    Write-Host "[WARNING] Drive is currently unavailable."
                    Write-Host ""
                    Write-Host "Drive:"
                    Write-Host $selectedDrive.Root

                    if (-not [string]::IsNullOrWhiteSpace($selectedDrive.Provider)) {

                        Write-Host ""
                        Write-Host "Network Path:"
                        Write-Host $selectedDrive.Provider
                    }

                    Pause-Tool
                    continue
                }

                return $selectedDrive.Root
            }
        }

        Write-Host ""
        Write-Host "Invalid Selection"

        Pause-Tool
    }
}


# ==========================================
# Read Current Folder
# ==========================================

function Get-CurrentItems {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {

        $exists = Test-Path -LiteralPath $Path -ErrorAction Stop
    }
    catch {

        $exists = $false
    }


    # ======================================
    # Path unavailable
    # ======================================

    if (-not $exists) {

        return @{
            Folders = @()
            Files   = @()
            Success = $false
            Error   = "Path does not exist or cannot be accessed."
        }
    }


    # ======================================
    # Read contents
    # ======================================

    try {

        $items = @(
            Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop
        )

        $folders = @(
            $items |
            Where-Object { $_.PSIsContainer } |
            Sort-Object Name
        )

        $files = @(
            $items |
            Where-Object { -not $_.PSIsContainer } |
            Sort-Object Name
        )

        return @{
            Folders = $folders
            Files   = $files
            Success = $true
            Error   = ""
        }
    }
    catch {

        return @{
            Folders = @()
            Files   = @()
            Success = $false
            Error   = $_.Exception.Message
        }
    }
}


# ==========================================
# Current Folder Keyword Search
# ==========================================

function Search-CurrentFolder {

    param(
        [Parameter(Mandatory = $true)]
        [array]$Items,

        [Parameter(Mandatory = $true)]
        [string]$Keyword
    )

    if ([string]::IsNullOrWhiteSpace($Keyword)) {

        return @()
    }

    return @(
        $Items |
        Where-Object {

            $_.Name.IndexOf(
                $Keyword,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0
        }
    )
}


# ==========================================
# Recursive Search
# ==========================================

function Search-Recursive {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    while ($true) {

        Show-Header "Search Mode"

        Write-Host "Search Path:"
        Write-Host $Path
        Write-Host ""

        Write-Host "00. Back"
        Write-Host ""

        $keyword = Read-Host "Enter Keyword"

        if ($keyword -eq "00") {

            return $null
        }

        if ([string]::IsNullOrWhiteSpace($keyword)) {

            continue
        }


        Write-Host ""
        Write-Host "Searching..."
        Write-Host "Maximum Results : $MaxSearchResults"
        Write-Host "------------------------------------------"


        # ======================================
        # Search
        # ======================================

        $searchErrors = @()

        try {

            $allSearchItems = @(
                Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +searchErrors
            )

            $results = @(
                $allSearchItems |
                Where-Object {

                    $_.Name.IndexOf(
                        $keyword,
                        [System.StringComparison]::OrdinalIgnoreCase
                    ) -ge 0

                } |
                Select-Object -First $MaxSearchResults
            )
        }
        catch {

            Write-Host ""
            Write-Host "[ERROR] Search failed."
            Write-Host ""
            Write-Host $_.Exception.Message

            Pause-Tool
            continue
        }


        Write-Host ""


        # ======================================
        # No Results
        # ======================================

        if ($results.Count -eq 0) {

            Write-Host "No Result Found"

            if ($searchErrors.Count -gt 0) {

                Write-Host ""
                Write-Host "WARNING:"
                Write-Host "Some folders could not be accessed."
                Write-Host "Error / skipped count: $($searchErrors.Count)"
            }

            Pause-Tool
            continue
        }


        # ======================================
        # Show Results
        # ======================================

        for ($i = 0; $i -lt $results.Count; $i++) {

            $item = $results[$i]

            if ($item.PSIsContainer) {

                $type = "[Folder]"
            }
            else {

                $type = "[File]"
            }

            Write-Host "$($i + 1). $type $($item.Name)"
            Write-Host "    $($item.FullName)"
        }


        Write-Host ""
        Write-Host "------------------------------------------"
        Write-Host "Found $($results.Count) Result(s)"


        if ($searchErrors.Count -gt 0) {

            Write-Host ""
            Write-Host "WARNING:"
            Write-Host "Some folders could not be accessed."
            Write-Host "Error / skipped count: $($searchErrors.Count)"
        }


        if ($results.Count -ge $MaxSearchResults) {

            Write-Host ""
            Write-Host "WARNING:"
            Write-Host "Maximum result limit reached."
            Write-Host "Additional matching items may exist."
        }


        Write-Host "------------------------------------------"
        Write-Host ""
        Write-Host "00. Back"
        Write-Host ""


        # ======================================
        # Select Result
        # ======================================

        $choice = Read-Host "Select Result Number"

        if ($choice -eq "00") {

            return $null
        }

        $number = 0

        if (-not [int]::TryParse($choice, [ref]$number)) {

            Write-Host ""
            Write-Host "Invalid Selection"

            Pause-Tool
            continue
        }

        if ($number -lt 1 -or $number -gt $results.Count) {

            Write-Host ""
            Write-Host "Invalid Selection"

            Pause-Tool
            continue
        }


        $selected = $results[$number - 1]


        # ======================================
        # Folder Result
        # ======================================

        if ($selected.PSIsContainer) {

            return @{
                Action = "Navigate"
                Path   = $selected.FullName
            }
        }


        # ======================================
        # File Result
        # ======================================

        Open-File -Path $selected.FullName

        Pause-Tool

        return $null
    }
}


# ==========================================
# Folder Navigation
# ==========================================

function Start-FolderNavigation {

    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPath
    )

    $CurrentPath = $StartPath

    try {

        $RootPath = [System.IO.Path]::GetPathRoot($StartPath)
    }
    catch {

        $RootPath = $StartPath
    }


    while ($true) {

        Show-Header "Current Path"

        Write-Host $CurrentPath
        Write-Host ""

        Write-Host "0.  Search Here"
        Write-Host "00. Go Back"
        Write-Host "99. Open Current Folder"
        Write-Host ""


        # ======================================
        # Read Directory
        # ======================================

        $currentItems = Get-CurrentItems -Path $CurrentPath


        if (-not $currentItems.Success) {

            Write-Host "[ERROR] Unable to read folder:"
            Write-Host $CurrentPath
            Write-Host ""
            Write-Host "Reason:"
            Write-Host $currentItems.Error
            Write-Host ""

            Write-Host "00. Go Back"
            Write-Host "99. Open Current Folder"
            Write-Host ""

            $errorSelection = Read-Host "Select"


            if ($errorSelection -eq "00") {

                if ($CurrentPath -eq $RootPath) {

                    return
                }

                try {

                    $parent = Split-Path -LiteralPath $CurrentPath -Parent

                    if ([string]::IsNullOrWhiteSpace($parent)) {

                        $CurrentPath = $RootPath
                    }
                    else {

                        $CurrentPath = $parent
                    }
                }
                catch {

                    $CurrentPath = $RootPath
                }

                continue
            }


            if ($errorSelection -eq "99") {

                Open-Folder -Path $CurrentPath
                continue
            }

            continue
        }


        # ======================================
        # Folders / Files
        # ======================================

        $folders = @($currentItems.Folders)
        $files   = @($currentItems.Files)

        $allItems = @()


        # ======================================
        # Show Folders
        # ======================================

        Write-Host "Folders"
        Write-Host "------------------------------------------"


        if ($folders.Count -eq 0) {

            Write-Host "(No folders)"
        }
        else {

            foreach ($folder in $folders) {

                $allItems += $folder

                Write-Host "$($allItems.Count). [Folder] $($folder.Name)"
            }
        }


        # ======================================
        # Show Files
        # ======================================

        Write-Host ""
        Write-Host "Files"
        Write-Host "------------------------------------------"


        if ($files.Count -eq 0) {

            Write-Host "(No files)"
        }
        else {

            foreach ($file in $files) {

                $allItems += $file

                Write-Host "$($allItems.Count). [File] $($file.Name)"
            }
        }


        Write-Host ""
        Write-Host "------------------------------------------"


        $selection = Read-Host "Number or Keyword"


        # ======================================
        # Recursive Search
        # ======================================

        if ($selection -eq "0") {

            $searchResult = Search-Recursive -Path $CurrentPath

            if ($searchResult -and $searchResult.Action -eq "Navigate") {

                $CurrentPath = $searchResult.Path
            }

            continue
        }


        # ======================================
        # Explorer
        # ======================================

        if ($selection -eq "99") {

            Open-Folder -Path $CurrentPath
            continue
        }


        # ======================================
        # Back
        # ======================================

        if ($selection -eq "00") {

            if ($CurrentPath -eq $RootPath) {

                return
            }

            try {

                $parent = Split-Path -LiteralPath $CurrentPath -Parent

                if ([string]::IsNullOrWhiteSpace($parent)) {

                    $CurrentPath = $RootPath
                }
                else {

                    $CurrentPath = $parent
                }
            }
            catch {

                $CurrentPath = $RootPath
            }

            continue
        }


        # ======================================
        # Number Selection
        # ======================================

        $number = 0

        if ([int]::TryParse($selection, [ref]$number)) {

            if ($number -ge 1 -and $number -le $allItems.Count) {

                $selected = $allItems[$number - 1]

                if ($selected.PSIsContainer) {

                    $CurrentPath = $selected.FullName
                }
                else {

                    Open-File -Path $selected.FullName
                }

                continue
            }
        }


        # ======================================
        # Empty Input
        # ======================================

        if ([string]::IsNullOrWhiteSpace($selection)) {

            continue
        }


        # ======================================
        # Keyword Search
        # ======================================

        $matches = @(
            Search-CurrentFolder -Items $allItems -Keyword $selection
        )


        # ======================================
        # No Match
        # ======================================

        if ($matches.Count -eq 0) {

            Write-Host ""
            Write-Host "No Match Found"

            Pause-Tool
            continue
        }


        # ======================================
        # One Match
        # ======================================

        if ($matches.Count -eq 1) {

            $selected = $matches[0]

            if ($selected.PSIsContainer) {

                $CurrentPath = $selected.FullName
            }
            else {

                Open-File -Path $selected.FullName
            }

            continue
        }


        # ======================================
        # Multiple Matches
        # ======================================

        Write-Host ""

        for ($i = 0; $i -lt $matches.Count; $i++) {

            $match = $matches[$i]

            if ($match.PSIsContainer) {

                $type = "[Folder]"
            }
            else {

                $type = "[File]"
            }

            Write-Host "Match $($i + 1) : $type $($match.Name)"
        }


        Write-Host ""
        Write-Host "00. Cancel"
        Write-Host ""


        $pick = Read-Host "Select Match Number"


        if ($pick -eq "00") {

            continue
        }


        $pickNumber = 0


        if (-not [int]::TryParse($pick, [ref]$pickNumber)) {

            Write-Host ""
            Write-Host "Invalid Selection"

            Pause-Tool
            continue
        }


        if ($pickNumber -lt 1 -or $pickNumber -gt $matches.Count) {

            Write-Host ""
            Write-Host "Invalid Selection"

            Pause-Tool
            continue
        }


        $selected = $matches[$pickNumber - 1]


        if ($selected.PSIsContainer) {

            $CurrentPath = $selected.FullName
        }
        else {

            Open-File -Path $selected.FullName
        }
    }
}


# ==========================================
# Main
# ==========================================

while ($true) {

    $selectedDrive = Select-Drive

    if ([string]::IsNullOrWhiteSpace($selectedDrive)) {

        break
    }

    Start-FolderNavigation -StartPath $selectedDrive
}
