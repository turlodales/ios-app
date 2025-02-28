//
//  ReleaseNotesHostViewController.swift
//  ownCloud
//
//  Created by Matthias Hühne on 04.12.19.
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
import ownCloudSDK
import ownCloudAppShared

class ReleaseNotesHostViewController: UIViewController {

	// MARK: - Constants
	private let cornerRadius : CGFloat = 8.0
	private let padding : CGFloat = 20.0
	private let smallPadding : CGFloat = 10.0
	private let buttonHeight : CGFloat = 44.0
	private let headerHeight : CGFloat = 60.0

	// MARK: - Instance Variables
	var titleLabel = ThemeCSSLabel(withSelectors: [.title])
	var proceedButton = ThemeButton(withSelectors: [.cancel])
	var footerButton = UIButton()

	override func viewDidLoad() {
		super.viewDidLoad()

		self.cssSelectors = [.modal, .releaseNotes]

		ReleaseNotesDatasource.setUserPreferenceValue(NSString(utf8String: VendorServices.shared.appBuildNumber), forClassSettingsKey: .lastSeenReleaseNotesVersion)

		let appName = OCAppIdentity.shared.appName ?? "ownCloud"

		let headerView = UIView()
		headerView.backgroundColor = .clear
		headerView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(headerView)
		NSLayoutConstraint.activate([
			headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			headerView.heightAnchor.constraint(equalToConstant: headerHeight)
		])

		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: NSLayoutConstraint.Axis.horizontal)

		titleLabel.text = String(format:OCLocalizedString("New in %@", nil), appName)
		titleLabel.textAlignment = .center
		titleLabel.numberOfLines = 0
		titleLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
		titleLabel.adjustsFontForContentSizeCategory = true
		headerView.addSubview(titleLabel)

		NSLayoutConstraint.activate([
			titleLabel.leftAnchor.constraint(greaterThanOrEqualTo: headerView.safeAreaLayoutGuide.leftAnchor, constant: padding),
			titleLabel.rightAnchor.constraint(lessThanOrEqualTo: headerView.safeAreaLayoutGuide.rightAnchor, constant: padding * -1),
			titleLabel.centerXAnchor.constraint(equalTo: headerView.safeAreaLayoutGuide.centerXAnchor),

			titleLabel.topAnchor.constraint(equalTo: headerView.safeAreaLayoutGuide.topAnchor, constant: padding)
		])

		let releaseNotesController = ReleaseNotesTableViewController(style: .plain)
		if let containerView = releaseNotesController.view {
			containerView.backgroundColor = .clear
			containerView.translatesAutoresizingMaskIntoConstraints = false
			view.addSubview(containerView)

			let bottomView = UIView()
			bottomView.backgroundColor = .clear
			bottomView.translatesAutoresizingMaskIntoConstraints = false
			view.addSubview(bottomView)
			NSLayoutConstraint.activate([
				bottomView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
				bottomView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
				bottomView.topAnchor.constraint(equalTo: containerView.bottomAnchor),
				bottomView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
			])

			proceedButton.setTitle(OCLocalizedString("Proceed", nil), for: .normal)
			proceedButton.translatesAutoresizingMaskIntoConstraints = false
			proceedButton.addTarget(self, action: #selector(dismissView), for: .touchUpInside)
			bottomView.addSubview(proceedButton)

			let appName = VendorServices.shared.appName
			var footerText = ""
			if VendorServices.shared.isBranded {
				footerText = String(format:OCLocalizedString("Thank you for using %@.\n", nil), appName)
			} else {
				footerText = String(format:OCLocalizedString("Thank you for using %@.\nIf you like our App, please leave an AppStore review.\n❤️", nil), appName)
			}
			footerButton.setTitle(footerText, for: .normal)

			footerButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.footnote)
			footerButton.titleLabel?.adjustsFontForContentSizeCategory = true
			footerButton.titleLabel?.numberOfLines = 0
			footerButton.titleLabel?.textAlignment = .center
			footerButton.cssSelectors = [.subtitle]
			footerButton.translatesAutoresizingMaskIntoConstraints = false
			footerButton.addTarget(self, action: #selector(rateApp), for: .touchUpInside)
			bottomView.addSubview(footerButton)

			NSLayoutConstraint.activate([
				footerButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: padding),
				footerButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: padding * -1),
				footerButton.topAnchor.constraint(equalTo: bottomView.topAnchor, constant: smallPadding),
				footerButton.bottomAnchor.constraint(equalTo: proceedButton.topAnchor, constant: padding * -1)
			])

			NSLayoutConstraint.activate([
				proceedButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: padding),
				proceedButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: padding * -1),
				proceedButton.heightAnchor.constraint(equalToConstant: buttonHeight),
				proceedButton.bottomAnchor.constraint(equalTo: bottomView.bottomAnchor, constant: smallPadding * -2)
			])

			NSLayoutConstraint.activate([
				containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
				containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
				containerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
				containerView.bottomAnchor.constraint(equalTo: bottomView.topAnchor)
			])
		}

		Theme.shared.register(client: self)
	}

	deinit {
		Theme.shared.unregister(client: self)
	}

	@objc func dismissView() {
		self.dismiss(animated: true, completion: nil)
	}

	@objc func rateApp() {
		guard let appStoreLink =  VendorServices.classSetting(forOCClassSettingsKey: .appStoreLink) as? String else { return }

		guard let reviewURL = URL(string: "\(appStoreLink)&action=write-review") else { return }

		guard UIApplication.shared.canOpenURL(reviewURL) else { return }
		UIApplication.shared.open(reviewURL)
	}
}

