//
//  ThemeCollection.swift
//  ownCloud
//
//  Created by Felix Schwarz on 10.04.18.
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

class ThemeColorPair : NSObject {
	@objc var foreground: UIColor
	@objc var background: UIColor

	init(foreground fgColor: UIColor, background bgColor: UIColor) {
		foreground = fgColor
		background = bgColor
	}
}

class ThemeColorPairCollection : NSObject {
	@objc var normal : ThemeColorPair
	@objc var highlighted : ThemeColorPair
	@objc var disabled : ThemeColorPair

	init(fromPair: ThemeColorPair) {
		normal = fromPair
		highlighted = ThemeColorPair(foreground: fromPair.foreground, background: fromPair.background.lighter(0.25))
		disabled = ThemeColorPair(foreground: fromPair.foreground, background: fromPair.background.lighter(0.25))
	}
}

class ThemeColorCollection : NSObject {
	@objc var backgroundColor : UIColor?
	@objc var labelColor : UIColor
	@objc var secondaryLabelColor : UIColor
	@objc var symbolColor : UIColor
	@objc var tintColor : UIColor?

	@objc var filledColorPairCollection : ThemeColorPairCollection

	init(backgroundColor bgColor : UIColor?, tintColor tntColor: UIColor?, labelColor lblColor : UIColor, secondaryLabelColor secLabelColor: UIColor, symbolColor symColor: UIColor, filledColorPairCollection filColorPairCollection: ThemeColorPairCollection) {
		backgroundColor = bgColor
		labelColor = lblColor
		symbolColor = symColor
		secondaryLabelColor = secLabelColor
		tintColor = tntColor
		filledColorPairCollection = filColorPairCollection
	}
}

enum ThemeCollectionStyle : String, CaseIterable {
	case dark
	case light
	case contrast

	var name : String {
		switch self {
			case .dark:	return "Dark".localized
			case .light:	return "Light".localized
			case .contrast:	return "Contrast".localized
		}
	}
}

class ThemeCollection : NSObject {
	@objc var identifier : String = UUID().uuidString

	// MARK: - Brand colors
	@objc var darkBrandColor: UIColor
	@objc var lightBrandColor: UIColor

	// MARK: - Brand color collection
	@objc var darkBrandColors : ThemeColorCollection
	@objc var lightBrandColors : ThemeColorCollection

	// MARK: - Button / Fill color collections
	@objc var approvalColors : ThemeColorPairCollection
	@objc var neutralColors : ThemeColorPairCollection
	@objc var destructiveColors : ThemeColorPairCollection

	// MARK: - Label colors
	@objc var informativeColor: UIColor
	@objc var successColor: UIColor
	@objc var warningColor: UIColor
	@objc var errorColor: UIColor

	@objc var tintColor : UIColor

	// MARK: - Table views
	@objc var tableBackgroundColor : UIColor
	@objc var tableGroupBackgroundColor : UIColor
	@objc var tableSeparatorColor : UIColor?
	@objc var tableRowColors : ThemeColorCollection
	@objc var tableRowHighlightColors : ThemeColorCollection
	@objc var tableRowBorderColor : UIColor?

	// MARK: - Bars
	@objc var navigationBarColors : ThemeColorCollection
	@objc var toolbarColors : ThemeColorCollection
	@objc var statusBarStyle : UIStatusBarStyle
	@objc var barStyle : UIBarStyle

	// MARK: - SearchBar
	@objc var searchbarColors : ThemeColorCollection

	// MARK: - Progress
	@objc var progressColors : ThemeColorPair

	// MARK: - Activity View
	@objc var activityIndicatorViewStyle : UIActivityIndicatorView.Style
	@objc var searchBarActivityIndicatorViewStyle : UIActivityIndicatorView.Style

	// MARK: - Icon colors
	@objc var iconColors : [String:String]

	@objc var favoriteEnabledColor : UIColor?
	@objc var favoriteDisabledColor : UIColor?

	// MARK: - Default Collection
	static var defaultCollection : ThemeCollection = {
		let collection = ThemeCollection()

		/*
		Log.log("%@", collection.value(forKeyPath: "tintColor") as! CVarArg)
		Log.log("%@", collection.value(forKeyPath: "toolBarColorCollection.filledColorPairCollection.normal.background") as! CVarArg)
		Log.log("%@", collection.value(forKeyPath: "toolBarColorCollection.filledColorPairCollection.normal.backgrounds") as! CVarArg)
		*/

		return (collection)
	}()

