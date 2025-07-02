# HelloID-Conn-Prov-Notification-BulkSMS

> [!IMPORTANT]
> Please be aware that the notifications only can be triggered by [events](https://docs.helloid.com/en/provisioning/notifications--provisioning-/notification-events--provisioning-.html) and cannot be used as entitlements.

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center"> 
  <img src="https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Notification-BulkSMS/refs/heads/main/Logo.png">
</p>

## Table of contents

## Introduction

_HelloID-Conn-Prov-Notification-BulkSMS_ is a _notifcation_ connector. BulkSMS provides a set of REST APIs that allow you to programmatically interact with its data. The [BulkSMS SMS API documentation](https://www.bulksms.com/developer/json/v1/#) provides details of API commands that are used.

## Table of contents

- [HelloID-Conn-Prov-Notification-BulkSMS](#helloid-conn-prov-notification-bulksms)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Table of contents](#table-of-contents-1)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Templates](#templates)
      - [SMS](#sms)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Getting started

### HelloID Icon URL
URL of the icon used for the HelloID Provisioning target system.

```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Notification-BulkSMS/refs/heads/main/Icon.png
```

### Prerequisites
  - TokenID and TokenSecret from BulkSMS

### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                                                                                                                                       | Mandatory |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| BaseUri      | The BaseURI of the BulkSMS API endpoint(s), default value https://api.bulksms.com/v1                                                              | Yes       |
| TokenID      | TokenID for BulkSMS API.                                                                                                                          | Yes       |
| TokenSecret  | TokenSecret for BulkSMS API.                                                                                                                      | Yes       |
| Sending From | The sender of the message. This can be a telephone number (including country code) or an alphanumeric string. The maximum length is 11 characters | Yes       |

### Templates
#### SMS
To create a form for SMS the following template should be used: [template.json](https://github.com/Tools4everBV/HelloID-Conn-Prov-Notification-BulkSMS/blob/main/template.json).

The table below describes the different form fields from the template.

| template key            | Description                                                    | Mandatory |
| ----------------------- | -------------------------------------------------------------- | --------- |
| scriptFlow              | Fixed value "SMS" (read-only)                                  | Yes       |
| Time                    | Optional, the scheduled time of the message in format HH:mm:ss | Yes       |
| Recipient mobile number | Mobile number where SMS should be delivered                    | Yes       |
| Message                 | Body of the SMS Message                                        | Yes       |

> [!NOTE]
> When setting a scheduled time, the SMS will be sent at the specified time of day. If the scheduled time has passed, the SMS will be sent immediately.
> - The time used is based on the current agent time.
> - For cloud agents, this is in UTC.
> - To match your local time, use a local agent instead. If the server is configured correctly, this will account for daylight saving time as well.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/notifications--provisioning-/notification-systems--provisioning-) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5366-helloid-conn-prov-notification-bulksms)_

## HelloID docs

> The official HelloID documentation can be found at: https://docs.helloid.com/
