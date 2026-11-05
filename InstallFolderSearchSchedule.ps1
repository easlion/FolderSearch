# ============================================================
# Install Folder Search Automatic Update Schedule
#
# Daily:
# 09:00
# 12:00
# 16:00
#
# Windows PowerShell 5.1
# ============================================================


$TaskName = "FolderSearch Auto Incremental Update"


$AutoScript = (
    "D:\Tools\FolderSearchAutoUpdate.ps1"
)


$WorkingDirectory = (
    "D:\Tools"
)


# ============================================================
# CHECK SCRIPT
# ============================================================

if (
    -not (
        Test-Path `
            -LiteralPath $AutoScript `
            -PathType Leaf
    )
) {

    Write-Host ""
    Write-Host "Auto update script not found:"
    Write-Host $AutoScript
    Write-Host ""

    Read-Host "Press Enter to exit" |
        Out-Null

    exit 1
}


# ============================================================
# ACTION
# ============================================================

$argumentText = (
    '-NoProfile -ExecutionPolicy Bypass -File "' +
    $AutoScript +
    '"'
)


$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $argumentText `
    -WorkingDirectory $WorkingDirectory


# ============================================================
# THREE DAILY TRIGGERS
# ============================================================

$trigger0900 = New-ScheduledTaskTrigger `
    -Daily `
    -At "09:00"


$trigger1200 = New-ScheduledTaskTrigger `
    -Daily `
    -At "12:00"


$trigger1600 = New-ScheduledTaskTrigger `
    -Daily `
    -At "16:00"


$triggers = @(
    $trigger0900,
    $trigger1200,
    $trigger1600
)


# ============================================================
# SETTINGS
#
# MultipleInstances IgnoreNew:
#
# If 09:00 update is still running at 12:00,
# Windows will NOT launch another copy.
# ============================================================

$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -ExecutionTimeLimit (
        New-TimeSpan `
            -Hours 8
    )


# ============================================================
# CURRENT USER
#
# Interactive logon is intentional because mapped network
# drives such as V: normally belong to the interactive user
# session.
# ============================================================

$currentIdentity = (
    [System.Security.Principal.WindowsIdentity]::GetCurrent()
)


$currentUser = (
    $currentIdentity.Name
)


$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Limited


# ============================================================
# TASK
# ============================================================

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Principal $principal `
    -Description (
        "Folder Search automatic incremental update at 09:00, 12:00 and 16:00."
    )


try {

    Register-ScheduledTask `
        -TaskName $TaskName `
        -InputObject $task `
        -Force `
        -ErrorAction Stop |
        Out-Null
}
catch {

    Write-Host ""
    Write-Host "Unable to create scheduled task."
    Write-Host ""

    Write-Host $_.Exception.Message

    Write-Host ""

    Write-Host "If access is denied, run this installer once as Administrator."

    Write-Host ""

    Read-Host "Press Enter to exit" |
        Out-Null

    exit 2
}


# ============================================================
# RESULT
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " Folder Search Schedule Installed"
Write-Host "============================================================"
Write-Host ""

Write-Host (
    "Task : " +
    $TaskName
)

Write-Host ""

Write-Host "Daily schedules:"
Write-Host "  09:00"
Write-Host "  12:00"
Write-Host "  16:00"

Write-Host ""

Write-Host (
    "User : " +
    $currentUser
)

Write-Host ""

Write-Host "Duplicate execution:"
Write-Host "  Ignore new instance if previous update is still running."

Write-Host ""

Write-Host "Log:"
Write-Host (
    Join-Path `
        $env:LOCALAPPDATA `
        "FolderSearchV83\AutoUpdate.log"
)

Write-Host ""

Read-Host "Press Enter to exit" |
    Out-Null
