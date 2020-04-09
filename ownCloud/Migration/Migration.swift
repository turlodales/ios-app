//
//  Migration.swift
//  ownCloud
//
//  Created by Michael Neuwert on 03.03.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
* Copyright (C) 2019, ownCloud GmbH.
*
* This code is covered by the GNU Public License Version 3.
*
* For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
* You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
*
*/

import Foundation
import ownCloudSDK
import ownCloudApp
import ownCloudAppShared
import Photos

// TODO: Somehow this stuff is not found by Xcode, although ownCloudAppShared is linked:-(
class OCItemTracker: NSObject {

	var itemTracking : OCCoreItemTracking?

	public func item(for bookmark: OCBookmark, at path: String, completionHandler: @escaping (_ error: Error?, _ core: OCCore?, _ item: OCItem?) -> Void) {

		OCCoreManager.shared.requestCore(for: bookmark, setup: nil, completionHandler: { (core, error) in
			if error == nil, let core = core {
				self.itemTracking = core.trackItem(atPath: path, trackingHandler: { (error, item, isInitial) in
					if isInitial {
						self.itemTracking = nil
					}
					completionHandler(error, core, item)
				})
			} else {
				completionHandler(error, nil, nil)
			}
		})
	}
}

class MigrationActivity {
	enum State {
		case initiated, finished, failed
	}
	var title: String?
	var description: String?
	var state : State = .initiated
}

class Migration {

	struct Entitlements : Codable {

		var appGroups : [String]?
		var keychainAccessGroups : [String]?

		enum CodingKeys: String, CodingKey {
			case appGroups = "com.apple.security.application-groups"
			case keychainAccessGroups = "keychain-access-groups"
		}
	}

	static let ActivityUpdateNotification = NSNotification.Name(rawValue: "MigrationActivityUpdateNotification")
	static let FinishedNotification = NSNotification.Name(rawValue: "MigrationFinishedNotification")

	private static let legacyDbFilename = "DB.sqlite"
	private static let legacyCacheFolder = "cache_folder"
	private static let legacyInstantUploadFolder = "/InstantUpload"

	static let shared = Migration()

	private lazy var appGroupId : String? = {
		// Try to read entitlements
		if let entitlements = readAppEntitlements() {
			return entitlements.appGroups?.first
		}

		// Try to construct group id from bundle identifier
		if let bundleId = Bundle.main.bundleIdentifier {
			return "group." + bundleId
		}

		return nil
	}()

	private lazy var legacyDataDirectoryURL: URL? = {
		if let groupId = self.appGroupId {
			let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
			return containerURL?.appendingPathComponent(Migration.legacyCacheFolder)
		}
		return nil
	}()

	// MARK: - Public API

