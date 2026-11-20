# KNEAYERNG App Security documentation

This set documents the inspected implementation and its production prerequisites. `implementation-status.md` is the short status summary; the remaining pages provide the architecture, API, operational and security details. Statements are labeled by actual implementation state: a stored or submitted value is not described as verified unless the server verifies it.

## Developer and operator guides

1. [Architecture](architecture.md)
2. [Project discovery report](project-discovery-report.md)
3. [Database schema](database-schema.md)
4. [API specification](api-specification.md)
5. [APK release process](apk-release-process.md)
6. [Website distribution](website-distribution.md)
7. [Android Keystore](android-keystore.md)
8. [Key Attestation](key-attestation.md)
9. [Request signing](request-signing.md)
10. [Session management](session-management.md)
11. [Risk engine](risk-engine.md)
12. [Admin dashboard](admin-dashboard.md)
13. [Deployment guide](deployment-guide.md)
14. [Security testing](security-testing.md)
15. [Troubleshooting](troubleshooting.md)
16. [Disaster recovery](disaster-recovery.md)

The browser administration and release workflows belong to the root Laravel application, which also serves the mobile API. Keep the feature flag disabled until the staged rollout prerequisites in the deployment guide are satisfied.

