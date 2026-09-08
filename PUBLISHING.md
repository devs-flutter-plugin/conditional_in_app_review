# Publishing

This package is prepared for publication on pub.dev without storing long-lived publishing credentials in GitHub.

All repository workflows run on self-hosted GitHub Actions runners.

## Runner requirement

The repository is owned by `devs-flutter-plugin`, so it must have access to a self-hosted runner through a repository runner, an organization runner group, or an Enterprise runner group shared with this organization.

Both `.github/workflows/ci.yml` and `.github/workflows/publish.yml` use `runs-on: self-hosted`.

## First publication

Pub.dev automated publishing can only be enabled after the package already exists. The first version must therefore be published manually from a trusted development machine.

Before publishing:

1. Confirm the `main` CI workflow is green on the self-hosted runner.
2. Confirm `pubspec.yaml` and `CHANGELOG.md` contain the intended version.
3. Run `dart pub publish --dry-run` and resolve every warning or error.
4. Publish with `dart pub publish` and complete the pub.dev authentication flow.

Do not commit pub credentials or authentication files to this repository.

## Automated publishing after the first version

After the first version exists on pub.dev:

1. Open the package Admin tab on pub.dev.
2. Enable publishing from GitHub Actions.
3. Configure the repository as `devs-flutter-plugin/conditional_in_app_review`.
4. Configure the tag pattern as `v{{version}}`.
5. Require the GitHub Actions environment named `pub.dev`.
6. In GitHub, create the `pub.dev` environment and configure required reviewers if desired.

The repository contains `.github/workflows/publish.yml`, which runs directly on the self-hosted runner and uses GitHub OIDC authentication. No long-lived pub.dev publishing token is required.

## Releasing a version

For a version such as `0.2.0`:

1. Update `version:` in `pubspec.yaml` to `0.2.0`.
2. Add the release notes to `CHANGELOG.md`.
3. Merge the changes into `main` and confirm CI is green.
4. Create and push the matching tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

The tag version and `pubspec.yaml` version must match. The publish workflow authenticates to pub.dev using a short-lived GitHub OIDC token.

## Security

Anyone allowed to create matching release tags can potentially trigger publication after automated publishing is enabled. Protect release tags and/or require approval on the `pub.dev` GitHub environment.

See the official Dart documentation for current automated publishing requirements: https://dart.dev/tools/pub/automated-publishing