	var legacyDataFound : Bool {
		get {
			var isDirectory : ObjCBool = false
			if let directoryPath = self.legacyDataDirectoryURL?.path {
				let pathExists = FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory)
				return (pathExists && isDirectory.boolValue == true)
			}
			return false
		}
	}

	private let migrationQueue = DispatchQueue(label: "com.owncloud.migration-queue")

	func migrateAccountsAndSettings(_ parentViewController:UIViewController? = nil) {

		guard let legacyDbURL = self.legacyDataDirectoryURL?.appendingPathComponent(Migration.legacyDbFilename) else { return }

		if FileManager.default.fileExists(atPath: legacyDbURL.path) {
			let db = OCSQLiteDB(url: legacyDbURL)
			db.open(with: .readOnly) { (_, err) in
				if err == nil {
					let queryResultHandler : OCSQLiteDBResultHandler = { (db, error, transaction, resultSet) in
						if let resultSet = resultSet {
							var error : NSError?

							resultSet.iterate({ (_, _, rowDict, _) in
								self.migrationQueue.async {
									if let userId = rowDict["id"] as? Int,
										let serverURL = rowDict["url"] as? String,
										let credentials = self.getCredentialsDataItem(for: userId) {

										let bookmark = OCBookmark()
										bookmark.url = URL(string: serverURL)
										let connection = OCConnection(bookmark: bookmark)

										let bookmarkActivity = "\(credentials.userName ?? "")@\(bookmark.url?.absoluteString ?? "")"

										self.postAccountMigrationNotification(activity: bookmarkActivity)

										if let authMethods = self.setup(connection: connection) {

											// Generate authorization data
											self.authorize(bookmark: bookmark,
														   using: connection,
														   credentials: credentials,
														   supportedAuthMethods: authMethods,
														   parentViewController: parentViewController)

											// Delete old auth data from the keychain
											self.removeCredentials(for: userId)

											// Save the bookmark
											OCBookmarkManager.shared.addBookmark(bookmark)
											OCBookmarkManager.shared.saveBookmarks()

											// For the active account, migrate instant upload settings
											if let activeAccount = rowDict["activeaccount"] as? Int, activeAccount == 1 {
												self.migrateInstantUploadSettings(for: bookmark, userId: userId, accountDictionary: rowDict)
											}

											self.postAccountMigrationNotification(activity: bookmarkActivity, state: .finished)

										} else {
											self.postAccountMigrationNotification(activity: bookmarkActivity, state: .failed)
										}
									}
								}

							}, error: &error)
						}
					}

					if let usersQuery = OCSQLiteQuery(selectingColumns: nil, fromTable: "users", where: nil, orderBy: nil, limit: nil, resultHandler: queryResultHandler) {
						db.execute(usersQuery)
					}

					self.migrationQueue.async {
						// Check if the passcode is set
						let passcodeQuery = OCSQLiteQuery(selectingColumns: ["passcode"], fromTable: "passcode", where: nil, orderBy: "id DESC", limit: "1") { (_, _, _, resultSet) in
							if let dict = try? resultSet?.nextRowDictionary(), let passcode = dict?["passcode"] as? String {
								self.postAccountMigrationNotification(activity: "App Passcode", state: .initiated)
								if passcode.count == 4 && passcode.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
									AppLockManager.shared.passcode = passcode
									AppLockManager.shared.lockEnabled = true
									self.postAccountMigrationNotification(activity: "App Passcode", state: .finished)
								} else {
									self.postAccountMigrationNotification(activity: "App Passcode", state: .failed)
								}
							}
						}
						if let query = passcodeQuery {
							db.execute(query)
						}
					}

					self.migrationQueue.async {
						DispatchQueue.main.async {
							NotificationCenter.default.post(name: Migration.FinishedNotification, object: nil)
						}
					}

				}
			}
		}
	}

	// MARK: - Private helpers

	private func setup(connection:OCConnection) -> [OCAuthenticationMethodIdentifier]? {
		let connectGroup = DispatchGroup()
		var supportedAuthMethods: [OCAuthenticationMethodIdentifier]?

		func connectAndAuthorize() {
			connectGroup.enter()
			connection.prepareForSetup(options: nil) { (issue, _, supportedAuthenticationMethods, _) in
				supportedAuthMethods = supportedAuthenticationMethods

				if let issue = issue, issue.level != .error, supportedAuthMethods == nil {
					issue.approve()
					connectAndAuthorize()
				}
				connectGroup.leave()
			}
		}

		connectAndAuthorize()

		connectGroup.wait()

		return supportedAuthMethods
	}

	private func authorize(bookmark:OCBookmark,
						   using connection:OCConnection,
						   credentials:OCCredentialsDto,
						   supportedAuthMethods:[OCAuthenticationMethodIdentifier],
						   parentViewController:UIViewController? = nil) {

		var authMethod = OCAuthenticationMethodIdentifier.basicAuth
		var options : [OCAuthenticationMethodKey : Any] = [:]

		var unsupportedAuthMethod = false

		switch credentials.authenticationMethod {
		case .basicHttpAuth:
			// If server supports OAuth2, switch basic auth user to this more secure method
			if supportedAuthMethods.contains(OCAuthenticationMethodIdentifier.oAuth2) {
				authMethod = OCAuthenticationMethodIdentifier.oAuth2
			}

		case .bearerToken:
			if supportedAuthMethods.contains(OCAuthenticationMethodIdentifier.oAuth2) {
				authMethod = OCAuthenticationMethodIdentifier.oAuth2
				// Migrate OAuth2 data if possible. Note that the below method forces token expiration and subsequent refresh
				if let authData = credentials.oauth2Data() {
					bookmark.authenticationData = authData
				}
			} else {
				unsupportedAuthMethod = true
			}

		case .samlWebSSO:
			// If server supports OAuth2, switch basic auth user to this more secure method
			if supportedAuthMethods.contains(OCAuthenticationMethodIdentifier.oAuth2) {
				authMethod = OCAuthenticationMethodIdentifier.oAuth2
			} else {
				unsupportedAuthMethod = true
			}
		default:
			 break
		}

		bookmark.authenticationMethodIdentifier = authMethod

		if unsupportedAuthMethod == false {
			// In case we use OAuth2 and we had already required auth data, finalize account migration
			if bookmark.authenticationData == nil {
				// For basic auth, set userName and password
				if authMethod == OCAuthenticationMethodIdentifier.basicAuth {
					options[.usernameKey] = credentials.userName
					options[.passphraseKey] = credentials.accessToken
				}

				if authMethod == OCAuthenticationMethodIdentifier.oAuth2 {
					// Set parent view controller to display a webview with auth server UI
					options[.presentingViewControllerKey] = parentViewController
				}

				let semaphore = DispatchSemaphore(value: 0)
				connection.generateAuthenticationData(withMethod: authMethod, options: options) { (error, authMethodIdentifier, authMethodData) in
					if error == nil {
						bookmark.authenticationMethodIdentifier = authMethodIdentifier
						bookmark.authenticationData = authMethodData
					}
					semaphore.signal()
				}
				semaphore.wait()
			}
		}
	}

	private func postAccountMigrationNotification(activity:String, state:MigrationActivity.State = .initiated) {
		DispatchQueue.main.async {
			let migrationActivity = MigrationActivity()
			migrationActivity.title = activity
			migrationActivity.state = state
			switch state {
			case .initiated:
				migrationActivity.description = "Migrating"
			case .finished:
				migrationActivity.description = "Migrated"
			case .failed:
				migrationActivity.description = "Failed to migrate"
			}
			NotificationCenter.default.post(name: Migration.ActivityUpdateNotification, object: migrationActivity)
		}
	}

	private func migrateInstantUploadSettings(for bookmark:OCBookmark, userId:Int, accountDictionary: [String : Any]) {
		// In the legacy app only active account could have been used for instant photo / video upload
		guard let userDefaults = OCAppIdentity.shared.userDefaults else { return }

		guard let legacyInstantPhotoUploadActive = accountDictionary["image_instant_upload"] as? Int else { return }

		guard let legacyInstantVideoUploadActive = accountDictionary["video_instant_upload"] as? Int else { return }

		guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }

		// If one of the instant upload options is active, check and request if needed photo library permissions
		if legacyInstantPhotoUploadActive > 0 || legacyInstantVideoUploadActive > 0 {

			let activityName = "Instant Upload Settings"

			postAccountMigrationNotification(activity: activityName)

			func setupInstantUpload() {
				userDefaults.instantUploadPath = Migration.legacyInstantUploadFolder
				userDefaults.instantUploadBookmarkUUID = bookmark.uuid

				userDefaults.instantUploadPhotos = legacyInstantPhotoUploadActive > 0 ? true : false
				userDefaults.instantUploadVideos = legacyInstantVideoUploadActive > 0 ? true : false

				if let legacyLastPhotoUploadTimeInterval = accountDictionary["timestamp_last_instant_upload_image"] as? TimeInterval, legacyLastPhotoUploadTimeInterval > 0 {
					let timestamp = Date(timeIntervalSince1970: legacyLastPhotoUploadTimeInterval)
					userDefaults.instantUploadPhotosAfter = timestamp
				}

				if let legacyLastVideoUploadTimeInterval = accountDictionary["timestamp_last_instant_upload_video"] as? TimeInterval, legacyLastVideoUploadTimeInterval > 0 {
					let timestamp = Date(timeIntervalSince1970: legacyLastVideoUploadTimeInterval)
					userDefaults.instantUploadVideosAfter = timestamp
				}

				self.postAccountMigrationNotification(activity: activityName, state: .finished)
			}

			// In the legacy app the instant upload folder was hardcoded to \InstantUpload
			// So, check if the directory is present and create it if it is absent
			var uploadFolderAvailable = false
			let trackItemGroup = DispatchGroup()
			trackItemGroup.enter()
			OCItemTracker().item(for: bookmark, at: "/") { (error, core, rootItem) in
				if rootItem != nil {
					trackItemGroup.enter()
					OCItemTracker().item(for: bookmark, at: Migration.legacyInstantUploadFolder) { (error, core, item) in
						if error == nil {
							if item == nil {
								trackItemGroup.enter()
								core?.createFolder(Migration.legacyInstantUploadFolder, inside: rootItem!, options: nil, resultHandler: { (error, _, _, _) in
									uploadFolderAvailable = (error == nil)
									trackItemGroup.leave()
								})
							} else {
								uploadFolderAvailable = true
							}
						}
						trackItemGroup.leave()
					}
				}
				trackItemGroup.leave()
			}

			trackItemGroup.wait()

			if uploadFolderAvailable == true {
				setupInstantUpload()
			} else {
				self.postAccountMigrationNotification(activity: activityName, state: .failed)
			}
		}

	}

	func wipeLegacyData() {
		var isDirectory: ObjCBool = false
		if let legacyDataPath = self.legacyDataDirectoryURL?.path {
			if FileManager.default.fileExists(atPath: legacyDataPath, isDirectory: &isDirectory) {
				try? FileManager.default.removeItem(atPath: legacyDataPath)
			}
		}
	}

	private func getCredentialsDataItem(for userId:Int) -> OCCredentialsDto? {

		guard let groupId = self.appGroupId else { return nil }
		guard let bundleSeed = self.bundleSeedID() else { return nil }

		let fullGroupId = "\(bundleSeed).\(groupId)"

		let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
									kSecAttrAccessGroup as String: fullGroupId,
									kSecAttrAccount as String: "\(userId)",
									kSecReturnData as String : true,
									kSecReturnAttributes as String : true]

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		if status == errSecSuccess {
			guard let existingItem = item as? [String : Any],
				let credentialsData = existingItem[kSecValueData as String] as? Data
			else {
				return nil
			}

			let credentials = NSKeyedUnarchiver.unarchiveObject(with: credentialsData) as? OCCredentialsDto

			return credentials
		}

		return nil
	}

	private func removeCredentials(for userId:Int) {
		guard let groupId = self.appGroupId else { return }
		guard let bundleSeed = self.bundleSeedID() else { return }

		let fullGroupId = "\(bundleSeed).\(groupId)"

		let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
									kSecAttrAccessGroup as String: fullGroupId,
									kSecAttrAccount as String: "\(userId)"]
		SecItemDelete(query as CFDictionary)
	}

	private func readAppEntitlements() -> Entitlements? {
		guard let productName = Bundle.main.infoDictionary?[String(kCFBundleNameKey)] as? String else { return nil }
		guard let entitlementsPath = Bundle.main.path(forResource: productName, ofType: "entitlements") else { return nil }
		guard let plistData = FileManager.default.contents(atPath: entitlementsPath) else { return nil}

		var entitlements : Entitlements?
		let decoder = PropertyListDecoder()
		entitlements = try? decoder.decode(Entitlements.self, from: plistData)

		return entitlements
	}

	private func bundleSeedID() -> String? {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "bundleSeedID" as AnyObject,
            kSecAttrService as String: "" as AnyObject,
            kSecReturnAttributes as String: kCFBooleanTrue
        ]

        var result : AnyObject?
        var status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        if status == errSecItemNotFound {
            status = withUnsafeMutablePointer(to: &result) {
                SecItemAdd(query as CFDictionary, UnsafeMutablePointer($0))
            }
        }

        if status == noErr {
            if let resultDict = result as? [String: Any], let accessGroup = resultDict[kSecAttrAccessGroup as String] as? String {
                let components = accessGroup.components(separatedBy: ".")
                return components.first
            }
		}

		return nil
    }
}