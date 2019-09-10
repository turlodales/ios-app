//
//  ClientQueryViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 05.04.18.
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
import ownCloudSDK
import MobileCoreServices

typealias ClientActionVieDidAppearHandler = () -> Void
typealias ClientActionCompletionHandler = (_ actionPerformed: Bool) -> Void

extension OCQueryState {
	var isFinal: Bool {
		switch self {
		case .idle, .targetRemoved, .contentsFromCache, .stopped:
			return true
		default:
			return false
		}
	}
}

class ClientQueryViewController: QueryFileListTableViewController, UIDropInteractionDelegate, UIPopoverPresentationControllerDelegate {
	var selectedItemIds = Set<OCLocalID>()

	var actions : [Action]?

	let flexibleSpaceBarButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
	var deleteMultipleBarButtonItem: UIBarButtonItem?
	var moveMultipleBarButtonItem: UIBarButtonItem?
	var duplicateMultipleBarButtonItem: UIBarButtonItem?
	var copyMultipleBarButtonItem: UIBarButtonItem?
	var openMultipleBarButtonItem: UIBarButtonItem?

	var selectBarButton: UIBarButtonItem?
	var plusBarButton: UIBarButtonItem?
	var selectDeselectAllButtonItem: UIBarButtonItem?
	var exitMultipleSelectionBarButtonItem: UIBarButtonItem?

	var quotaLabel = UILabel()
	var quotaObservation : NSKeyValueObservation?
	var titleButtonThemeApplierToken : ThemeApplierToken?

	private var _actionProgressHandler : ActionProgressHandler?

