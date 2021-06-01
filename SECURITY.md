# Security Policy

Security is the top priority for this library and any report will be treated as urgent.

After sending a report, you should expect a response within **7 calendar days**. If you have not, please file a secondary report with the SSWG using [sswg-security-reports@forums.swift.org](mailto:sswg-security-reports@forums.swift.org).

Once a report has been received, and determined to be a valid issue, a fix should be released no later than **14 calendar days** from the date it was determined as valid.

After a fix has been implemented, a [CVE](https://cve.mitre.org/index.html) request will be filed with GitLab and issued according to [GitLab's CVE policies](https://about.gitlab.com/security/cve/).

Once the fix has been released, the original report may become public.

## Reporting Issues

If you have discovered a vulnerability in the project, please send your report directly to  [support@redistack.info](mailto:support@redistack.info)

> Please prefix your subject line with `[SECURITY]`

These reports are immediately filed as confidential and only you and those with [report access](#report-access) will see any conversation from your initial report.

Example:

```
To: support@redistack.info
From: reporter@email.com
Subject: [SECURITY] DDOS Potential with PubSub
Body:
The current way that PubSub is implemented leaves the opportunity for a bad actor to cause a denial-of-service by...
```

> For tips on writing your vulnerability reports, refer to [How to Write a Better Vulnerability Report](https://medium.com/swlh/how-to-write-a-better-vulnerability-report-20163ab913fb), by Vickie Li

## Report Access

All [project members](https://gitlab.com/mordil/redistack/-/project_members), which includes [SSWG](https://swift.org/sswg/) representatives, are able to view confidential issues reported by following this security policy.
