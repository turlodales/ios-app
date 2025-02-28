//
//  AccountControllerSpacesGridViewController.swift
//  ownCloudAppShared
//
//  Created by Felix Schwarz on 29.11.22.
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

class AccountControllerSpacesGridViewController: CollectionViewController, ViewControllerPusher {
	var spacesSection: CollectionViewSection
	var noSpacesCondition: DataSourceCondition?

	init(with context: ClientContext) {
		let gridContext = ClientContext(with: context)

		gridContext.postInitializationModifier = { (owner, context) in
			context.viewControllerPusher = owner as? ViewControllerPusher
		}

		spacesSection = CollectionViewSection(identifier: "spaces", dataSource: context.core?.projectDrivesDataSource, cellStyle: .init(with: .gridCell), cellLayout: AccountControllerSpacesGridViewController.cellLayout(for: .current))

		super.init(context: gridContext, sections: [ spacesSection ], useStackViewRoot: true, hierarchic: false)

		self.revoke(in: gridContext, when: [ .connectionClosed ])

		navigationItem.title = OCLocalizedString("Spaces", nil)

		if let projectDrivesDataSource = context.core?.projectDrivesDataSource {
			let noSpacesMessage = ComposedMessageView(elements: [
				.image(OCSymbol.icon(forSymbolName: "square.grid.2x2")!, size: CGSize(width: 64, height: 48), alignment: .centered),
				.title(OCLocalizedString("No spaces", nil), alignment: .centered)
			])

			noSpacesCondition = DataSourceCondition(.empty, with: projectDrivesDataSource, initial: true, action: { [weak self] condition in
				let coverView = (condition.fulfilled == true) ? noSpacesMessage : nil
				self?.setCoverView(coverView, layout: .top)
			})
		}

		// Disable dragging of items, so keyboard control does
		// not include "Drag Item" in the accessibility actions
		// invoked with Tab + Z
		defer { // needed so dragInteractionEnabled.didSet is called despite being set in the initializer
			dragInteractionEnabled = false
		}
	}

	static func cellLayout(for traitCollection: UITraitCollection) -> CollectionViewSection.CellLayout {
		return .fillingGrid(minimumWidth: 260, maximumWidth: 300, computeHeight: { width in
			return floor(width * 3 / 4)
		}, cellSpacing: NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10), sectionInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5), center: true)
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)

		OnMainThread {
			self.spacesSection.cellLayout = AccountControllerSpacesGridViewController.cellLayout(for: self.traitCollection)
		}
	}

	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func pushViewController(context: ClientContext?, provider: (ClientContext) -> UIViewController?, push: Bool, animated: Bool) -> UIViewController? {
		var viewController: UIViewController?

		if let context {
			viewController = provider(context)
		}

		if push, let viewController {
			navigationController?.pushViewController(viewController, animated: animated)
		}

		return viewController
	}
}