	// MARK: - Init & Deinit
	public override init(core inCore: OCCore, query inQuery: OCQuery) {
		super.init(core: inCore, query: inQuery)

		let lastPathComponent = (query.queryPath as NSString?)!.lastPathComponent

		if lastPathComponent.isRootPath, let shortName = core?.bookmark.shortName {
			self.navigationItem.title = shortName
		} else {
			let titleButton = UIButton()
			titleButton.setTitle(lastPathComponent, for: .normal)
			titleButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
			titleButton.addTarget(self, action: #selector(showPathBreadCrumb(_:)), for: .touchUpInside)
			titleButton.sizeToFit()
			titleButton.accessibilityLabel = "Show parent paths".localized
			titleButton.accessibilityIdentifier = "show-paths-button"
			titleButton.semanticContentAttribute = (titleButton.effectiveUserInterfaceLayoutDirection == .leftToRight) ? .forceRightToLeft : .forceLeftToRight
			titleButton.setImage(UIImage(named: "chevron-small-light"), for: .normal)
			titleButtonThemeApplierToken = Theme.shared.add(applier: { (_, collection, _) in
				titleButton.setTitleColor(collection.navigationBarColors.labelColor, for: .normal)
				titleButton.tintColor = collection.navigationBarColors.labelColor
			})
			self.navigationItem.titleView = titleButton
		}

		if lastPathComponent.isRootPath {
			quotaObservation = core?.observe(\OCCore.rootQuotaBytesUsed, options: [.initial], changeHandler: { [weak self, core] (_, _) in
				let quotaUsed = core?.rootQuotaBytesUsed?.int64Value ?? 0

				OnMainThread {
					var footerText: String?

					if quotaUsed > 0 {

						let byteCounterFormatter = ByteCountFormatter()
						byteCounterFormatter.allowsNonnumericFormatting = false

						let quotaUsedFormatted = byteCounterFormatter.string(fromByteCount: quotaUsed)

						// A rootQuotaBytesRemaining value of nil indicates that no quota has been set
						if core?.rootQuotaBytesRemaining != nil, let quotaTotal = core?.rootQuotaBytesTotal?.int64Value {
							let quotaTotalFormatted = byteCounterFormatter.string(fromByteCount: quotaTotal )
							footerText = String(format: "%@ of %@ used".localized, quotaUsedFormatted, quotaTotalFormatted)
						} else {
							footerText = String(format: "Total: %@".localized, quotaUsedFormatted)
						}
					}

					self?.updateFooter(text: footerText)
				}
			})
		}
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		queryStateObservation = nil
		quotaObservation = nil

		if titleButtonThemeApplierToken != nil {
			Theme.shared.remove(applierForToken: titleButtonThemeApplierToken)
			titleButtonThemeApplierToken = nil
		}
	}

	// MARK: - View controller events
	override func viewDidLoad() {
		super.viewDidLoad()

		self.tableView.dragDelegate = self
		self.tableView.dropDelegate = self
		self.tableView.dragInteractionEnabled = true
		self.tableView.allowsMultipleSelectionDuringEditing = true

		plusBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(plusBarButtonPressed))
		plusBarButton?.accessibilityIdentifier = "client.file-add"
		selectBarButton = UIBarButtonItem(title: "Select".localized, style: .done, target: self, action: #selector(multipleSelectionButtonPressed))
		selectBarButton?.isEnabled = false
    		selectBarButton?.accessibilityIdentifier = "select-button"
		self.navigationItem.rightBarButtonItems = [selectBarButton!, plusBarButton!]

		selectDeselectAllButtonItem = UIBarButtonItem(title: "Select All".localized, style: .done, target: self, action: #selector(selectAllItems))
		exitMultipleSelectionBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(exitMultipleSelection))

		// Create bar button items for the toolbar
		deleteMultipleBarButtonItem = UIBarButtonItem(image: UIImage(named:"trash"), target: self as AnyObject, action: #selector(actOnMultipleItems), dropTarget: self, actionIdentifier: DeleteAction.identifier!)
		deleteMultipleBarButtonItem?.isEnabled = false

		moveMultipleBarButtonItem = UIBarButtonItem(image: UIImage(named:"folder"), target: self as AnyObject, action: #selector(actOnMultipleItems), dropTarget: self, actionIdentifier: MoveAction.identifier!)
		moveMultipleBarButtonItem?.isEnabled = false

		duplicateMultipleBarButtonItem = UIBarButtonItem(image: UIImage(named: "duplicate-file"), target: self as AnyObject, action: #selector(actOnMultipleItems), dropTarget: self, actionIdentifier: DuplicateAction.identifier!)
		duplicateMultipleBarButtonItem?.isEnabled = false

		copyMultipleBarButtonItem = UIBarButtonItem(image: UIImage(named: "copy-file"), target: self as AnyObject, action: #selector(actOnMultipleItems), dropTarget: self, actionIdentifier: CopyAction.identifier!)
		copyMultipleBarButtonItem?.isEnabled = false

		openMultipleBarButtonItem = UIBarButtonItem(image: UIImage(named: "open-in"), target: self as AnyObject, action: #selector(actOnMultipleItems), dropTarget: self, actionIdentifier: OpenInAction.identifier!)
		openMultipleBarButtonItem?.isEnabled = false

		quotaLabel.textAlignment = .center
		quotaLabel.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
		quotaLabel.numberOfLines = 0
	}

	private var viewControllerVisible : Bool = false

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		leaveMultipleSelection()
	}

	private func updateFooter(text:String?) {
		let labelText = text ?? ""

		// Resize quota label
		self.quotaLabel.text = labelText
		self.quotaLabel.sizeToFit()
		var frame = self.quotaLabel.frame
		// Width is ignored and set by the UITableView when assigning to tableFooterView property
		frame.size.height = floor(self.quotaLabel.frame.size.height * 2.0)
		quotaLabel.frame = frame
		self.tableView.tableFooterView = quotaLabel
	}

	// MARK: - Theme support
	override func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		super.applyThemeCollection(theme: theme, collection: collection, event: event)

		self.quotaLabel.textColor = collection.tableRowColors.secondaryLabelColor
	}

	// MARK: - Table view delegate
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		// If not in multiple-selection mode, just navigate to the file or folder (collection)
		if !self.tableView.isEditing {
			super.tableView(tableView, didSelectRowAt: indexPath)
		} else {
			updateMultiSelectionUI()
		}
	}

	override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		if tableView.isEditing {
			updateMultiSelectionUI()
		}
	}

	override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		return true
	}

	func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
		for item in session.items {
			if item.localObject == nil, item.itemProvider.hasItemConformingToTypeIdentifier("public.folder") {
				return false
			}
		}
		return true
	}

 	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let core = self.core, let item : OCItem = itemAt(indexPath: indexPath) else {
			return nil
		}