	static var darkCollection : ThemeCollection = {
		let collection = ThemeCollection()

		return (collection)
	}()

	init(darkBrandColor darkColor: UIColor, lightBrandColor lightColor: UIColor, style: ThemeCollectionStyle = .dark, customColors: NSDictionary? = nil, genericColors: NSDictionary? = nil) {
		var logoFillColor : UIColor?

		self.darkBrandColor = darkColor
		self.lightBrandColor = lightColor

		var colors = NSDictionary()
		if let customColors = customColors {
			colors = customColors
		}
		var generic = NSDictionary()
		if let genericColors = genericColors {
			generic = genericColors
		}

		self.darkBrandColors = colors.resolveThemeColorCollection("darkBrandColors", ThemeColorCollection(
			backgroundColor: darkColor,
			tintColor: lightColor.lighter(0.2),
			labelColor: UIColor.white,
			secondaryLabelColor: UIColor.lightGray,
			symbolColor: UIColor.white,
			filledColorPairCollection: ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: darkColor))
		), generic)

		self.lightBrandColors = colors.resolveThemeColorCollection("lightBrandColors", ThemeColorCollection(
			backgroundColor: lightColor,
			tintColor: UIColor.white,
			labelColor: UIColor.white,
			secondaryLabelColor: UIColor.lightGray,
			symbolColor: UIColor.white,
			filledColorPairCollection: ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: lightBrandColor))
		), generic)

		self.informativeColor = colors.resolveColor("Label.informativeColor", UIColor.darkGray, generic)
		self.successColor = colors.resolveColor("Label.successColor", UIColor(hex: 0x27AE60), generic)
		self.warningColor = colors.resolveColor("Label.warningColor", UIColor(hex: 0xF2994A), generic)
		self.errorColor = colors.resolveColor("Label.errorColor", UIColor(hex: 0xEB5757), generic)

		self.approvalColors = colors.resolveThemeColorPairCollection("Fill.approvalColors", ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: UIColor(hex: 0x1AC763))), generic)
		self.neutralColors = colors.resolveThemeColorPairCollection("Fill.neutralColors", lightBrandColors.filledColorPairCollection, generic)
		self.destructiveColors = colors.resolveThemeColorPairCollection("Fill.destructiveColors", ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: UIColor.red)), generic)

		self.tintColor = colors.resolveColor("tintColor", self.lightBrandColor, generic)

		// Table view
		self.tableBackgroundColor = colors.resolveColor("Table.tableBackgroundColor", UIColor.white, generic)
		self.tableGroupBackgroundColor = colors.resolveColor("Table.tableGroupBackgroundColor", UIColor.groupTableViewBackground, generic)
		self.tableSeparatorColor = colors.resolveColor("Table.tableSeparatorColor", nil, generic)
		let rowColor : UIColor? = UIColor.black.withAlphaComponent(0.1)
		self.tableRowBorderColor = colors.resolveColor("Table.tableRowBorderColor", rowColor, generic)

		self.tableRowColors = colors.resolveThemeColorCollection("Table.tableRowColors", ThemeColorCollection(
			backgroundColor: tableBackgroundColor,
			tintColor: nil,
			labelColor: UIColor.black,
			secondaryLabelColor: UIColor.gray,
			symbolColor: darkColor,
			filledColorPairCollection: ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: lightBrandColor))
		), generic)

		self.tableRowHighlightColors = colors.resolveThemeColorCollection("Table.tableRowHighlightColors", ThemeColorCollection(
			backgroundColor: nil,
			tintColor: nil,
			labelColor: UIColor.black,
			secondaryLabelColor: UIColor.gray,
			symbolColor: darkColor,
			filledColorPairCollection: ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: lightBrandColor))
		), generic)

		self.favoriteEnabledColor = UIColor(hex: 0xFFCC00)
		self.favoriteDisabledColor = UIColor(hex: 0x7C7C7C)

		// Styles
		switch style {
			case .dark:
				// Bars
				self.navigationBarColors = colors.resolveThemeColorCollection("NavigationBar", self.darkBrandColors, generic)
				self.toolbarColors = colors.resolveThemeColorCollection("Toolbar", self.darkBrandColors, generic)
				self.searchbarColors = colors.resolveThemeColorCollection("Searchbar", self.darkBrandColors, generic)

				// Table view
				self.tableBackgroundColor = colors.resolveColor("Table.tableBackgroundColor", navigationBarColors.backgroundColor!.darker(0.1), generic)
				self.tableGroupBackgroundColor = colors.resolveColor("Table.tableGroupBackgroundColor", navigationBarColors.backgroundColor!.darker(0.3), generic)
				let separatorColor : UIColor? = UIColor.darkGray
				self.tableSeparatorColor = colors.resolveColor("Table.tableSeparatorColor", separatorColor, generic)
				let rowBorderColor : UIColor? = UIColor.white.withAlphaComponent(0.1)
				self.tableRowBorderColor = colors.resolveColor("Table.tableRowBorderColor", rowBorderColor, generic)
				self.tableRowColors = colors.resolveThemeColorCollection("Table.tableRowColors", ThemeColorCollection(
					backgroundColor: tableBackgroundColor,
					tintColor: navigationBarColors.tintColor,
					labelColor: navigationBarColors.labelColor,
					secondaryLabelColor: navigationBarColors.secondaryLabelColor,
					symbolColor: lightColor,
					filledColorPairCollection: ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: lightBrandColor))
				), generic)

				self.tableRowHighlightColors = colors.resolveThemeColorCollection("Table.tableRowHighlightColors", ThemeColorCollection(
					backgroundColor: lightColor.darker(0.2),
					tintColor: UIColor.white,
					labelColor: UIColor.white,
					secondaryLabelColor: UIColor.white,
					symbolColor: darkColor,
					filledColorPairCollection: ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: lightBrandColor))
				), generic)

				// Bar styles
				self.statusBarStyle = .lightContent
				self.barStyle = .black

				// Progress
				self.progressColors = ThemeColorPair(foreground: self.lightBrandColor, background: self.lightBrandColor.withAlphaComponent(0.3))

				// Activity
				self.activityIndicatorViewStyle = .white
				self.searchBarActivityIndicatorViewStyle = .white

				// Logo fill color
				let logoColor : UIColor? = UIColor.white
				logoFillColor = colors.resolveColor("Icon.logoFillColor", logoColor, generic)

			case .light:
				// Bars
				self.navigationBarColors = colors.resolveThemeColorCollection("NavigationBar", ThemeColorCollection(
					backgroundColor: UIColor.white.darker(0.05),
					tintColor: nil,
					labelColor: UIColor.black,
					secondaryLabelColor: UIColor.gray,
					symbolColor: darkColor,
					filledColorPairCollection: ThemeColorPairCollection(fromPair: ThemeColorPair(foreground: UIColor.white, background: lightBrandColor))
				), generic)

				self.toolbarColors = colors.resolveThemeColorCollection("Toolbar", self.navigationBarColors, generic)
				self.searchbarColors = colors.resolveThemeColorCollection("Searchbar", self.navigationBarColors, generic)

				// Bar styles
				self.statusBarStyle = .default
				self.barStyle = .default

				// Progress
				self.progressColors = ThemeColorPair(foreground: self.lightBrandColor, background: UIColor.lightGray.withAlphaComponent(0.3))

				// Activity
				self.activityIndicatorViewStyle = .gray
				self.searchBarActivityIndicatorViewStyle = .gray

				// Logo fill color
				logoFillColor = UIColor.lightGray

			case .contrast:
				// Bars
				self.navigationBarColors = colors.resolveThemeColorCollection("NavigationBar", self.darkBrandColors, generic)
				self.toolbarColors = colors.resolveThemeColorCollection("Toolbar", self.darkBrandColors, generic)
				self.searchbarColors = colors.resolveThemeColorCollection("Searchbar", self.darkBrandColors, generic)

				// Bar styles
				self.statusBarStyle = .lightContent
				self.barStyle = .black

				// Progress
				self.progressColors = colors.resolveThemeColorPair("Progress", ThemeColorPair(foreground: self.lightBrandColor, background: UIColor.lightGray.withAlphaComponent(0.3)), generic)

				// Activity
				self.activityIndicatorViewStyle = .gray
				self.searchBarActivityIndicatorViewStyle = .white

				// Logo fill color
				logoFillColor = UIColor.lightGray
		}

		let iconSymbolColor = self.tableRowColors.symbolColor

		self.iconColors = [
			"folderFillColor" : colors.resolveColor("Icon.folderFillColor", iconSymbolColor, generic).hexString(),
			"fileFillColor" : colors.resolveColor("Icon.fileFillColor", iconSymbolColor, generic).hexString(),
			"logoFillColor" : colors.resolveColor("Icon.logoFillColor", logoFillColor, generic)?.hexString() ?? "#ffffff",
			"iconFillColor" : colors.resolveColor("Icon.iconFillColor", tableRowColors.tintColor, generic)?.hexString() ?? iconSymbolColor.hexString(),
			"symbolFillColor" : colors.resolveColor("Icon.symbolFillColor", iconSymbolColor, generic).hexString()
		]
	}

	convenience override init() {
		self.init(darkBrandColor: UIColor(hex: 0x1D293B), lightBrandColor: UIColor(hex: 0x468CC8))
	}
}

