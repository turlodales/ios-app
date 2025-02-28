//
//  StaticTableViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 08.03.18.
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

public enum StaticTableViewEvent {
	case initial
	case appBecameActive
	case tableViewWillAppear
	case tableViewWillDisappear
	case tableViewDidDisappear
}

open class StaticTableViewController: UITableViewController, Themeable {
	public var sections : [StaticTableViewSection] = Array()

	public var needsLiveUpdates : Bool {
		return (self.view.window != nil) || hasBeenPresentedAtLeastOnce
	}

	private var hasBeenPresentedAtLeastOnce : Bool = false

	// MARK: - Section administration
	open func addSection(_ section: StaticTableViewSection, animated animateThis: Bool = false) {
		self.insertSection(section, at: sections.count, animated: animateThis)
	}

	open func insertSection(_ section: StaticTableViewSection, at index: Int, animated: Bool = false) {
		section.viewController = self

		if animated {
			tableView.performBatchUpdates({
				sections.insert(section, at: index)
				tableView.insertSections(IndexSet(integer: index), with: .fade)
			})
		} else {
			sections.insert(section, at: index)

			tableView.reloadData()
		}
	}

	open func removeSection(_ section: StaticTableViewSection, animated: Bool = false) {
		if animated {
			tableView.performBatchUpdates({
				if let index = sections.firstIndex(of: section) {
					sections.remove(at: index)
					tableView.deleteSections(IndexSet(integer: index), with: .fade)
				}
			}, completion: { (_) in
				section.viewController = nil
			})
		} else {
			if let sectionIndex = sections.firstIndex(of: section) {
				sections.remove(at: sectionIndex)

				section.viewController = nil

				tableView.reloadData()
			} else {
				section.viewController = nil
			}
		}
	}

	open func addSections(_ addSections: [StaticTableViewSection], animated animateThis: Bool = false) {
		for section in addSections {
			section.viewController = self
		}

		if animateThis {
			tableView.performBatchUpdates({
				let index = sections.count
				sections.append(contentsOf: addSections)
				tableView.insertSections(IndexSet(integersIn: index..<(index+addSections.count)), with: UITableView.RowAnimation.fade)
			})
		} else {
			sections.append(contentsOf: addSections)
			tableView.reloadData()
		}
	}

	open func removeSections(_ removeSections: [StaticTableViewSection], animated animateThis: Bool = false) {
		if animateThis {
			tableView.performBatchUpdates({
				var removalIndexes : IndexSet = IndexSet()

				for section in removeSections {
					if let index : Int = sections.firstIndex(of: section) {
						removalIndexes.insert(index)
					}
				}

				for section in removeSections {
					if let index : Int = sections.firstIndex(of: section) {
						sections.remove(at: index)
					}
				}

				tableView.deleteSections(removalIndexes, with: .fade)
			}, completion: { (_) in
				for section in removeSections {
					section.viewController = nil
				}
			})
		} else {
			for section in removeSections {
				sections.remove(at: sections.firstIndex(of: section)!)
				section.viewController = nil
			}

			tableView.reloadData()
		}
	}

	// MARK: - Search
	open func sectionForIdentifier(_ sectionID: String) -> StaticTableViewSection? {
		for section in sections {
			if section.identifier == sectionID {
				return section
			}
		}

		return nil
	}

	open func rowInSection(_ inSection: StaticTableViewSection?, rowIdentifier: String) -> StaticTableViewRow? {
		if inSection == nil {
			for section in sections {
				if let row = section.row(withIdentifier: rowIdentifier) {
					return row
				}
			}
		} else {
			return inSection?.row(withIdentifier: rowIdentifier)
		}

		return nil
	}

	open func indexForSection(_ inSection: StaticTableViewSection) -> Int? {
		return sections.firstIndex(of: inSection)
	}

	// MARK: - View Controller
	override open func viewDidLoad() {
		super.viewDidLoad()
		extendedLayoutIncludesOpaqueBars = true
	}

	public var willDismissAction : ((_ viewController: StaticTableViewController) -> Void)?
	public var didDismissAction : ((_ viewController: StaticTableViewController) -> Void)?

	@objc open func dismissAnimated() {
		self.willDismissAction?(self)

		if self.extensionContext != nil {
			self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
		} else {
			self.dismiss(animated: true, completion: {
				self.didDismissAction?(self)
			})
		}
	}

	private var _themeRegistered = false
	override open func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		hasBeenPresentedAtLeastOnce = true

		if !_themeRegistered {
			_themeRegistered = true
			Theme.shared.register(client: self)
		}
	}

	deinit {
		Theme.shared.unregister(client: self)
	}

	// MARK: - Tools
	open func staticRowForIndexPath(_ indexPath: IndexPath) -> StaticTableViewRow {
		return (sections[indexPath.section].rows[indexPath.row])
	}

	// MARK: - Table view data source
	override open func numberOfSections(in tableView: UITableView) -> Int {
		return sections.count
	}

	override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return sections[section].rows.count
	}

	override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return sections[indexPath.section].rows[indexPath.row].cell!
	}

	override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

		let staticRow : StaticTableViewRow = staticRowForIndexPath(indexPath)

		if let action = staticRow.action {
			action(staticRow, self)
		}

		tableView.deselectRow(at: indexPath, animated: true)
	}

	override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return sections[section].headerTitle
	}

	override open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return sections[section].footerTitle
	}

	override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if sections[section].headerTitle != nil || sections[section].headerView != nil {
			return UITableView.automaticDimension
		}

		return 0.0
	}

	override open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		if sections[section].footerTitle != nil || sections[section].footerView != nil {
			return UITableView.automaticDimension
		}

		return 0.0
	}

	override open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		let cell = staticRowForIndexPath(indexPath)
		if cell.type == .datePicker {
			return 216.0
		}

		return tableView.rowHeight
	}

	override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return sections[section].headerView
	}

	override open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return sections[section].footerView
	}

	// MARK: - Theme support
	func applyColor(headerFooterView view: UIView, color: UIColor) {
		if let label = view as? UILabel {
			label.textColor = color
		} else if let headerView = view as? UITableViewHeaderFooterView {
			headerView.textLabel?.textColor = color
		}
	}

	open func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		self.tableView.applyThemeCollection(collection)

		var headerTextColor: UIColor?
		var footerTextColor: UIColor?

		for sectionIdx in 0..<sections.count {
			if let headerView = tableView.headerView(forSection: sectionIdx) {
				if headerTextColor == nil {
					headerTextColor = Theme.shared.activeCollection.css.getColor(.stroke, selectors: [.sectionHeader], for: tableView)
				}
				if let headerTextColor {
					applyColor(headerFooterView: headerView, color: headerTextColor)
				}
			}

			if let footerView = tableView.footerView(forSection: sectionIdx) {
				if footerTextColor == nil {
					footerTextColor = Theme.shared.activeCollection.css.getColor(.stroke, selectors: [.sectionHeader], for: tableView)
				}
				if let footerTextColor {
					applyColor(headerFooterView: footerView, color: footerTextColor)
				}
			}
		}
	}

	public override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		guard let sectionColor = Theme.shared.activeCollection.css.getColor(.stroke, selectors: [.sectionHeader], for: tableView) else { return }
		applyColor(headerFooterView: view, color: sectionColor)
	}

	public override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
		guard let sectionColor = Theme.shared.activeCollection.css.getColor(.stroke, selectors: [.sectionFooter], for: tableView) else { return }
		applyColor(headerFooterView: view, color: sectionColor)
	}
}
