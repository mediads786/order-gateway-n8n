# Publication safety

Current evidence: [QA report](docs/QA-TEST-REPORT.md) and [notification verification](docs/NOTIFICATION-VERIFICATION.md). The shared [17 October disclosure review](https://github.com/mediads786/order-gateway/blob/master/docs/publication-review-2026-10-17.md) covers every tracked file and available Git history in both repositories, including their binary evidence. It records no confirmed exposure within its stated scope; it is not a security certification.

Keep credential values/bindings, access tokens, encryption/signing keys, passwords, cookies, private keys, live deployment hostnames/IPs, provider account identifiers, customer contacts, raw environment files, logs, execution payloads and database exports private. Publish separately sanitized summaries and inactive workflow exports with no pinned data. Use independently generated secrets; never deploy example credentials.

For each publication, inspect `git status --short`, the exact staged file list and the complete staged diff. Scan the complete proposed files and Git history locally with fully redacted output. With Gitleaks, use `gitleaks git --log-opts=--all --redact=100 --ignore-gitleaks-allow` and `gitleaks git --pre-commit --staged --redact=100 --ignore-gitleaks-allow`. Compare known private credentials and endpoints in memory without printing them. Do not blanket-exclude tests or examples from scanning.

Inspect every new screenshot/recording frame and image metadata; text scanning alone does not review pixels. Run `node scripts/verify-release.js` for sanitized workflow structure and local documentation links. Verify the committed file list and remote revision after pushing.

Ignored files can still be force-added, and ignore rules do not remove tracked content or history. If a real credential is exposed, revoke/rotate it first, then agree removal of current/history copies with the owner. Never paste an exposed value into a public report or issue. This workflow does not replace dependency or runtime security auditing.
