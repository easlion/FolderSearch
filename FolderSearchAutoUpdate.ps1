# ============================================================
# Folder Search Auto Incremental Update V11
# Windows PowerShell 5.1 Compatible
#
# Features:
# - Automatic Incremental Update ALL indexed drives
# - Prevent duplicate execution
# - Log start / finish / errors
# - Log rotation
# - Reuse FolderSearchV11.ps1 functions
# ============================================================


# ============================================================
# CONFIGURATION
# ============================================================

$MainScript = "D:\Tools\FolderSearchV11.ps1"

$AppName = "FolderSearchV83"

$DataFolder = Join-Path `
    $env:LOCALAPPDATA `
    $AppName


# ============================================================
# AUTO UPDATE LOG / LOCK LOCATION
# ============================================================

$ToolsFolder = "D:\Tools"


$LogFolder = Join-Path `
    $ToolsFolder `
    "Log"

$LogFile = Join-Path `
    $LogFolder `
    "AutoUpdate.log"


$OldLogFile = Join-Path `
    $LogFolder `
    "AutoUpdate.log.old"


$LockFile = Join-Path `
    $LogFolder `
    "AutoUpdate.lock"

# 10 MB
$MaxLogSize = 10MB


# ============================================================
# CREATE DATA FOLDER
# ============================================================

if (
    -not (
        Test-Path `
            -LiteralPath $DataFolder
    )
) {

    try {

        New-Item `
            -ItemType Directory `
            -Path $DataFolder `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }
    catch {

        exit 10
    }
}

# ============================================================
# CREATE TOOLS FOLDER
# ============================================================

if (
    -not (
        Test-Path `
            -LiteralPath $ToolsFolder
    )
) {

    try {

        New-Item `
            -ItemType Directory `
            -Path $ToolsFolder `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }
    catch {

        exit 11
    }
}

# ============================================================
# CREATE LOG FOLDER
# ============================================================

if (
    -not (
        Test-Path `
            -LiteralPath $LogFolder
    )
) {

    try {

        New-Item `
            -ItemType Directory `
            -Path $LogFolder `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }
    catch {

        exit 12
    }
}

# ============================================================
# LOG ROTATION
# ============================================================

