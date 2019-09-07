//
//  NSObject+ThemeApplication.swift
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

enum ThemeItemStyle {
	case defaultForItem

	case success
	case informal
	case warning
	case error

	case approval
	case neutral
	case destructive

	case logo
	case title
	case message

	case bigTitle
	case bigMessage
}

enum ThemeItemState {
	case normal
	case highlighted
	case disabled

	init(selected: Bool) {
		if selected {
			self = .highlighted
		} else {
			self = .normal
		}
	}
}

extension NSObject {
	func applyThemeCollection(_ collection: ThemeCollection, itemStyle: ThemeItemStyle = .defaultForItem, itemState: ThemeItemState = .normal) {
		if let themeButton = self as? ThemeButton {
			switch itemStyle {
				case .approval:
					themeButton.themeColorCollection = collection.approvalColors

				case .neutral:
					themeButton.themeColorCollection = collection.neutralColors

				case .destructive:
					themeButton.themeColorCollection = collection.destructiveColors

				case .bigTitle:
					themeButton.themeColorCollection = collection.neutralColors
					themeButton.titleLabel?.font = UIFont.systemFont(ofSize: 34)

				default:
					themeButton.themeColorCollection = collection.lightBrandColors.filledColorPairCollection
			}
		} else if let button = self as? UIButton {
			button.tintColor = collection.navigationBarColors.tintColor
		}

		if let navigationController = self as? UINavigationController {
			navigationController.navigationBar.applyThemeCollection(collection, itemStyle: itemStyle)
			//navigationController.view.backgroundColor = collection.tableBackgroundColor
		}

		if let navigationBar = self as? UINavigationBar {
			navigationBar.barTintColor = collection.navigationBarColors.backgroundColor
			navigationBar.backgroundColor = collection.navigationBarColors.backgroundColor
			navigationBar.tintColor = collection.navigationBarColors.tintColor
			navigationBar.titleTextAttributes = [ .foregroundColor :  collection.navigationBarColors.labelColor ]
			navigationBar.largeTitleTextAttributes = [ .foregroundColor :  collection.navigationBarColors.labelColor ]
			navigationBar.isTranslucent = false
		}

		if let toolbar = self as? UIToolbar {
			toolbar.barTintColor = collection.toolbarColors.backgroundColor
			toolbar.tintColor = collection.toolbarColors.tintColor
		}

		if let tabBar = self as? UITabBar {
			tabBar.barTintColor = collection.toolbarColors.backgroundColor
			tabBar.tintColor =  collection.toolbarColors.filledColorPairCollection.normal.foreground
			tabBar.unselectedItemTintColor = collection.toolbarColors.filledColorPairCollection.disabled.foreground
		}

		if let tableView = self as? UITableView {
			tableView.backgroundColor = collection.tableBackgroundColor
			tableView.separatorColor = collection.tableSeparatorColor
		}

		if let collectionView = self as? UICollectionView {

			collectionView.backgroundColor = collection.tableBackgroundColor
		}

		if let searchBar = self as? UISearchBar {
			searchBar.tintColor = collection.searchbarColors.tintColor
			searchBar.searchTextField.backgroundColor = collection.searchbarColors.backgroundColor
			searchBar.searchTextField.textColor = collection.searchbarColors.labelColor
			searchBar.searchTextField.tintColor = collection.searchbarColors.tintColor
			if let glassIconView = searchBar.searchTextField.leftView as? UIImageView {
				glassIconView.image?.withRenderingMode(.alwaysTemplate)
				glassIconView.tintColor = collection.searchbarColors.tintColor
			}
			searchBar.barStyle = collection.barStyle
		}

		if let label = self as? UILabel {
			var normalColor : UIColor = collection.tableRowColors.labelColor
			var highlightColor : UIColor = collection.tableRowHighlightColors.labelColor
			let disabledColor : UIColor = collection.tableRowColors.secondaryLabelColor

			switch itemStyle {
				case .title, .bigTitle:
					normalColor = collection.tableRowColors.labelColor
					highlightColor = collection.tableRowHighlightColors.labelColor

				case .message, .bigMessage:
					normalColor = collection.tableRowColors.secondaryLabelColor
					highlightColor = collection.tableRowHighlightColors.secondaryLabelColor

				default:
					normalColor = collection.tableRowColors.labelColor
					highlightColor = collection.tableRowHighlightColors.labelColor
			}

			switch itemStyle {
				case .bigTitle:
					label.font = UIFont.boldSystemFont(ofSize: 34)

				case .bigMessage:
					label.font = UIFont.systemFont(ofSize: 17)

				default:
				break
			}

			switch itemState {
				case .normal:
					label.textColor = normalColor

				case .highlighted:
					label.textColor = highlightColor

				case .disabled:
					label.textColor = disabledColor
			}
		}

		if let textField = self as? UITextField {
			textField.textColor = collection.tableRowColors.labelColor
		}

		if let cell = self as? UITableViewCell {
			cell.backgroundColor = collection.tableRowColors.backgroundColor

			if cell.selectionStyle != .none {
				if collection.tableRowHighlightColors.backgroundColor != nil {
					let backgroundView = UIView()

					backgroundView.backgroundColor = collection.tableRowHighlightColors.backgroundColor

					cell.selectedBackgroundView = backgroundView
				} else {
					cell.selectedBackgroundView = nil
				}
			}
		}

		if let progressView = self as? UIProgressView {
			progressView.tintColor = collection.tintColor
			progressView.trackTintColor = collection.tableSeparatorColor
		}

		if let segmentedControl = self as? UISegmentedControl {
			segmentedControl.tintColor = collection.navigationBarColors.tintColor
		}
	}
}