		let actionsLocation = OCExtensionLocation(ofType: .action, identifier: .tableRow)
		let actionContext = ActionContext(viewController: self, core: core, items: [item], location: actionsLocation)
		let actions = Action.sortedApplicableActions(for: actionContext)
		actions.forEach({
			$0.progressHandler = makeActionProgressHandler()
		})

		let contextualActions = actions.compactMap({$0.provideContextualAction()})
		let configuration = UISwipeActionsConfiguration(actions: contextualActions)
		return configuration
	}

	func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {

		if session.localDragSession != nil {
				if let indexPath = destinationIndexPath, items.count - 1 < indexPath.row {
					return UITableViewDropProposal(operation: .forbidden)
				}

				if let indexPath = destinationIndexPath, items[indexPath.row].type == .file {
					return UITableViewDropProposal(operation: .move)
				} else {
					return UITableViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
				}
		} else {
			return UITableViewDropProposal(operation: .copy)
		}
	}

	func updateToolbarItemsForDropping(_ items: [OCItem]) {
		guard let tabBarController = self.tabBarController as? ClientRootViewController else { return }
		guard let toolbarItems = tabBarController.toolbar?.items else { return }

		if let core = self.core {
			// Remove duplicates
			let uniqueItems = Array(Set(items))
			// Get possible associated actions
			let actionsLocation = OCExtensionLocation(ofType: .action, identifier: .toolbar)
			let actionContext = ActionContext(viewController: self, core: core, query: query, items: uniqueItems, location: actionsLocation)
			self.actions = Action.sortedApplicableActions(for: actionContext)

			// Enable / disable tool-bar items depending on action availability
			for item in toolbarItems {
				if self.actions?.contains(where: {type(of:$0).identifier == item.actionIdentifier}) ?? false {
					item.isEnabled = true
				} else {
					item.isEnabled = false
				}
			}
		}

	}

	func tableView(_: UITableView, dragSessionDidEnd: UIDragSession) {
		if !self.tableView.isEditing {
			removeToolbar()
		}
	}

	// MARK: - UIBarButtonItem Drop Delegate

	func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
		return true
	}

	func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
		return UIDropProposal(operation: .copy)
	}

	func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
		guard let button = interaction.view as? UIButton, let identifier = button.actionIdentifier  else { return }

		if let action = self.actions?.first(where: {type(of:$0).identifier == identifier}) {
			// Configure progress handler
			action.progressHandler = makeActionProgressHandler()

			action.completionHandler = { (_, _) in
			}

			// Execute the action
			action.perform()
		}
	}

	func dragInteraction(_ interaction: UIDragInteraction,
						 session: UIDragSession,
						 didEndWith operation: UIDropOperation) {
		removeToolbar()
	}

	// MARK: - Upload
	func upload(itemURL: URL, name: String, completionHandler: ClientActionCompletionHandler? = nil) {
		if let rootItem = query.rootItem,
		   let progress = core?.importFileNamed(name, at: rootItem, from: itemURL, isSecurityScoped: false, options: nil, placeholderCompletionHandler: nil, resultHandler: { (error, _ core, _ item, _) in
			if error != nil {
				Log.debug("Error uploading \(Log.mask(name)) file to \(Log.mask(rootItem.path))")
				completionHandler?(false)
			} else {
				Log.debug("Success uploading \(Log.mask(name)) file to \(Log.mask(rootItem.path))")
				completionHandler?(true)
			}
		}) {
			self.progressSummarizer?.startTracking(progress: progress)
		}
	}

	// MARK: - Toolbar actions handling multiple selected items
	fileprivate func updateSelectDeselectAllButton() {
		var selectedCount = 0
		if let selectedIndexPaths = self.tableView.indexPathsForSelectedRows {
			selectedCount = selectedIndexPaths.count
		}

		if selectedCount == self.items.count {
			selectDeselectAllButtonItem?.title = "Deselect All".localized
			selectDeselectAllButtonItem?.target = self
			selectDeselectAllButtonItem?.action = #selector(deselectAllItems)
		} else {
			selectDeselectAllButtonItem?.title = "Select All".localized
			selectDeselectAllButtonItem?.target = self
			selectDeselectAllButtonItem?.action = #selector(selectAllItems)
		}
	}

	fileprivate func updateActions(for selectedItems:[OCItem]) {
		guard let tabBarController = self.tabBarController as? ClientRootViewController else { return }

		guard let toolbarItems = tabBarController.toolbar?.items else { return }

		if selectedItems.count > 0 {
			if let core = self.core {
				// Get possible associated actions
				let actionsLocation = OCExtensionLocation(ofType: .action, identifier: .toolbar)
				let actionContext = ActionContext(viewController: self, core: core, query: query, items: selectedItems, location: actionsLocation)

				self.actions = Action.sortedApplicableActions(for: actionContext)

				// Enable / disable tool-bar items depending on action availability
				for item in toolbarItems {
					if self.actions?.contains(where: {type(of:$0).identifier == item.actionIdentifier}) ?? false {
						item.isEnabled = true
					} else {
						item.isEnabled = false
					}
				}
			}

		} else {
			self.actions = nil
			for item in toolbarItems {
				item.isEnabled = false
			}
		}

	}

	fileprivate func updateMultiSelectionUI() {

		updateSelectDeselectAllButton()

		var selectedItems = [OCItem]()

		// Do we have selected items?
		if let selectedIndexPaths = self.tableView.indexPathsForSelectedRows {
			if selectedIndexPaths.count > 0 {

				// Get array of OCItems from selected table view index paths
				selectedItemIds.removeAll()
				for indexPath in selectedIndexPaths {
					if let item = itemAt(indexPath: indexPath) {
						selectedItems.append(item)

						if let localID = item.localID as OCLocalID? {
							selectedItemIds.insert(localID)
						}
					}
				}
			}
		}

		updateActions(for: selectedItems)
	}

	func leaveMultipleSelection() {
		self.tableView.setEditing(false, animated: true)
		selectBarButton?.title = "Select".localized
		self.navigationItem.rightBarButtonItems = [selectBarButton!, plusBarButton!]
		self.navigationItem.leftBarButtonItem = nil
		selectedItemIds.removeAll()
		removeToolbar()
	}

	func populateToolbar() {
		self.populateToolbar(with: [
			openMultipleBarButtonItem!,
			flexibleSpaceBarButton,
			moveMultipleBarButtonItem!,
			flexibleSpaceBarButton,
			copyMultipleBarButtonItem!,
			flexibleSpaceBarButton,
			duplicateMultipleBarButtonItem!,
			flexibleSpaceBarButton,
			deleteMultipleBarButtonItem!])
	}

	@objc func actOnMultipleItems(_ sender: UIButton) {
		// Find associated action
		if let action = self.actions?.first(where: {type(of:$0).identifier == sender.actionIdentifier}) {
			// Configure progress handler
			action.progressHandler = makeActionProgressHandler()

			action.completionHandler = { [weak self] (_, _) in
				OnMainThread {
					self?.leaveMultipleSelection()
				}
			}

			// Execute the action
			action.perform()
		}
	}

	// MARK: - Navigation Bar Actions
	@objc func multipleSelectionButtonPressed(_ sender: UIBarButtonItem) {

		if !self.tableView.isEditing {
			updateMultiSelectionUI()
			self.tableView.setEditing(true, animated: true)

			populateToolbar()

			self.navigationItem.leftBarButtonItem = selectDeselectAllButtonItem!
			self.navigationItem.rightBarButtonItems = [exitMultipleSelectionBarButtonItem!]

			updateMultiSelectionUI()
		}
	}

	@objc func exitMultipleSelection(_ sender: UIBarButtonItem) {
		leaveMultipleSelection()
	}

	@objc func selectAllItems(_ sender: UIBarButtonItem) {
		(0..<self.items.count).map { (item) -> IndexPath in
			return IndexPath(item: item, section: 0)
			}.forEach { (indexPath) in
				self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
		}
		updateMultiSelectionUI()
	}

	@objc func deselectAllItems(_ sender: UIBarButtonItem) {

		self.tableView.indexPathsForSelectedRows?.forEach({ (indexPath) in
			self.tableView.deselectRow(at: indexPath, animated: true)
		})
		updateMultiSelectionUI()
	}

	@objc func plusBarButtonPressed(_ sender: UIBarButtonItem) {

		let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

		// Actions for plusButton
		if let core = self.core, let rootItem = query.rootItem {
			let actionsLocation = OCExtensionLocation(ofType: .action, identifier: .plusButton)
			let actionContext = ActionContext(viewController: self, core: core, items: [rootItem], location: actionsLocation)

			let actions = Action.sortedApplicableActions(for: actionContext)

			for action in actions {
				action.progressHandler = makeActionProgressHandler()

				if let controllerAction = action.provideAlertAction() {
					controller.addAction(controllerAction)
				}
			}
		}

		// Cancel button
		let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)
		controller.addAction(cancelAction)

		if let popoverController = controller.popoverPresentationController {
			popoverController.barButtonItem = sender
		}
		self.present(controller, animated: true)
	}

	// MARK: - Path Bread Crumb Action
	@objc func showPathBreadCrumb(_ sender: UIButton) {
		let tableViewController = BreadCrumbTableViewController()
		tableViewController.modalPresentationStyle = UIModalPresentationStyle.popover
		tableViewController.parentNavigationController = self.navigationController
		tableViewController.queryPath = (query.queryPath as NSString?)!
		if let shortName = core?.bookmark.shortName {
			tableViewController.bookmarkShortName = shortName
		}

		let popoverPresentationController = tableViewController.popoverPresentationController
		popoverPresentationController?.sourceView = sender
		popoverPresentationController?.delegate = self
		popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: sender.frame.size.width, height: sender.frame.size.height)

		present(tableViewController, animated: true, completion: nil)
	}

	// MARK: - ClientItemCell item resolution
	override func item(for cell: ClientItemCell) -> OCItem? {
		guard let indexPath = self.tableView.indexPath(for: cell) else {
			return nil
		}

		return self.itemAt(indexPath: indexPath)
	}

	// MARK: - Updates
	override func performUpdatesWithQueryChanges(query: OCQuery, changeSet: OCQueryChangeSet?) {
		switch query.state {
			case .contentsFromCache, .idle, .waitingForServerReply:
				self.selectBarButton?.isEnabled = (self.items.count == 0) ? false : true

			default: break
		}

		if let rootItem = self.query.rootItem {
			if query.queryPath != "/" {
				let totalSize = String(format: "Total: %@".localized, rootItem.sizeLocalized)
				self.updateFooter(text: totalSize)
			}
		}
	}

	// MARK: - Reloads
	override func restoreSelectionAfterTableReload() {
		// Restore previously selected items
		if tableView.isEditing && selectedItemIds.count > 0 {
			var selectedItems = [OCItem]()
			for row in 0..<self.items.count {
				if let itemLocalID = self.items[row].localID as OCLocalID? {
					if selectedItemIds.contains(itemLocalID) {
						selectedItems.append(self.items[row])
						self.tableView.selectRow(at: IndexPath(row: row, section: 0), animated: false, scrollPosition: .none)
					}
				}
			}
		}
	}

	// MARK: - UIPopoverPresentationControllerDelegate
	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}
}

