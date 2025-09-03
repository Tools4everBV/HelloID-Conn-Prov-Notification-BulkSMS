#####################################################
# HelloID-Conn-Prov-Notification-BulkSMS
# PowerShell Notification System
#####################################################

# Debug
if ($actionContext.DryRun -eq $true) {
    $actionContext.TemplateConfiguration.scriptFlow = 'SMS'
    $actionContext.TemplateConfiguration.timezone = 'W. Europe Standard Time'
    $actionContext.TemplateConfiguration.time = '08:00:00'
    $actionContext.TemplateConfiguration.recipient = '+31612345678'
    $actionContext.TemplateConfiguration.body = 'Test message'
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-BulkSMSError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            if ($errorDetailsObject.detail) {
                $httpErrorObj.FriendlyMessage = $errorDetailsObject.detail
            }
        }
        catch {
            $httpErrorObj.FriendlyMessage = "Error: [$($httpErrorObj.ErrorDetails)] [$($_.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    if ($($actionContext.TemplateConfiguration.scriptFlow) -eq "SMS") {
        $actionMessage = 'creating headers'
        $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
        $tokenID = $actionContext.Configuration.tokenID
        $tokenSecret = $actionContext.Configuration.tokenSecret
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("${tokenID}:${tokenSecret}")
        $base64 = [System.Convert]::ToBase64String($bytes)
        $headers.Add("Authorization", "BASIC $base64")
        $headers.Add('Content-Type', 'application/json')

        $actionMessage = 'creating message body'
        $sendMessageBody = @{
            to   = $actionContext.TemplateConfiguration.recipient
            from = $actionContext.Configuration.originator
            body = $actionContext.TemplateConfiguration.body
        }
        # Optional, define date and time of the message
        if (-NOT[String]::IsNullOrEmpty($actionContext.TemplateConfiguration.time)) {
            $currentDate = Get-date
            if ([String]::IsNullOrEmpty($actionContext.TemplateConfiguration.timezone)) { $actionContext.TemplateConfiguration.timezone = 'UTC' }
            $timezone = [TimeZoneInfo]::FindSystemTimeZoneById($actionContext.TemplateConfiguration.timezone)
            $dateTimeString = $currentDate.toString("yyyy-MM-dd") + " $($actionContext.TemplateConfiguration.time)"
            $scheduledDatetime = [datetime]$dateTimeString
            $scheduledUtcDateTime = [TimeZoneInfo]::ConvertTimeToUtc($scheduledDatetime, $timezone)
            if ($timezone.SupportsDaylightSavingTime) { $daylightSavingActive = $timezone.IsDaylightSavingTime($scheduledDatetime) } else { $daylightSavingActive = $false }
            $scheduledDatetimeRFC = $scheduledUtcDateTime.ToString("yyyy-MM-dd\THH:mm:sszzz", [System.Globalization.CultureInfo]::InvariantCulture)
            $scheduledDatetimeRFC = [System.Uri]::EscapeDataString($scheduledDatetimeRFC)
            $uri = "$($actionContext.Configuration.baseUri)/messages?auto-unicode=false&schedule-date=$scheduledDatetimeRFC"
            $scheduledTime = $true
        }
        else {
            $uri = "$($actionContext.Configuration.baseUri)/messages?auto-unicode=false"
            $scheduledTime = $false
        }

        $body = $sendMessageBody | ConvertTo-Json
        $splatParams = @{
            Uri         = $uri
            Headers     = $headers
            Method      = 'POST'
            Body        = ([System.Text.Encoding]::UTF8.GetBytes($body))
            ErrorAction = "Stop"
        }

        $actionMessage = 'sending sms'
        if (-not($actionContext.DryRun -eq $true)) {
            $response = Invoke-RestMethod @splatParams
            if ($scheduledTime) {
                $auditMessage = "Successfully scheduled BulkSMS notification [$($response.id)] for [$($personContext.Person.DisplayName)] to [$($sendMessageBody.to)] at [$($scheduledDatetime.ToString("yyyy-MM-dd HH:mm"))]"
                Write-Information "Selected time zone [$timezone], daylight saving active: [$daylightSavingActive]. SMS will be sent at UTC time [$($scheduledUtcDateTime.ToString("yyyy-MM-dd HH:mm"))], which corresponds to local time [$($scheduledDatetime.ToString("yyyy-MM-dd HH:mm"))]."
            }
            else {
                $auditMessage = "Successfully sent BulkSMS notification [$($response.id)] for [$($personContext.Person.DisplayName)] to [$($sendMessageBody.to)]"
            }
        }
        else {
            if ($scheduledTime) {
                $auditMessage = "DryRun: Would schedule BulkSMS notification for [$($personContext.Person.DisplayName)] to [$($sendMessageBody.to)] at [$($scheduledDatetime.ToString("yyyy-MM-dd HH:mm"))]"
                Write-Information "Selected time zone [$timezone], daylight saving active: [$daylightSavingActive]. SMS will be sent at UTC time [$($scheduledUtcDateTime.ToString("yyyy-MM-dd HH:mm"))], which corresponds to local time [$($scheduledDatetime.ToString("yyyy-MM-dd HH:mm"))]."
            }
            else {
                $auditMessage = "DryRun: Would Send BulkSMS notification for [$($personContext.Person.DisplayName)] to [$($sendMessageBody.to)]"
            }
            Write-Information $auditMessage
        }
        $outputContext.Success = $true
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Message = $auditMessage
                IsError = $false
            })
    }
    else {
        $outputContext.Success = $false
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Message = 'Incorrect scriptFlow'
                IsError = $true
            })
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-BulkSMSError -ErrorObject $ex
        $auditMessage = "Error $($actionMessage). Error: $($errorObj.FriendlyMessage)"
        $warningMessage = "Error at Line [$($errorObj.ScriptLineNumber)]: $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }

    Write-Warning $warningMessage
    $outputContext.Success = $false
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
