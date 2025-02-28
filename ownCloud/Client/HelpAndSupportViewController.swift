//
//  HelpAndSupportViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 27.06.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit
import ownCloudSDK
import ownCloudApp
import ownCloudAppShared

class HelpAndSupportViewController: CollectionViewController {
	init() {
		super.init(context: nil, sections: nil, useStackViewRoot: true)

		add(sections: [
			helpAndSupportSection()
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		cssSelectors = [.modal]

		navigationItem.title = OCLocalizedString("Help & Contact", nil)
		navigationItem.largeTitleDisplayMode = .always

		navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction(handler: { [weak self] _ in
			self?.dismiss(animated: true)
		}))
	}

	func helpAndSupportSection() -> CollectionViewSection {
		var elements: [ComposedMessageElement] = []

		if let documentationURL = VendorServices.shared.documentationURL {
			elements.append(contentsOf: [
				.title(OCLocalizedString("Documentation", nil)),
				.text(OCLocalizedString("Find information, answers and solutions in the detailed documentation.", nil), style: .informal, cssSelectors: [.message]),
				.spacing(5),

				.button(OCLocalizedString("View documentation", nil), action: UIAction(handler: { [weak self] _ in
					if let self {
						VendorServices.shared.openSFWebView(on: self, for: documentationURL)
					}
				}), image: nil, cssSelectors: [ .info ]),

				.spacing(20)
			])
		}

		elements.append(contentsOf: [
			.title(OCLocalizedString("Help", nil)),
			.text(OCLocalizedString("Get in touch with our community in the forums - or file a GitHub issue to report a bug or request a feature.", nil), style: .informal, cssSelectors: [.message]),
			.spacing(5),

			.button(OCLocalizedString("File an issue", nil), action: UIAction(handler: { [weak self] _ in
				if let self {
					VendorServices.shared.openSFWebView(on: self, for: URL(string: "https://github.com/owncloud/ios-app/issues/new/choose")!)
				}
			}), image: nil, cssSelectors: [ .info ]),

			.button(OCLocalizedString("Visit the forums", nil), action: UIAction(handler: { [weak self] _ in
				if let self {
					VendorServices.shared.openSFWebView(on: self, for: URL(string: "https://central.owncloud.org/c/ios/")!)
				}
			}), image: nil, cssSelectors: [ .info ]),

			.spacing(20)
		])

		if Branding.shared.feedbackURL != nil {
			elements.append(contentsOf: [
				.title(OCLocalizedString("Feedback", nil)),

				.text(OCLocalizedString("If you have a moment to give us your feedback, please take our survey.", nil), style: .informal, cssSelectors: [.message]),
				.spacing(5),

				.button(OCLocalizedString("Take survey", nil), action: UIAction(handler: { [weak self] _ in
					if let self {
						VendorServices.shared.sendFeedback(from: self)
					}
				}), image: nil, cssSelectors: [ .info ], insets: .zero)
			])
		}

		let section = CollectionViewSection(identifier: "helpAndSupport", dataSource: OCDataSourceArray(items: [
			ComposedMessageView(elements: elements)
		]))

		return section
	}
}
