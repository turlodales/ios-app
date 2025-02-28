//
//  GetFileInfoIntentHandler.swift
//  ownCloudAppShared
//
//  Created by Matthias Hühne on 27.08.19.
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
public class GetFileInfoIntentHandler: NSObject, GetFileInfoIntentHandling {

	func handle(intent: GetFileInfoIntent, completion: @escaping (GetFileInfoIntentResponse) -> Void) {

		guard IntentSettings.shared.isEnabled else {
			completion(GetFileInfoIntentResponse(code: .disabled, userActivity: nil))
			return
		}

		guard !AppLockManager.isPassCodeEnabled else {
			completion(GetFileInfoIntentResponse(code: .authenticationRequired, userActivity: nil))
			return
		}

		guard let path = intent.path, let uuid = intent.account?.uuid else {
			completion(GetFileInfoIntentResponse(code: .failure, userActivity: nil))
			return
		}

		guard let bookmark = OCBookmarkManager.shared.bookmark(forUUIDString: uuid) else {
			completion(GetFileInfoIntentResponse(code: .accountFailure, userActivity: nil))
			return
		}

		guard IntentSettings.shared.isLicensedFor(bookmark: bookmark) else {
			completion(GetFileInfoIntentResponse(code: .unlicensed, userActivity: nil))
			return
		}

		OCItemTracker(for: bookmark, at: .legacyRootPath(path), waitOnlineTimeout: 5) { (error, core, item) in
			if error == nil, let targetItem = item {
				let fileInfo = FileInfo(identifier: targetItem.localID, display: targetItem.name ?? "")

				let calendar = Calendar.current
				if let creationDate = targetItem.creationDate {
					let components = calendar.dateTimeComponents(from: creationDate)
					fileInfo.creationDate = components
					fileInfo.creationDateTimestamp = NSNumber(value: creationDate.timeIntervalSince1970)
				}
				if let lastModified = targetItem.lastModified {
					let components = calendar.dateTimeComponents(from: lastModified)
					fileInfo.lastModified = components
					fileInfo.lastModifiedTimestamp = NSNumber(value: lastModified.timeIntervalSince1970)
				}
				fileInfo.isFavorite = targetItem.isFavorite
				fileInfo.mimeType = targetItem.mimeType
				fileInfo.size = NSNumber(value: targetItem.size)
				fileInfo.fileID = targetItem.fileID
				fileInfo.localID = targetItem.localID

				completion(GetFileInfoIntentResponse.success(fileInfo: fileInfo))
			} else if core != nil {
				completion(GetFileInfoIntentResponse(code: .pathFailure, userActivity: nil))
			} else if error?.isAuthenticationError == true {
				completion(GetFileInfoIntentResponse(code: .authenticationFailed, userActivity: nil))
			} else if error?.isNetworkConnectionError == true {
				completion(GetFileInfoIntentResponse(code: .networkUnavailable, userActivity: nil))
			} else {
				completion(GetFileInfoIntentResponse(code: .failure, userActivity: nil))
			}
		}
	}

	func resolveAccount(for intent: GetFileInfoIntent, with completion: @escaping (AccountResolutionResult) -> Void) {
		if let account = intent.account {
			completion(AccountResolutionResult.success(with: account))
		} else {
			completion(AccountResolutionResult.needsValue())
		}
	}

	func provideAccountOptions(for intent: GetFileInfoIntent, with completion: @escaping ([Account]?, Error?) -> Void) {
		completion(OCBookmarkManager.shared.accountList, nil)
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideAccountOptionsCollection(for intent: GetFileInfoIntent, with completion: @escaping (INObjectCollection<Account>?, Error?) -> Void) {
		completion(INObjectCollection(items: OCBookmarkManager.shared.accountList), nil)
	}

	func resolvePath(for intent: GetFileInfoIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
		if let path = intent.path {
			completion(INStringResolutionResult.success(with: path))
		} else {
			completion(INStringResolutionResult.needsValue())
		}
	}

}

@available(iOS 13.0, *)
extension GetFileInfoIntentResponse {

    public static func success(fileInfo: FileInfo) -> GetFileInfoIntentResponse {
        let intentResponse = GetFileInfoIntentResponse(code: .success, userActivity: nil)
        intentResponse.fileInfo = fileInfo
        return intentResponse
    }
}
