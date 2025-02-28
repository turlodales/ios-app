//
//  AccountAuthenticationUpdater.swift
//  ownCloud
//
//  Created by Felix Schwarz on 25.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit
import ownCloudSDK

public class AccountAuthenticationUpdater: NSObject {
	var bookmark : OCBookmark
	var preferredAuthenticationMethodIdentifiers: [OCAuthenticationMethodIdentifier]?

	public init(with inBookmark: OCBookmark, preferredAuthenticationMethods authMethodIDs: [OCAuthenticationMethodIdentifier]?) {
		bookmark = inBookmark
		preferredAuthenticationMethodIdentifiers = authMethodIDs

		super.init()
	}

	open var authenticationMethodIdentifier : OCAuthenticationMethodIdentifier? {
		if let methods = preferredAuthenticationMethodIdentifiers, methods.count > 0,
		   let existingAuthMethod = bookmark.authenticationMethodIdentifier,
		   !methods.contains(existingAuthMethod) {
			return methods.first
		}

		return bookmark.authenticationMethodIdentifier ?? preferredAuthenticationMethodIdentifiers?.first
	}

	var isTokenBased : Bool {
		if let authenticationMethodIdentifier = self.authenticationMethodIdentifier, let authenticationMethodClass = OCAuthenticationMethod.registeredAuthenticationMethod(forIdentifier: authenticationMethodIdentifier) {
			return authenticationMethodClass.type == .token
		}

		return false
	}

	open var canUpdateInline : Bool {
		return (isTokenBased || (!isTokenBased && (bookmark.userName != nil))) && (preferredAuthenticationMethodIdentifiers != nil) && ((preferredAuthenticationMethodIdentifiers?.count ?? 0) > 0)
	}

	open func updateAuthenticationData(on viewController: UIViewController, completion: ((Error?) -> Void)? = nil) {
		if let url = bookmark.url, let authenticationMethodID = self.authenticationMethodIdentifier, self.canUpdateInline {
			let tempBookmark = OCBookmark(for: url)
			let tempConnection = OCConnection(bookmark: tempBookmark)
			var options : [OCAuthenticationMethodKey : Any] = [:]

			tempBookmark.setLastUserName(bookmark.userName)

			if let cookieSupportEnabled = OCCore.classSetting(forOCClassSettingsKey: .coreCookieSupportEnabled) as? Bool, cookieSupportEnabled == true {
				tempConnection.cookieStorage = OCHTTPCookieStorage()
				Log.debug("Created cookie storage \(String(describing: tempConnection.cookieStorage)) for client auth updater")
			}

			options[.presentingViewControllerKey] = viewController
			options[.requiredUsernameKey] = bookmark.userName

			tempBookmark.authenticationMethodIdentifier = authenticationMethodID

			if self.isTokenBased {
				tempConnection.generateAuthenticationData(withMethod: authenticationMethodID, options: options) { (error, authMethodIdentifier, authMethodData) in
					if let authMethodIdentifier = authMethodIdentifier, let authMethodData = authMethodData, error == nil {
						self.bookmark.authenticationMethodIdentifier = authMethodIdentifier
						self.bookmark.authenticationData = authMethodData
						OCBookmarkManager.shared.updateBookmark(self.bookmark)

						completion?(nil)
					} else {
						completion?(error ?? NSError(ocError: .internal))
					}
				}
			} else {
				let updateViewController = AccountAuthenticationUpdaterPasswordPromptViewController(passwordHeaderText: bookmark.shortName, passwordValidationHandler: { (password, errorHandler) in
					// Password Validation + Update
					if let userName = self.bookmark.userName {
						var options : [OCAuthenticationMethodKey : Any] = [:]

						options[.usernameKey] = userName
						options[.passphraseKey] = password

						tempConnection.generateAuthenticationData(withMethod: authenticationMethodID, options: options) { (error, authMethodIdentifier, authMethodData) in
							if let authMethodIdentifier = authMethodIdentifier, let authMethodData = authMethodData, error == nil {
								self.bookmark.authenticationMethodIdentifier = authMethodIdentifier
								self.bookmark.authenticationData = authMethodData
								OCBookmarkManager.shared.updateBookmark(self.bookmark)

								errorHandler(nil)
								completion?(nil)
							} else {
								errorHandler(error ?? NSError(ocError: .internal))
							}
						}
					} else {
						errorHandler(NSError(ocError: .internal))
					}
				})

				viewController.present(asCard: ThemeNavigationController(rootViewController: updateViewController), animated: true, completion: nil)
			}
		} else {
			completion?(NSError(ocError: .internal))
		}
	}
}