extension NSDictionary {

	func resolveColor(_ forKeyPath: String, _ fallback : UIColor, _ generic: NSDictionary) -> UIColor {
		if let rawColor = self.value(forKeyPath: forKeyPath) as? String {
			if rawColor.contains("."), let genericRawColor = generic.value(forKeyPath: rawColor) as? String, let decodedHexColor = genericRawColor.colorFromHex {

				print("--->>> use generic path \(rawColor) \(genericRawColor) \(decodedHexColor)")

				return decodedHexColor
			} else if let decodedHexColor = rawColor.colorFromHex {
				return decodedHexColor
			}
		}
		return fallback
	}

	func resolveColor(_ forKeyPath: String, _ fallback : UIColor? = nil, _ generic: NSDictionary) -> UIColor? {
		if let rawColor = self.value(forKeyPath: forKeyPath) as? String {
			if rawColor.contains("."), let genericRawColor = generic.value(forKeyPath: rawColor) as? String, let decodedHexColor = genericRawColor.colorFromHex {
				return decodedHexColor
			} else if let decodedHexColor = rawColor.colorFromHex {
				if forKeyPath.hasPrefix("NavigationBar") {
				}
				return decodedHexColor
			}
		}
		return fallback
	}

	func resolveThemeColorPair(_ forKeyPath: String, _ colorPair : ThemeColorPair, _ generic: NSDictionary) -> ThemeColorPair {
		let pair = ThemeColorPair(foreground: self.resolveColor(forKeyPath.appending(".foreground"), colorPair.foreground, generic),
								  background: self.resolveColor(forKeyPath.appending(".background"), colorPair.background, generic))

		return pair
	}

