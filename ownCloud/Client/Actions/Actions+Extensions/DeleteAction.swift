//
//  DeleteAction.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 12/11/2018.
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

import ownCloudSDK
import ownCloudAppShared

class DeleteAction : Action {
	override class var identifier : OCExtensionIdentifier? { return OCExtensionIdentifier("com.owncloud.action.delete") }
	override class var category : ActionCategory? { return .destructive }
	override class var name : String? { return OCLocalizedString("Delete", nil) }
	override class var locations : [OCExtensionLocationIdentifier]? { return [.moreItem, .moreDetailItem, .tableRow, .moreFolder, .multiSelection, .dropAction, .keyboardShortcut, .contextMenuItem] }
	override class var keyCommand : String? { return "\u{08}" }
	override class var keyModifierFlags: UIKeyModifierFlags? { return [.command] }

	// MARK: - Extension matching
	override class func applicablePosition(forContext: ActionContext) -> ActionPosition {

		if forContext.containsRoot || !forContext.allItemsDeleteable {
			return .none
		}

		if forContext.containsShareRoot {
			return .none
		}

		return .last
	}

	// MARK: - Action implementation
	override func run() {
		guard context.items.count > 0, let viewController = context.viewController else {
			self.completed(with: NSError(ocError: .insufficientParameters))
			return
		}

		let items = context.items

		let message: String
		if items.count > 1 {
			message = OCLocalizedString("Are you sure you want to delete these items from the server?", nil)
		} else {
			message = OCLocalizedString("Are you sure you want to delete this item from the server?", nil)
		}

		let itemDescripton: String?
		if items.count > 1 {
			itemDescripton = OCLocalizedString("Multiple items", nil)
		} else {
			itemDescripton = items.first?.name?.redacted()
		}

		guard let name = itemDescripton else {
			self.completed(with: NSError(ocError: .insufficientParameters))
			return
		}

		let deleteItemAndPublishProgress = { (items: [OCItem]) in
			for item in items {
				if let progress = self.core?.delete(item, requireMatch: true, resultHandler: { (error, _, _, _) in
					if error != nil {
						Log.log("Error \(String(describing: error)) deleting \(String(describing: item.path))")
					}
				}) {
					self.publish(progress: progress)
				}
			}

			self.completed()
		}

		let alertController = ThemedAlertController(
			with: name,
			message: message,
			destructiveLabel: OCLocalizedString("Delete", nil),
			preferredStyle: UIDevice.current.isIpad ? UIAlertController.Style.alert : UIAlertController.Style.actionSheet,
			destructiveAction: {
				deleteItemAndPublishProgress(items)
		})

		viewController.present(alertController, animated: true)

	}

	override class func iconForLocation(_ location: OCExtensionLocationIdentifier) -> UIImage? {
		return UIImage(named: "trash")?.withRenderingMode(.alwaysTemplate)
	}
}
