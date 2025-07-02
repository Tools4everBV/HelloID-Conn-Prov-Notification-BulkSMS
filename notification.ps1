#####################################################
# HelloID-Conn-Prov-Notification-BulkSMS
#
# Version: 1.0.0
#####################################################

# Debug
if ($actionContext.DryRun -eq $true) {
    $actionContext.TemplateConfiguration.scriptFlow = 'SMS'
    $actionContext.TemplateConfiguration.time = "08:00:00"
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
        if (![String]::IsNullOrEmpty($actionContext.TemplateConfiguration.time)) {
            # Define the date and time
            $currentDate = Get-date
            $time = $actionContext.TemplateConfiguration.time

            # Create a DateTime object of current date and specified time
            $dateTimeString = $currentDate.toString("yyyy-MM-dd") + " $time"
            $scheduledDatetime = [datetime]$dateTimeString

            # Convert DateTime to RFC3339 format (Y-m-d\TH:i:sP)
            $scheduledDatetimeRFC = $scheduledDatetime.ToString("yyyy-MM-dd\THH:mm:sszzz", [System.Globalization.CultureInfo]::InvariantCulture)

            # Escapes a string for use in a URI by encoding special characters (e.g., spaces, symbols) 
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
                $auditMessage = "Successfully scheduled BulkSMS notification [$($response.id)] for [$($personContext.Person.DisplayName)] to [$($sendMessageBody.to)] at [$scheduledDatetimeRFC]"
            }
            else {
                $auditMessage = "Successfully sent BulkSMS notification [$($response.id)] for [$($personContext.Person.DisplayName)] to [$($sendMessageBody.to)]"
            }
        }
        else {
            if ($scheduledTime) {
                $auditMessage = "DryRun: Would schedule BulkSMS notification for [$($personContext.Person.DisplayName)] to [$($sendMessageBody.to)] at [$scheduledDatetimeRFC]"
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