	func resolveThemeColorCollection(_ forKeyPath: String, _ colorCollection : ThemeColorCollection, _ generic: NSDictionary) -> ThemeColorCollection {
		let collection = ThemeColorCollection(backgroundColor: self.resolveColor(forKeyPath.appending(".backgroundColor"), colorCollection.backgroundColor, generic),
											  tintColor: self.resolveColor(forKeyPath.appending(".tintColor"), colorCollection.tintColor, generic),
											  labelColor: self.resolveColor(forKeyPath.appending(".labelColor"), colorCollection.labelColor, generic),
											  secondaryLabelColor: self.resolveColor(forKeyPath.appending(".secondaryLabelColor"), colorCollection.secondaryLabelColor, generic),
											  symbolColor: self.resolveColor(forKeyPath.appending(".symbolColor"), colorCollection.symbolColor, generic),
											  filledColorPairCollection: self.resolveThemeColorPairCollection(forKeyPath.appending(".filledColorPairCollection"), colorCollection.filledColorPairCollection, generic))

		return collection
	}

	func resolveThemeColorPairCollection(_ forKeyPath: String, _ colorPairCollection : ThemeColorPairCollection, _ generic: NSDictionary) -> ThemeColorPairCollection {
		let newColorPairCollection = colorPairCollection

		newColorPairCollection.normal = self.resolveThemeColorPair(forKeyPath.appending(".normal"), colorPairCollection.normal, generic)
		newColorPairCollection.highlighted = self.resolveThemeColorPair(forKeyPath.appending(".highlighted"), colorPairCollection.highlighted, generic)
		newColorPairCollection.disabled = self.resolveThemeColorPair(forKeyPath.appending(".disabled"), colorPairCollection.disabled, generic)

		return newColorPairCollection
	}
}