try {

    if (
        Test-Path `
            -LiteralPath $LogFile `
            -PathType Leaf
    ) {

        $logItem = Get-Item `
            -LiteralPath $LogFile `
            -ErrorAction Stop


        if ($logItem.Length -ge $MaxLogSize) {

            if (
                Test-Path `
                    -LiteralPath $OldLogFile
            ) {

                Remove-Item `
                    -LiteralPath $OldLogFile `
                    -Force `
                    -ErrorAction SilentlyContinue
            }


            Move-Item `
                -LiteralPath $LogFile `
                -Destination $OldLogFile `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
catch {
}


# ============================================================
# LOG FUNCTION
# ============================================================

function Write-AutoLog {

    param(
        [string]$Message,

        [string]$Level = "INFO"
    )


    $timestamp = Get-Date `
        -Format "yyyy-MM-dd HH:mm:ss"


    $line = (
        $timestamp +
        " [" +
        $Level +
        "] " +
        $Message
    )


    try {

        Add-Content `
            -LiteralPath $LogFile `
            -Value $line `
            -Encoding UTF8
    }
    catch {
    }


    Write-Host $line
}


# ============================================================
# PREVENT DUPLICATE EXECUTION
#
# FileShare.None means:
# only one AutoUpdate process can hold this file.
# ============================================================

$lockStream = $null


try {

    $lockStream = New-Object `
        -TypeName System.IO.FileStream `
        -ArgumentList @(
            $LockFile,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
}
catch {

    Write-AutoLog `
        -Message "Another AutoUpdate process is already running. This run was skipped." `
        -Level "SKIP"


    exit 20
}


# ============================================================
# START
# ============================================================

try {

    Write-AutoLog `
        -Message "============================================================"


    Write-AutoLog `
        -Message "Automatic incremental update started."


    Write-AutoLog `
        -Message (
            "Computer: " +
            $env:COMPUTERNAME
        )


    Write-AutoLog `
        -Message (
            "User: " +
            $env:USERNAME
        )


    # ========================================================
    # MAIN SCRIPT CHECK
    # ========================================================

    if (
        -not (
            Test-Path `
                -LiteralPath $MainScript `
                -PathType Leaf
        )
    ) {

        Write-AutoLog `
            -Message (
                "Main script not found: " +
                $MainScript
            ) `
            -Level "ERROR"


        exit 30
    }


    # ========================================================
    # LOAD MAIN PROGRAM FUNCTIONS
    # ========================================================

    $Script:FolderSearchLibraryMode = $true


    try {

        . $MainScript
    }
    catch {

        Write-AutoLog `
            -Message (
                "Unable to load main script: " +
                $_.Exception.Message
            ) `
            -Level "ERROR"


        exit 31
    }


    Write-AutoLog `
        -Message "Main Folder Search functions loaded."


    # ========================================================
    # GET DRIVES
    # ========================================================

    try {

        $drives = @(
            Get-AvailableDrives
        )
    }
    catch {

        Write-AutoLog `
            -Message (
                "Drive detection failed: " +
                $_.Exception.Message
            ) `
            -Level "ERROR"


        exit 32
    }


    Write-AutoLog `
        -Message (
            "Detected drives: " +
            [string]$drives.Count
        )


    # ========================================================
    # COUNTERS
    # ========================================================

    [int]$successCount = 0

    [int]$failedCount = 0

    [int]$skippedCount = 0

    [int]$indexedCount = 0


    $autoStartTime = Get-Date


    # ========================================================
    # UPDATE ALL INDEXED DRIVES
    # ========================================================

    foreach ($drive in $drives) {

        $driveRoot = (
            [string]$drive.Root
        )


        # ----------------------------------------------------
        # Drive unavailable
        # ----------------------------------------------------

        if (-not $drive.Accessible) {

            Write-AutoLog `
                -Message (
                    "Skipped unavailable drive: " +
                    $driveRoot
                ) `
                -Level "SKIP"


            $skippedCount++

            continue
        }


        # ----------------------------------------------------
        # Check existing index
        # ----------------------------------------------------

        try {

            $meta = Get-IndexMetadata `
                -Drive $drive
        }
        catch {

            Write-AutoLog `
                -Message (
                    "Unable to read metadata for " +
                    $driveRoot +
                    ": " +
                    $_.Exception.Message
                ) `
                -Level "ERROR"


            $failedCount++

            continue
        }


        if ($null -eq $meta) {

            Write-AutoLog `
                -Message (
                    "Skipped drive without valid index: " +
                    $driveRoot
                ) `
                -Level "SKIP"


            $skippedCount++

            continue
        }


        $indexedCount++


        # ----------------------------------------------------
        # Start individual drive
        # ----------------------------------------------------

        Write-AutoLog `
            -Message (
                "Starting incremental update: " +
                $driveRoot
            )


        $driveStartTime = Get-Date


        try {

            $ok = Update-IncrementalIndex `
                -Drive $drive `
                -NoPause


            $driveElapsed = (
                Get-Date
            ) - $driveStartTime


            $driveElapsedText = (
                "{0:00}:{1:00}:{2:00}" -f
                [math]::Floor(
                    $driveElapsed.TotalHours
                ),
                $driveElapsed.Minutes,
                $driveElapsed.Seconds
            )


            if ($ok) {

                $successCount++


                Write-AutoLog `
                    -Message (
                        "Incremental update completed: " +
                        $driveRoot +
                        " | Time " +
                        $driveElapsedText
                    ) `
                    -Level "SUCCESS"
            }
            else {

                $failedCount++


                Write-AutoLog `
                    -Message (
                        "Incremental update returned failure: " +
                        $driveRoot +
                        " | Time " +
                        $driveElapsedText
                    ) `
                    -Level "ERROR"
            }
        }
        catch {

            $failedCount++


            Write-AutoLog `
                -Message (
                    "Incremental update exception: " +
                    $driveRoot +
                    " | " +
                    $_.Exception.Message
                ) `
                -Level "ERROR"
        }
    }


    # ========================================================
    # COMPLETE SUMMARY
    # ========================================================

    $autoElapsed = (
        Get-Date
    ) - $autoStartTime


    $totalElapsedText = (
        "{0:00}:{1:00}:{2:00}" -f
        [math]::Floor(
            $autoElapsed.TotalHours
        ),
        $autoElapsed.Minutes,
        $autoElapsed.Seconds
    )


    Write-AutoLog `
        -Message "------------------------------------------------------------"


    Write-AutoLog `
        -Message (
            "Indexed drives : " +
            [string]$indexedCount
        )


    Write-AutoLog `
        -Message (
            "Successful     : " +
            [string]$successCount
        )


    Write-AutoLog `
        -Message (
            "Failed         : " +
            [string]$failedCount
        )


    Write-AutoLog `
        -Message (
            "Skipped        : " +
            [string]$skippedCount
        )


    Write-AutoLog `
        -Message (
            "Total time     : " +
            $totalElapsedText
        )


    Write-AutoLog `
        -Message "Automatic incremental update finished."


    Write-AutoLog `
        -Message "============================================================"


    if ($failedCount -gt 0) {

        exit 1
    }


    exit 0
}
finally {

    # ========================================================
    # RELEASE LOCK
    # ========================================================

    if ($null -ne $lockStream) {

        try {

            $lockStream.Close()

            $lockStream.Dispose()
        }
        catch {
        }
    }
}
