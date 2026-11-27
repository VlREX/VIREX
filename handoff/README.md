# VIREX Studio mailbox

Only session-specific, commit-pinned v3 JSON test plans are stored here. Never store test reports, credentials or personal data. The local Studio must explicitly authorize the target repository and a two-hour session; the session ID is a correlation ID, not a secret. The Studio validates the envelope, scope and commit before execution. Publish r1.json through r4.json only after the user's START or an authenticated in-chat report requests the next round. No automatic merge.
