---
name: Release
about: List of checklist to accomplish for the ownCloud team to finish the release process
title: "[RELEASE]"
labels: Release
assignees: ''

---

Release a new version

Xcode version to work with:

## TASKS:

### Git & Code

* [ ] [DEV] Update [SBOM](https://cloud.owncloud.com/f/6072865)
- [ ] [GIT] Create branch `release/[major].[minor].[patch]` (freeze the code)
- [ ] [DEV] Update `APP_SHORT_VERSION` `[major].[minor].[patch]` in [ownCloud.xcodeproj/project.pbxproj](https://github.com/owncloud/ios-app/blob/master/ownCloud.xcodeproj/project.pbxproj)
- [ ] [TRFX] Update translations from transifex branch.
- [ ] [TRFX] Check for missing translations.
- [ ] [DIS] Update [changelog](https://github.com/owncloud/ios-app/blob/master/CHANGELOG.md)
- [ ] [DEV] Update In-App Release Notes (changelog) in ownCloud/Release Notes/ReleaseNotes.plist
- [ ] [DEV] Changelog: Created a folder for the new version like $majorVersion.$minorVersion.$patchVersion_YYYY-MM-DD
- [ ] [DEV] Changelog: Moved all changelog files from the unreleased folder to the new version folder
- [ ] [DEV] Inform Documentation-Team for the upcoming major/minor release with new version tag (notify #documentation-internal)
- [ ] [QA] Design Test plan
- [ ] [QA] Regression Test plan
- [ ] [DOC] Update https://owncloud.com/mobile-apps/#ios version numbers (notify #marketing)
- [ ] [GIT] Merge branch `release/[major].[minor].[patch]` in master
- [ ] [GIT] Create tag and sign it `[major].[minor].[patch]`
- [ ] [GIT] Add the new release on [GitHub ios-app](https://github.com/owncloud/ios-app/releases)
- [ ] [DEV] ownBrander: Update the ownBrander git tag in repository `customer_portal` to new release tag
- [ ] [DEV] Update used Xcode version for the release in [.xcode-version](https://github.com/owncloud/ios-app/blob/master/.xcode-version)
- [ ] [DEV] Inform #documentation about the new release to set new documentation branch tag

If it is required to update the iOS-SDK version:

- [ ] [GIT] Create branch library `release/[major].[minor].[patch]`(freeze the code)
- [ ] [mail] inform #marketing about the new release.
- [ ] [DIS] Update README.md (version number, third party, supported versions of iOS, Xcode)
- [ ] [DIS] Update [changelog](https://github.com/owncloud/ios-sdk/blob/master/CHANGELOG.md)
- [ ] [GIT] Merge branch `release/[major].[minor].[patch]` in `master`
- [ ] [GIT] Create tag and sign it `[major].[minor].[patch]`
- [ ] [GIT] Add the new release on [GitHub ios-sdk](https://github.com/owncloud/ios-sdk/releases)

If it is required to update third party:

- [ ] [DIS] Update THIRD_PARTY.txt

## App Store

- [ ] [DIS] App Store Connect: Create a new version following the `[major].[minor].[patch]`
- [ ] [DIS] App Store Connect: Trigger Fastlane screenshots generation and upload
- [ ] [DIS] Upload the binary to the App Store
- [ ] [DIS] App Store Connect: Trigger release (manually)
- [ ] [DIS] App Store Connect: Decide reset of iOS summary rating (Default: keep)
- [ ] [DIS] App Store Connect: Update description if necessary (coordinated with #marketing)
- [ ] [DIS] App Store Connect: Update changelogs
- [ ] [DIS] App Store Connect: Submit for review

## BUGS & IMPROVEMENTS:
