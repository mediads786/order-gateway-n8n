# Notification verification: dated evidence and owner follow-up

Updated 17 October 2026 (Asia/Karachi). This public summary excludes recipients, phone numbers, provider message IDs, credentials, deployment addresses and raw execution payloads.

## Completed tests remain verified

- Historical Gmail executions 190/191 exercised the success path; 197 exercised a failure branch, and error-workflow execution 535 is retained.
- Historical WhatsApp executions 252 and 272 record successful sending/outbox processing; 277 exercised failure/retry. The stored WhatsApp outbox retains one sent, one retry and one dead example. The sent example contains a provider message identifier, whose value is not published here.
- On 13 October the custom failure-alert template passed direct Meta API acceptance, and the owner confirmed phone receipt. That direct API test did not activate or execute the scheduled Module 06 workflow at its checkpoint.
- In the 17 October evidence reconciliation, the owner clarified that, after Meta approved the template, the failure-notification workflow was activated and tested successfully. This is owner-performed test evidence and must not be erased by an older report or a later inactive snapshot. The exact activation time and a separately retained post-approval execution ID were not identified in this review; no new automated scheduled-workflow run is claimed.

## Separate runtime observation

A read-only local database observation on 17 October showed the WhatsApp API-test and failure-notification workflows inactive at that moment. Retained execution metadata includes five API-test executions and two failure-notification executions, with the latest retained entries dated 12 October. This later snapshot does not determine the historical activation state. The owner's report of post-approval activation and testing remains separately documented; its exact activation date and execution ID were not established by this review.

Do not describe the workflow as continuously active based only on historical successful delivery. Equally, do not describe successful template delivery or the owner's later test as still awaiting approval. Runtime activation and completed verification are separate facts.

## Review method

The reconciliation read 23 existing business orders, their audit histories, notification-outbox status fields and retained execution metadata in database-enforced read-only transactions. Every one of the 37 execution IDs selected from the existing QA references was present. A green execution alone is not proof of recipient delivery; the existing provider/outbox evidence and the owner's receipt confirmation supply the respective evidence layers.

No workflow was triggered, notification sent, credential read out or runtime setting changed by this documentation update. The Python gateway's separate AWS deployment and approvals are not features of this n8n implementation. Full results and remaining boundaries are in [QA-TEST-REPORT.md](QA-TEST-REPORT.md) and [TESTING.md](TESTING.md).
