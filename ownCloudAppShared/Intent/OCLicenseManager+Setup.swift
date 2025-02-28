//
//  OCLicenseManager+Setup.swift
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

public extension OCLicenseFeatureIdentifier {
	static var documentScanner : OCLicenseFeatureIdentifier { return OCLicenseFeatureIdentifier(rawValue: "document-scanner") }
	static var shortcuts : OCLicenseFeatureIdentifier { return OCLicenseFeatureIdentifier(rawValue: "shortcuts") }
	static var documentMarkup : OCLicenseFeatureIdentifier { return OCLicenseFeatureIdentifier(rawValue: "document-markup") }
	static var photoProFeatures : OCLicenseFeatureIdentifier { return OCLicenseFeatureIdentifier(rawValue: "photo-pro-features") }
}

public extension OCLicenseProductIdentifier {
	static var singleDocumentScanner : OCLicenseProductIdentifier { return OCLicenseProductIdentifier(rawValue: "single.document-scanner") }
	static var singleShortcuts : OCLicenseProductIdentifier { return OCLicenseProductIdentifier(rawValue: "single.shortcuts") }
	static var singleDocumentMarkup : OCLicenseProductIdentifier { return OCLicenseProductIdentifier(rawValue: "single.document-markup") }
	static var singlePhotoProFeatures : OCLicenseProductIdentifier { return OCLicenseProductIdentifier(rawValue: "single.photo-pro-features") }

	static var bundlePro : OCLicenseProductIdentifier { return OCLicenseProductIdentifier(rawValue: "bundle.pro") }
}

private var OCLicenseManagerHasBeenSetup : Bool = false

