## 0.1.0

- Initial development release.
- Add configurable eligibility rules for launches, elapsed days, significant events, cooldowns, and app versions.
- Add `SharedPreferencesAsync` persistence.
- Delegate native review requests to `in_app_review`.
- Add injectable storage, requester, and clock abstractions for testing.
- Deduplicate concurrent initialization calls.
- Add runtime validation for invalid review conditions.
- Add read-only `ReviewSnapshot` diagnostics.
- Add CI validation for formatting, analysis, tests, and package publication readiness.
