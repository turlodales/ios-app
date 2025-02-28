//
//  ThemeStyle+Extensions.swift
//  ownCloud
//
//  Created by Felix Schwarz on 26.10.18.
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

import Foundation
import ownCloudSDK
import ownCloudApp

extension ThemeStyle {
	public func themeStyleExtension(isDefault: Bool = false, isBranding: Bool = false) -> OCExtension {
		let features : [String:Any] = [
			ThemeStyleFeatureKeys.localizedName : self.localizedName,
			ThemeStyleFeatureKeys.isDefault	    : isDefault,
			ThemeStyleFeatureKeys.isBranding    : isBranding
		]

		return OCExtension(identifier: OCExtensionIdentifier(rawValue: self.identifier), type: .themeStyle, location: OCExtensionLocationIdentifier(rawValue: self.identifier), features: features, objectProvider: { (_, _, _) -> Any? in
			return self
		})
	}

	static public var defaultStyle: ThemeStyle {
		let matchContext = OCExtensionContext(location: OCExtensionLocation(ofType: .themeStyle, identifier: nil),
						      requirements: [ThemeStyleFeatureKeys.isDefault : true], // Match default
						      preferences: [ThemeStyleFeatureKeys.isBranding : true]) // Prefer brandings (=> boosts score of brandings so it outmatches built-in styles)

		if let matches : [OCExtensionMatch] = try? OCExtensionManager.shared.provideExtensions(for: matchContext),
		   matches.count > 0,
		   let styleExtension = matches.first?.extension,
		   let defaultStyle = styleExtension.provideObject(for: matchContext) as? ThemeStyle {
			return defaultStyle
		}

		Log.error("Couldn't get defaultStyle")

		return ThemeStyle.systemDark()
	}

	static public var preferredStyle : ThemeStyle {
		set {
			// Store preferred theme style to shared userDefaults
			OCAppIdentity.shared.userDefaults?.setValue(newValue.identifier, forKey: "preferred-theme-style")

			considerAppearanceUpdate(animated: true)
		}

		get {
			var style : ThemeStyle?

			// This setting was previously stored in UserDefaults.standard. If it exists there, make sure to move it over
			// and subsequently remove it, so it can't overwrite changes to the value coming after that.
			if let legacyLocalPreferredThemeStyleIdentifier = UserDefaults.standard.string(forKey: "preferred-theme-style") {
				OCAppIdentity.shared.userDefaults?.setValue(legacyLocalPreferredThemeStyleIdentifier, forKey: "preferred-theme-style")
				UserDefaults.standard.removeObject(forKey: "preferred-theme-style")
			}

			// Retrieve preferred theme style from shared userDefaults
			if let preferredThemeStyleIdentifier = OCAppIdentity.shared.userDefaults?.string(forKey: "preferred-theme-style") {
				style = .forIdentifier(preferredThemeStyleIdentifier)
			}

			if style == nil {
				style = .defaultStyle
			}

			return style!
		}
	}

	static public var displayName : String {
		if ThemeStyle.followSystemAppearance {
			return OCLocalizedString("System", nil)
		}

		return ThemeStyle.preferredStyle.localizedName
	}

	@available(iOS 13.0, *)
	static public func userInterfaceStyle() -> UIUserInterfaceStyle? {
		return UITraitCollection.current.userInterfaceStyle
	}

	static public func considerAppearanceUpdate(animated: Bool = false) {
		let rootView : UIView? = UserInterfaceContext.shared.rootView
		var applyStyle : ThemeStyle? = ThemeStyle.preferredStyle

		if self.followSystemAppearance {
			if ThemeStyle.userInterfaceStyle() == .dark {
				if let style = ThemeStyle.forIdentifier("com.owncloud.dark") {
					applyStyle = style
				}
			} else {
				if let style = ThemeStyle.forIdentifier("com.owncloud.light") {
					applyStyle = style
				}
			}
		}

		if let applyStyle = applyStyle {
			let themeCollection = ThemeCollection(with: applyStyle)

			if let themeWindowSubviews = rootView?.subviews {
				for view in themeWindowSubviews {
					view.overrideUserInterfaceStyle = themeCollection.css.getUserInterfaceStyle()
				}
			}

			if animated {
				Theme.shared.switchThemeCollection(themeCollection)
			} else {
				Theme.shared.activeCollection = themeCollection
			}
		}
	}

	static public var followSystemAppearance : Bool {
		set {
			OCAppIdentity.shared.userDefaults?.setValue(newValue, forKey: "theme-style-follows-system-appearance")

			considerAppearanceUpdate()
		}

		get {
			var followSystemAppearance : Bool?

			if let themeStyleFollowsSystemAppearance = OCAppIdentity.shared.userDefaults?.object(forKey: "theme-style-follows-system-appearance") as? Bool {
				followSystemAppearance = themeStyleFollowsSystemAppearance
			}

			if followSystemAppearance == nil {
				followSystemAppearance = true
			}

			return followSystemAppearance!
		}

	}

	static public func forIdentifier(_ identifier: ThemeStyleIdentifier) -> ThemeStyle? {
		let matchContext = OCExtensionContext(location: OCExtensionLocation(ofType: .themeStyle, identifier: OCExtensionLocationIdentifier(rawValue: identifier)), requirements: nil, preferences: nil)

		if let matches : [OCExtensionMatch] = try? OCExtensionManager.shared.provideExtensions(for: matchContext),
		   matches.count > 0,
		   let styleExtension = matches.first?.extension,
		   let style = styleExtension.provideObject(for: matchContext) as? ThemeStyle {
			return style
		}

		return nil
	}

	static public var availableStyles : [ThemeStyle]? {
		let matchContext = OCExtensionContext(location: OCExtensionLocation(ofType: .themeStyle, identifier: nil), requirements: nil, preferences: nil)

		if let matches : [OCExtensionMatch] = try? OCExtensionManager.shared.provideExtensions(for: matchContext), matches.count > 0 {
			var styles : [ThemeStyle] = []

			for match in matches {
				if let style = match.extension.provideObject(for: matchContext) as? ThemeStyle {
					styles.append(style)
				}
			}

			return styles
		}

		return nil
	}

	static public func registerDefaultStyles() {
		if !Branding.shared.setupThemeStyles() {
			OCExtensionManager.shared.addExtension(ThemeStyle.systemLight().themeStyleExtension(isDefault: true))
			OCExtensionManager.shared.addExtension(ThemeStyle.systemDark().themeStyleExtension())
		}
	}

	static public func availableStyles(for styles: [ThemeCollectionStyle]) -> [ThemeStyle]? {
		let styles = ThemeStyle.availableStyles?.filter { (theme) -> Bool in
			if styles.contains(theme.themeStyle) {
				return true
			}

			return false
		}

		return styles
	}
}

extension OCExtensionType {
	static let themeStyle: OCExtensionType  =  OCExtensionType("app.themeStyle")
}

struct ThemeStyleFeatureKeys {
	static let localizedName: String = "localizedName"
	static let isDefault: String = "isDefault"
	static let isBranding: String = "isBranding"
}