public extension OCLicenseManager {
	func setupLicenseManagement() {
		if OCLicenseManagerHasBeenSetup {
			return
		}

		OCLicenseManagerHasBeenSetup = true

		// Set up features and products
		let documentScannerFeature = OCLicenseFeature(identifier: .documentScanner, name: OCLocalizedString("Document Scanner", nil), description: OCLocalizedString("Scan documents and photos with your camera.", nil))
		let shortcutsFeature = OCLicenseFeature(identifier: .shortcuts, name: OCLocalizedString("Shortcuts Actions", nil), description: OCLocalizedString("Use ownCloud actions in Shortcuts.", nil))
		let documentMarkupFeature = OCLicenseFeature(identifier: .documentMarkup, name: OCLocalizedString("Markup Documents", nil), description: OCLocalizedString("Markup photos and PDF files.", nil))
		let photoProFeature = OCLicenseFeature(identifier: .photoProFeatures, name: OCLocalizedString("Photo Pro Features", nil), description: OCLocalizedString("Image metadata, extended upload options", nil))

		// - Features
		register(documentScannerFeature)
		register(shortcutsFeature)
		register(documentMarkupFeature)
		register(photoProFeature)

		// - Single feature products
		register(OCLicenseProduct(identifier: .singleDocumentScanner, name: documentScannerFeature.localizedName!, description: documentScannerFeature.localizedDescription, contents: [.documentScanner]))
		register(OCLicenseProduct(identifier: .singleShortcuts, name: shortcutsFeature.localizedName!, description: shortcutsFeature.localizedDescription, contents: [.shortcuts]))
		register(OCLicenseProduct(identifier: .singleDocumentMarkup, name: documentMarkupFeature.localizedName!, description: documentMarkupFeature.localizedDescription, contents: [.documentMarkup]))
		register(OCLicenseProduct(identifier: .singlePhotoProFeatures, name: photoProFeature.localizedName!, description: photoProFeature.localizedDescription, contents: [.photoProFeatures]))

		// - Subscription
		register(OCLicenseProduct(identifier: .bundlePro, name: OCLocalizedString("Pro Features", nil), description: OCLocalizedString("Unlock all Pro Features.", nil), contents: [.documentScanner, .shortcuts, .documentMarkup, .photoProFeatures]))

		// Set up App Store License Provider
		#if !DISABLE_APPSTORE_LICENSING
		if let disableAppStoreLicensing = classSetting(forOCClassSettingsKey: .disableAppStoreLicensing) as? Bool, disableAppStoreLicensing == false, // only add AppStore IAP provider (and IAPs) if IAP licernsing has not been disabled via ClassSettings
		   !OCLicenseEMMProvider.isEMMVersion { // only add AppStore IAP provider (and IAPs) if this is not the EMM version (which is supposed to already include all of them)
			let appStoreLicenseProvider = OCLicenseAppStoreProvider(items: [
				OCLicenseAppStoreItem.nonConsumableIAP(withAppStoreIdentifier: "single.documentscanner", productIdentifier: .singleDocumentScanner),
				OCLicenseAppStoreItem.nonConsumableIAP(withAppStoreIdentifier: "single.shortcuts", productIdentifier: .singleShortcuts),
				OCLicenseAppStoreItem.nonConsumableIAP(withAppStoreIdentifier: "single.documentmarkup", productIdentifier: .singleDocumentMarkup),
				OCLicenseAppStoreItem.nonConsumableIAP(withAppStoreIdentifier: "single.photo_pro_features", productIdentifier: .singlePhotoProFeatures),
				OCLicenseAppStoreItem.subscription(withAppStoreIdentifier: "bundle.pro", productIdentifier: .bundlePro, trialDuration: OCLicenseDuration(unit: .day, length: 14))
			])

			add(appStoreLicenseProvider)
		}
		#endif

		// Set up Enterprise Provider
		if let disableEnterpriseLicensing = classSetting(forOCClassSettingsKey: .disableEnterpriseLicensing) as? Bool, disableEnterpriseLicensing == false { // only add Enterprise provider if not disabled via ClassSettings
			let enterpriseProvider = OCLicenseEnterpriseProvider(unlockedProductIdentifiers: [.bundlePro])

			add(enterpriseProvider)
		}

		// Set up EMM Provider
		let emmProvider = OCLicenseEMMProvider(unlockedProductIdentifiers: [.bundlePro])
		add(emmProvider)

		// Set up QA Provider
		let qaProvider = OCLicenseQAProvider(unlockedProductIdentifiers: [.bundlePro], delegate: VendorServices.shared)
		add(qaProvider)
	}
}

public extension OCClassSettingsIdentifier {
	static var licensing : OCClassSettingsIdentifier { return OCClassSettingsIdentifier(rawValue: "licensing") }
}

public extension OCClassSettingsKey {
	static var disableAppStoreLicensing : OCClassSettingsKey { return OCClassSettingsKey(rawValue: "disable-appstore-licensing") }
	static var disableEnterpriseLicensing : OCClassSettingsKey { return OCClassSettingsKey(rawValue: "disable-enterprise-licensing") }
}

extension OCLicenseManager : ownCloudSDK.OCClassSettingsSupport {
	public static var classSettingsIdentifier: OCClassSettingsIdentifier {
		return .licensing
	}

	public static func defaultSettings(forIdentifier identifier: OCClassSettingsIdentifier) -> [OCClassSettingsKey : Any]? {
		return [
			.disableAppStoreLicensing : false,
			.disableEnterpriseLicensing : false
		]
	}

	public static func classSettingsMetadata() -> [OCClassSettingsKey : [OCClassSettingsMetadataKey : Any]]? {
		return [
			.disableAppStoreLicensing : [
				.type 		: OCClassSettingsMetadataType.boolean,
				.description	: "Enables/disables App Store licensing support.",
				.category	: "Licensing",
				.status		: OCClassSettingsKeyStatus.debugOnly
			],

			.disableEnterpriseLicensing : [
				.type 		: OCClassSettingsMetadataType.boolean,
				.description	: "Enables/disables Enterprise licensing support.",
				.category	: "Licensing",
				.status		: OCClassSettingsKeyStatus.debugOnly
			]
		]
	}
}
