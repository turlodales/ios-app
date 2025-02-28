//
//  PathExistsIntentHandler.swift
//  ownCloudAppShared
//
//  Created by Matthias Hühne on 30.08.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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

import UIKit
import Intents
import ownCloudSDK
import ownCloudAppShared

@available(iOS 13.0, *)
public class PathExistsIntentHandler: NSObject, PathExistsIntentHandling {

	func handle(intent: PathExistsIntent, completion: @escaping (PathExistsIntentResponse) -> Void) {

		guard IntentSettings.shared.isEnabled else {
			completion(PathExistsIntentResponse(code: .disabled, userActivity: nil))
			return
		}

		guard !AppLockManager.isPassCodeEnabled else {
			completion(PathExistsIntentResponse(code: .authenticationRequired, userActivity: nil))
			return
		}

		guard let path = intent.path, let uuid = intent.account?.uuid else {
			completion(PathExistsIntentResponse(code: .failure, userActivity: nil))
			return
		}

		guard let bookmark = OCBookmarkManager.shared.bookmark(forUUIDString: uuid) else {
			completion(PathExistsIntentResponse(code: .accountFailure, userActivity: nil))
			return
		}

		guard IntentSettings.shared.isLicensedFor(bookmark: bookmark) else {
			completion(PathExistsIntentResponse(code: .unlicensed, userActivity: nil))
			return
		}

		OCItemTracker(for: bookmark, at: .legacyRootPath(path), waitOnlineTimeout: 5) { (error, core, item) in
			if error == nil, item != nil {
				completion(PathExistsIntentResponse.success(pathExists: true))
			} else if error?.isAuthenticationError == true {
				completion(PathExistsIntentResponse(code: .authenticationFailed, userActivity: nil))
			} else if error?.isNetworkConnectionError == true {
				completion(PathExistsIntentResponse(code: .networkUnavailable, userActivity: nil))
			} else if core != nil {
				completion(PathExistsIntentResponse.success(pathExists: false))
			} else {
				completion(PathExistsIntentResponse(code: .failure, userActivity: nil))
			}
		}
	}

	func resolveAccount(for intent: PathExistsIntent, with completion: @escaping (AccountResolutionResult) -> Void) {
		if let account = intent.account {
			completion(AccountResolutionResult.success(with: account))
		} else {
			completion(AccountResolutionResult.needsValue())
		}
	}

	func provideAccountOptions(for intent: PathExistsIntent, with completion: @escaping ([Account]?, Error?) -> Void) {
		completion(OCBookmarkManager.shared.accountList, nil)
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideAccountOptionsCollection(for intent: PathExistsIntent, with completion: @escaping (INObjectCollection<Account>?, Error?) -> Void) {
		completion(INObjectCollection(items: OCBookmarkManager.shared.accountList), nil)
	}

	func resolvePath(for intent: PathExistsIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
		if let path = intent.path {
			completion(INStringResolutionResult.success(with: path))
		} else {
			completion(INStringResolutionResult.needsValue())
		}
	}
}

@available(iOS 13.0, *)
extension PathExistsIntentResponse {

    public static func success(pathExists: Bool) -> PathExistsIntentResponse {
        let intentResponse = PathExistsIntentResponse(code: .success, userActivity: nil)
        intentResponse.pathExists = NSNumber(value: pathExists)
        return intentResponse
    }
}
