//
//  UploadFileAction.swift
//  ownCloud
//
//  Created by Felix Schwarz on 09.04.19.
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
import CoreServices
import UniformTypeIdentifiers

class UploadFileAction: UploadBaseAction {
	override class var identifier : OCExtensionIdentifier? { return OCExtensionIdentifier("com.owncloud.action.uploadfile") }
	override class var category : ActionCategory? { return .normal }
	override class var name : String { return OCLocalizedString("Upload file", nil) }
	override class var locations : [OCExtensionLocationIdentifier]? { return [.folderAction, .keyboardShortcut, .emptyFolder] }
	override class var keyCommand : String? { return "+" }
	override class var keyModifierFlags: UIKeyModifierFlags? { return [.command] }

	private static let associatedKeyAction = malloc(1)!

	// MARK: - Action implementation
	override func run() {
		guard context.items.count == 1, context.items.first?.type == .collection, let viewController = context.viewController else {
			self.completed(with: NSError(ocError: .insufficientParameters))
			return
		}

		let documentPickerViewController = UIDocumentPickerViewController(documentTypes: [UTType.data.identifier], in: .import)

		documentPickerViewController.delegate = self
		documentPickerViewController.allowsMultipleSelection = true

		// The action is only held weakly as delegate. This makes sure the Action object sticks around as long as UIDocumentPickerViewController, so that UIDocumentPickerViewController can call the UIDocumentPickerDelegate method.
		objc_setAssociatedObject(documentPickerViewController, UploadFileAction.associatedKeyAction, self, .OBJC_ASSOCIATION_RETAIN)

		viewController.present(documentPickerViewController, animated: true)
	}

	override class func iconForLocation(_ location: OCExtensionLocationIdentifier) -> UIImage? {
		Theme.shared.add(tvgResourceFor: "text")
		return Theme.shared.image(for: "text", size: CGSize(width: 30.0, height: 30.0))!.withRenderingMode(.alwaysTemplate)
	}
}

// MARK: - UIDocumentPickerDelegate
extension UploadFileAction : UIDocumentPickerDelegate {
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		if let rootItem = context.items.first {
			for url in urls {
				if !self.upload(itemURL: url, to: rootItem, name: url.lastPathComponent) {
					self.completed(with: NSError(ocError: .internal))
					return
				}
			}
		}

		self.completed()
	}
}
