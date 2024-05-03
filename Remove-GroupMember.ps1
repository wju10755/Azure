$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$date = Get-Date -Format "yyyyMMdd_HHmmss"
Start-Transcript -Path "./output/transcripts/transcript_$date.txt" | Out-Null
 
# Title Screen
Write-Output '------------------------------------------------------------------------------------------------------------------'
Write-Output "                                                            EasyJob - Schedule Group Member Removal        "
Write-Output '------------------------------------------------------------------------------------------------------------------'
Write-Output " "
$resourcegroup = "mits-automation" 
$automationAccount = "mits-automation" 
$ScheduleName = "Revoke-GeoExclude"
$Runbook = "Remove-GroupMember"
$hours = $args[2]
$days = $args[3]
$min = $args[4]

Write-Host -ForegroundColor Yellow "===Powershell Module Verification==="
#AzureAD Module Check
If (Get-Module -ListAvailable -name Az.Accounts) {
    Write-Output "Az.Accounts PowerShell Module Detected"
    Write-Output " "
}
else {
    Write-Host -ForegroundColor Red "Az.Accounts Module not found!"
    Write-Output "Installing Az.Accounts Module, please wait..."
    Install-Module -Name Az.Accounts -Scope CurrentUser -AllowClobber 
    Write-Output " "
}

Write-Host -ForegroundColor Yellow "===Azure Tenant Authentication==="
 
Start-Sleep -Milliseconds 500
# Connect to your Azure account and suppress the output
$connection = Connect-AzAccount
# Check if the connection was successful
if ($connection) {
    Write-Output "Connected to Azure Successfully"
} else {
    Write-Output "Failed to connect to AzureAD."
    Write-Host -ForegroundColor Red "Failed to connect to Azure"
}

# Get the current subscription
$subscription = Get-AzSubscription | Out-Null

# Set subscription id
Set-AzContext -SubscriptionId $subscription.Id | Out-Null

Write-Output " "
Write-Host -ForegroundColor Yellow "===Schedule $Runbook Runbook==="
# Runbook parameters (UPN & Group Name)
$params = @{
    "TargetUPN" = $args[0]
    "groupName" = $args[1]
}
$FinalTargetUPN = $params.TargetUPN
$FinalgroupName = $params.groupName

# Check if the user is a member of the group
$groupMembers = Get-AzADGroupMember -ObjectId (Get-AzADGroup -SearchString $FinalgroupName).Id

if ($groupMembers | Where-Object { $_.UserPrincipalName -eq $FinalTargetUPN }) {
    #Write-Output "$FinalTargetUPN is a member of the $FinalgroupName group."

    # Register runbook with the schedule
    Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccount -RunbookName $Runbook -ScheduleName $scheduleName -ResourceGroupName $resourcegroup -Parameters $params | Out-Null

    # Check if $hours is not null and not 0
    if ($hours -ne $null -and $hours -ne 0) {
        # Create a new onetime schedule to run in the next few hours
        New-AzAutomationSchedule -ResourceGroupName $resourcegroup -AutomationAccountName $automationAccount -Name 'Revoke-GeoExclude' -StartTime (Get-Date).AddHours($hours) -OneTime -ErrorAction SilentlyContinue
    } 
    # Check if $days is not null and not 0
    elseif ($days -ne $null -and $days -ne 0) {
        # Create a new onetime schedule to run in the future
        New-AzAutomationSchedule -ResourceGroupName $resourcegroup -AutomationAccountName $automationAccount -Name 'Revoke-GeoExclude' -StartTime (Get-Date).AddDays($days) -OneTime -ErrorAction SilentlyContinue
    }
    # Check if $min is not null and not 0
    elseif ($min -ne $null -and $min -ne 0) {
        # Create a new onetime schedule to run in the future
        New-AzAutomationSchedule -ResourceGroupName $resourcegroup -AutomationAccountName $automationAccount -Name 'Revoke-GeoExclude' -StartTime (Get-Date).AddMinutes($min) -OneTime -ErrorAction SilentlyContinue
    }

    # Register runbook with the schedule
    Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccount -RunbookName $Runbook -ScheduleName $scheduleName -ResourceGroupName $resourcegroup -Parameters $params.Parameters | Out-Null

    Start-Sleep -Seconds 3
    # Get the schedule
    $schedule = Get-AzAutomationSchedule -ResourceGroupName $resourcegroup -AutomationAccountName $automationAccount -Name $scheduleName
    Write-Output " "
    if ($schedule) {
        Write-Host -ForegroundColor Yellow "===Schedule Verification===" 
        Write-Output "Runbook '$Runbook' was scheduled successfully."
    } else {
        Write-Output "$Runbook runbook was not scheduled!"
    }
} else {
    Write-Output "$FinalTargetUPN is not a member of the $FinalgroupName group."
}
Write-Output " "
Stop-Transcript | Out-Null
Get-PSsession | Remove-Pssession