// MARK: - Drag & Drop delegates
extension ClientQueryViewController: UITableViewDropDelegate {
	func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
		guard let core = self.core else { return }

		for item in coordinator.items {
			if item.dragItem.localObject != nil {
				var destinationItem: OCItem

				guard let item = item.dragItem.localObject as? OCItem, let itemName = item.name else {
					return
				}

				if coordinator.proposal.intent == .insertIntoDestinationIndexPath {

					guard let destinationIndexPath = coordinator.destinationIndexPath else {
						return
					}

					guard items.count >= destinationIndexPath.row else {
						return
					}

					let rootItem = items[destinationIndexPath.row]

					guard rootItem.type == .collection else {
						return
					}

					destinationItem = rootItem

				} else {

					guard let rootItem = self.query.rootItem, item.parentFileID != rootItem.fileID else {
						return
					}

					destinationItem =  rootItem

				}

				if let progress = core.move(item, to: destinationItem, withName: itemName, options: nil, resultHandler: { (error, _, _, _) in
					if error != nil {
						Log.log("Error \(String(describing: error)) moving \(String(describing: item.path))")
					}
				}) {
					self.progressSummarizer?.startTracking(progress: progress)
				}
			} else {
				guard let UTI = item.dragItem.itemProvider.registeredTypeIdentifiers.last else { return }
				item.dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: UTI) { (url, _ error) in
					guard let url = url else { return }
					self.upload(itemURL: url, name: url.lastPathComponent)
				}
			}
		}
	}
}

