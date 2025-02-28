//
//  DisplayViewProtocol.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 29/08/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit
import ownCloudSDK
import CoreServices
import UniformTypeIdentifiers

protocol DisplayExtension where Self: DisplayViewController {

	static var features: [String : Any]? {get}
	static var supportedMimeTypes: [String]? {get}
	static var displayExtensionIdentifier: String {get}

	static var displayExtension: OCExtension {get}

	static var customMatcher: OCExtensionCustomContextMatcher? {get}
}

extension DisplayExtension {
	static var displayExtension: OCExtension {
		let rawIdentifier: OCExtensionIdentifier =  OCExtensionIdentifier(rawValue: displayExtensionIdentifier)
		var locationIdentifiers: [OCExtensionLocationIdentifier] = []

		if let supportedMimeTypes = supportedMimeTypes {
			for mimeType in supportedMimeTypes {
				let locationIdentifier: OCExtensionLocationIdentifier = OCExtensionLocationIdentifier(rawValue: mimeType)
				locationIdentifiers.append(locationIdentifier)
			}
		}

		let displayExtension = OCExtension(identifier: rawIdentifier, type: .viewer, locations: locationIdentifiers, features: features, objectProvider: { (_ rawExtension, _ context, _ error) -> Any? in
			let displayViewController = Self()
			displayViewController.clientContext = (context as? DisplayExtensionContext)?.clientContext
			return displayViewController
		}, customMatcher:customMatcher)

		return displayExtension
	}

	static func mimeTypeConformsTo(mime: String, utType: UTType) -> Bool {
		// Quick check if mime type looks plausible to avoid expensive lookups done by CoreServices APIs
		guard !mime.contains(" ") && mime.contains("/") else { return false }

		guard let uti = UTType(mimeType: mime) else {
			return false
		}

		return uti.conforms(to: utType)
	}
}

struct FeatureKeys {
	static let canEdit: String = "featureKeyCanEdit"
}