// MARK: - Themeable implementation
extension ReleaseNotesHostViewController : Themeable {
	func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		view.apply(css: collection.css, selectors: nil, properties: [.fill])
		footerButton.apply(css: collection.css, properties: [.stroke])
	}
}

class ReleaseNotesDatasource : NSObject, OCClassSettingsUserPreferencesSupport {

	static var shouldShowReleaseNotes: Bool {
		if VendorServices.shared.isBranded {
			return false
		} else if let lastSeenReleaseNotesVersion = self.classSetting(forOCClassSettingsKey: .lastSeenReleaseNotesVersion) as? String {

			if lastSeenReleaseNotesVersion.compare(VendorServices.shared.appBuildNumber, options: .numeric) == .orderedDescending || lastSeenReleaseNotesVersion.compare(VendorServices.shared.appBuildNumber, options: .numeric) == .orderedSame {
				return false
			}

			if let path = Bundle.main.path(forResource: "ReleaseNotes", ofType: "plist"), let releaseNotesValues = NSDictionary(contentsOfFile: path), let versionsValues = releaseNotesValues["Versions"] as? NSArray {

				let relevantReleaseNotes = versionsValues.filter {
					if let version = ($0 as AnyObject)["Version"] as? String, version.compare(VendorServices.shared.appVersion, options: .numeric) == .orderedDescending {
						return false
					}

					return true
				}

				if relevantReleaseNotes.count > 0 {
					return true
				}
			}

			return false
		} else if self.classSetting(forOCClassSettingsKey: .lastSeenAppVersion) != nil {
			if self.classSetting(forOCClassSettingsKey: .lastSeenAppVersion) as? String != VendorServices.shared.appBuildNumber {
				   return true
			}
			return false
		} else if OCBookmarkManager.shared.bookmarks.count > 0 && !VendorServices.shared.isBranded {
			// Fallback, if app was previously installed, because we cannot check for an user defaults key, we have to check if accounts was previously configured
			return true
		}

		return false
	}

	static func releaseNotes(for version: String) -> [[String:Any]]? {
		if let path = Bundle.main.path(forResource: "ReleaseNotes", ofType: "plist") {
			if let releaseNotesValues = NSDictionary(contentsOfFile: path), let versionsValues = releaseNotesValues["Versions"] as? NSArray {

				let relevantReleaseNotes = versionsValues.filter {
					if let version = ($0 as AnyObject)["Version"] as? String, version.compare(VendorServices.shared.appVersion, options: .numeric) == .orderedAscending {
						return false
					}

					return true
				}

				return relevantReleaseNotes as? [[String:Any]]
			}
		}

		return nil
	}

	static func image(for key: String) -> UIImage? {
		let homeSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 32, weight: .thin)
		return UIImage(systemName: key, withConfiguration: homeSymbolConfiguration)?.withRenderingMode(.alwaysTemplate)
	}

	static func updateLastSeenAppVersion() {
		ReleaseNotesDatasource.setUserPreferenceValue(NSString(utf8String: VendorServices.shared.appVersion), forClassSettingsKey: .lastSeenAppVersion)
	}
}

public extension OCClassSettingsIdentifier {
	static let releasenotes = OCClassSettingsIdentifier("releasenotes")
}

extension OCClassSettingsKey {
	 // Available since version 1.3.0
	static let lastSeenReleaseNotesVersion = OCClassSettingsKey("lastSeenReleaseNotesVersion")
	static let lastSeenAppVersion = OCClassSettingsKey("lastSeenAppVersion")
}

extension ReleaseNotesDatasource : OCClassSettingsSupport {
	static let classSettingsIdentifier : OCClassSettingsIdentifier = .releasenotes

	static func defaultSettings(forIdentifier identifier: OCClassSettingsIdentifier) -> [OCClassSettingsKey : Any]? {
		return nil
	}

	static func classSettingsMetadata() -> [OCClassSettingsKey : [OCClassSettingsMetadataKey : Any]]? {
		return [
			.lastSeenReleaseNotesVersion : [
				.type 		: OCClassSettingsMetadataType.string,
				.description	: "The app version for which the release notes were last shown.",
				.category	: "Release Notes",
				.status		: OCClassSettingsKeyStatus.debugOnly
			],

			.lastSeenAppVersion : [
				.type 		: OCClassSettingsMetadataType.string,
				.description	: "The last-seen app version.",
				.category	: "Release Notes",
				.status		: OCClassSettingsKeyStatus.debugOnly
			]
		]
	}
}

extension ThemeCSSSelector {
	static let releaseNotes = ThemeCSSSelector(rawValue: "releaseNotes")
}
