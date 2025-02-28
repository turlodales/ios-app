//
//  ThemeWindow.swift
//  ownCloud
//
//  Created by Felix Schwarz on 28.08.19.
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

public class ThemeWindow : UIWindow {
	// MARK: - Theme window list
	static let themeWindowListChangedNotification: NSNotification.Name = NSNotification.Name(rawValue: "ThemeWindowListChanged")
	static private let _themeWindows : NSHashTable<ThemeWindow> = NSHashTable<ThemeWindow>.weakObjects()

	public var themeWindowInForeground : Bool = false

	private static func addThemeWindow(_ window: ThemeWindow) {
		OCSynchronized(self) {
			_themeWindows.add(window)
		}
		NotificationCenter.default.post(name: ThemeWindow.themeWindowListChangedNotification, object: nil, userInfo: nil)
	}

	private static func removeThemeWindow(_ window: ThemeWindow) {
		OCSynchronized(self) {
			_themeWindows.remove(window)
		}
		NotificationCenter.default.post(name: ThemeWindow.themeWindowListChangedNotification, object: nil, userInfo: nil)
	}

	static var themeWindows : [ThemeWindow] {
		var themeWindows : [ThemeWindow] = []

		OCSynchronized(self) {
			themeWindows = _themeWindows.allObjects
		}

		return themeWindows
	}

	static var frontmostThemeWindow : ThemeWindow? {
		var themeWindow : ThemeWindow?

		OCSynchronized(self) {
			let themeWindows = _themeWindows.allObjects

			for checkWindow in themeWindows {
				if checkWindow.themeWindowInForeground {
					themeWindow = checkWindow
				}
			}
		}

		return themeWindow
	}

	// MARK: - Lifecycle
	override public init(frame: CGRect) {
		super.init(frame: frame)

		ThemeWindow.addThemeWindow(self)
	}

	override public init(windowScene: UIWindowScene) {
		super.init(windowScene: windowScene)

		ThemeWindow.addThemeWindow(self)
	}

	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		ThemeWindow.removeThemeWindow(self)
	}

	// MARK: - Theme change detection
	public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)

		if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
			ThemeStyle.considerAppearanceUpdate()
		}
	}
}