extension ClientQueryViewController: UITableViewDragDelegate {

	func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {

		if !self.tableView.isEditing {
			self.populateToolbar()
		}

		var selectedItems = [OCItem]()
		// Add Items from Multiselection too
		if let selectedIndexPaths = self.tableView.indexPathsForSelectedRows {
			if selectedIndexPaths.count > 0 {
				for indexPath in selectedIndexPaths {
					if let selectedItem : OCItem = itemAt(indexPath: indexPath) {
						selectedItems.append(selectedItem)
					}
				}
			}
		}
		for dragItem in session.items {
			guard let item = dragItem.localObject as? OCItem else { continue }
			selectedItems.append(item)
		}

		if let item: OCItem = itemAt(indexPath: indexPath) {
			selectedItems.append(item)

			updateToolbarItemsForDropping(selectedItems)

			guard let dragItem = itemForDragging(item: item) else { return [] }
			return [dragItem]
		}

		return []
	}

	func tableView(_ tableView: UITableView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
		var selectedItems = [OCItem]()
		for dragItem in session.items {
			guard let item = dragItem.localObject as? OCItem else { continue }
			selectedItems.append(item)
		}

		if let item: OCItem = itemAt(indexPath: indexPath) {
			selectedItems.append(item)

			updateToolbarItemsForDropping(selectedItems)

			guard let dragItem = itemForDragging(item: item) else { return [] }
			return [dragItem]
		}

		return []
	}

