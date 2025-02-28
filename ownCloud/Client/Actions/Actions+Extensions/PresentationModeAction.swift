//
//  PresentationModeAction.swift
//  ownCloud
//
//  Created by Matthias Hühne on 12.02.21.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
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

class PresentationModeAction: Action {
	override class var identifier : OCExtensionIdentifier? { return OCExtensionIdentifier("com.owncloud.action.presentationmode") }
	override class var category : ActionCategory? { return .normal }
	override class var name : String? { return OCLocalizedString("Presentation Mode", nil) }
	override class var locations : [OCExtensionLocationIdentifier]? { return [.moreDetailItem, .keyboardShortcut] }
	override class var keyCommand : String? { return "P" }
	override class var keyModifierFlags: UIKeyModifierFlags? { return [.command, .alternate] }

	static let reason : DisplaySleepPreventer.Reason = "presentation-mode"

	// MARK: - Extension matching
	override class func applicablePosition(forContext context: ActionContext) -> ActionPosition {
		if context.items.first?.cloudStatus == .cloudOnly {
			return .none
//		} else if let hostViewController = context.viewController, type(of: hostViewController) === ClientQueryViewController.self {
//			return .none
		} else if let hostViewController = context.viewController, (hostViewController.navigationController?.isNavigationBarHidden ?? false) {
			return .none
		}

		return .middle
	}

	// MARK: - Action implementation
	override func run() {
		guard context.items.count > 0, let hostViewController = context.viewController as? DisplayViewController else {
			completed(with: NSError(ocError: .insufficientParameters))
			return
		}

		if !DisplaySleepPreventer.shared.isPreventing(for: PresentationModeAction.reason) {
			let alertController = ThemedAlertController(title: OCLocalizedString("Presentation Mode", nil), message: OCLocalizedString("Enabling presentation mode will prevent the display from sleep mode until the view is closed.", nil), preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: OCLocalizedString("Cancel", nil), style: .cancel, handler: nil))
			alertController.addAction(UIAlertAction(title: OCLocalizedString("Enable", nil), style: .default, handler: { (_) in
				DisplaySleepPreventer.shared.startPreventingDisplaySleep(for: PresentationModeAction.reason)

				guard let navigationController = hostViewController.navigationController else {
					return
				}

				if hostViewController.supportsFullScreenMode, !navigationController.isNavigationBarHidden {
					navigationController.setNavigationBarHidden(true, animated: true)
					hostViewController.isFullScreenModeEnabled = true
				}
			}))
			hostViewController.present(alertController, animated: true)
		} else {
			guard let navigationController = hostViewController.navigationController else {
				return
			}

			if hostViewController.supportsFullScreenMode, !navigationController.isNavigationBarHidden {
				navigationController.setNavigationBarHidden(true, animated: true)
				hostViewController.isFullScreenModeEnabled = true
			}
		}

		self.completed()
	}

	override class func iconForLocation(_ location: OCExtensionLocationIdentifier) -> UIImage? {
		return UIImage(systemName: "tv")?.withRenderingMode(.alwaysTemplate)
	}
}
