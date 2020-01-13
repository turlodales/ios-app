//
//  IntentSettings.swift
//  ownCloudAppShared
//
//  Created by Felix Schwarz on 13.01.20.
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

import ownCloudApp

class IntentSettings: NSObject {
	static let shared = {
		IntentSettings()
	}()

	override init() {
		OCLicenseManager.shared.setupLicenseManagement()
	}

	var isEnabled : Bool = true

	func isLicensedFor(bookmark: OCBookmark, core: OCCore? = nil) -> Bool {
		var environment : OCLicenseEnvironment? = core?.licenseEnvironment

		if environment == nil {
			environment = OCLicenseEnvironment(bookmark: bookmark)
		}

		if let environment = environment {
			return (OCLicenseManager.shared.authorizationStatus(forFeature: .shortcuts, in: environment) == .granted)
		}

		return false
	}
}