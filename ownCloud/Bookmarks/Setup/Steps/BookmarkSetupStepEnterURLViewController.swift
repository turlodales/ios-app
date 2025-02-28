//
//  BookmarkSetupStepEnterURLViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 06.09.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit
import ownCloudAppShared
import ownCloudSDK

class BookmarkSetupStepEnterURLViewController: BookmarkSetupStepViewController {
	var urlTextField: UITextField?

	override func loadView() {
		stepTitle = OCLocalizedString("Server URL", nil)

		super.loadView()

		urlTextField = buildTextField(withAction: UIAction(handler: { [weak self] _ in
			self?.updateState()
		}), placeholder: "https://", keyboardType: .URL, autocorrectionType: .no, autocapitalizationType: .none, accessibilityLabel: OCLocalizedString("Server URL", nil), borderStyle: .roundedRect)

		urlTextField?.text = setupViewController?.composer?.configuration.url?.absoluteString

		focusTextFields = [ urlTextField! ]

		contentView = urlTextField

		updateState()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		urlTextField?.becomeFirstResponder()
	}

	func updateState() {
		if let urlString = urlTextField?.text, urlString.count > 0, NSURL(username: nil, password: nil, afterNormalizingURLString: urlString, protocolWasPrepended: nil) != nil {
			continueButton.isEnabled = true
		} else {
			continueButton.isEnabled = false
		}
	}

	override func handleContinue() {
		if let urlString = urlTextField?.text {
			setupViewController?.composer?.enterURL(urlString, completion: composerCompletion)
		}
	}
}