	func itemForDragging(item : OCItem) -> UIDragItem? {
		if let core = self.core {
			switch item.type {
			case .collection:
				guard let data = item.serializedData() else { return nil }
				let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: kUTTypeData as String)
				let dragItem = UIDragItem(itemProvider: itemProvider)
				dragItem.localObject = item
				return dragItem
			case .file:
				guard let itemMimeType = item.mimeType else { return nil }
				let mimeTypeCF = itemMimeType as CFString

				guard let rawUti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeTypeCF, nil)?.takeRetainedValue() else { return nil }

				if let fileData = NSData(contentsOf: core.localURL(for: item)) {
					let rawUtiString = rawUti as String
					let itemProvider = NSItemProvider(item: fileData, typeIdentifier: rawUtiString)
					itemProvider.suggestedName = item.name
					let dragItem = UIDragItem(itemProvider: itemProvider)
					dragItem.localObject = item
					return dragItem
				} else {
					guard let data = item.serializedData() else { return nil }
					let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: kUTTypeData as String)
					let dragItem = UIDragItem(itemProvider: itemProvider)
					dragItem.localObject = item
					return dragItem
				}
			}
		}

		return nil
	}
}

// MARK: - UINavigationControllerDelegate
extension ClientQueryViewController: UINavigationControllerDelegate {}
