//
//  OCDataItem+InteractionProtocols.swift
//  ownCloudAppShared
//
//  Created by Felix Schwarz on 30.05.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit
import ownCloudSDK

// MARK: - Selection
@objc public protocol DataItemSelectionInteraction: OCDataItem {
	// Allow selection
	@objc optional func allowSelection(in viewController: UIViewController?, section: CollectionViewSection?, with context: ClientContext?) -> Bool

	// Handle selection: suitable for f.ex. actions
	@objc optional func handleSelection(in viewController: UIViewController?, with context: ClientContext?, completion: ((_ success: Bool, _ performItemDeselection: Bool) -> Void)?) -> Bool

	// "Open" the item: suitable when pushing view controllers that should be restorable
	@objc optional func openItem(from viewController: UIViewController?, with context: ClientContext?, animated: Bool, pushViewController: Bool, completion: ((_ success: Bool) -> Void)?) -> UIViewController?

	// "Reveal" the item
	@objc @discardableResult optional func revealItem(from viewController: UIViewController?, with context: ClientContext?, animated: Bool, pushViewController: Bool, completion: ((_ success: Bool) -> Void)?) -> UIViewController?
}

// MARK: - Swipe Actions
@objc public protocol DataItemSwipeInteraction: OCDataItem {
	@objc optional func provideLeadingSwipeActions(with context: ClientContext?) -> UISwipeActionsConfiguration?
	@objc optional func provideTrailingSwipeActions(with context: ClientContext?) -> UISwipeActionsConfiguration?
}

// MARK: - Context menu
@objc public protocol DataItemContextMenuInteraction: OCDataItem {
	func composeContextMenuItems(in viewController: UIViewController?, location: OCExtensionLocationIdentifier, with context: ClientContext?) -> [UIMenuElement]?
}

// MARK: - Drag & drop
public struct LocalDataItem {
	public var bookmarkUUID : UUID
	public var dataItem: OCDataItem
}

@objc public protocol DataItemDragInteraction: OCDataItem {
	func provideDragItems(with context: ClientContext?) -> [UIDragItem]?
}

@objc public protocol DataItemDropInteraction: OCDataItem {
	@objc optional func allowDropOperation(for session: UIDropSession, with context: ClientContext?) -> UICollectionViewDropProposal?
	func performDropOperation(of items: [UIDragItem], with context: ClientContext?, handlingCompletion: @escaping (_ didSucceed: Bool) -> Void)
}

// MARK: - BrowserNavigationBookmark restoration
@objc public protocol DataItemBrowserNavigationBookmarkReStore: OCDataItem {
	func store(in bookmarkUUID: UUID?, context: ClientContext?, restoreAction: BrowserNavigationBookmark.BookmarkRestoreAction) -> BrowserNavigationBookmark?
	static func restore(navigationBookmark: BrowserNavigationBookmark, in viewController: UIViewController?, with context:ClientContext?, completion: @escaping ((_ error: Error?, _ viewController: UIViewController?) -> Void))
}
