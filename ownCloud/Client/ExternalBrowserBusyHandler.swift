//
//  ExternalBrowserBusyHandler.swift
//  ownCloud
//
//  Created by Felix Schwarz on 05.05.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
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

class ExternalBrowserBusyHandler: UIViewController, Themeable {
	static func setup() {
		OCAuthenticationBrowserSessionCustomScheme.busyPresenter = { (session, cancelHandler) in
			let viewController = ExternalBrowserBusyHandler()
			var hostViewController = session.hostViewController

			while hostViewController?.presentedViewController != nil {
				hostViewController  = hostViewController?.presentedViewController
			}

			viewController.cancelHandler = cancelHandler
			viewController.isModalInPresentation = true

			hostViewController?.present(viewController, animated: true, completion: nil)

			return {
				hostViewController?.dismiss(animated: true, completion: nil)
			}
		}
	}

	var infoLabel = ThemeCSSLabel(withSelectors: [.secondary])
	var cancelButton = ThemeButton(withSelectors: [.cancel])

	var cancelHandler : (() -> Void)?

	override func loadView() {
		let backgroundView = UIView()
		let activityIndicator = UIActivityIndicatorView(style: Theme.shared.activeCollection.css.getActivityIndicatorStyle() ?? .medium)
		activityIndicator.translatesAutoresizingMaskIntoConstraints = false
		activityIndicator.startAnimating()

		backgroundView.addSubview(activityIndicator)

		cancelButton.translatesAutoresizingMaskIntoConstraints = false
		cancelButton.setTitle(OCLocalizedString("Cancel", nil), for: .normal)
		cancelButton.addTarget(self, action: #selector(ExternalBrowserBusyHandler.cancel), for: UIControl.Event.touchUpInside)
		backgroundView.addSubview(cancelButton)

		infoLabel.translatesAutoresizingMaskIntoConstraints = false
		infoLabel.adjustsFontForContentSizeCategory = true
		infoLabel.textAlignment = .center
		infoLabel.font = UIFont.preferredFont(forTextStyle: .body)
		infoLabel.text = OCLocalizedString("Waiting for response from login session in external browser…", nil)
		infoLabel.numberOfLines = 0
		infoLabel.setContentCompressionResistancePriority(.required, for: .vertical)
		infoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		infoLabel.setContentHuggingPriority(.required, for: .horizontal)
		infoLabel.setContentHuggingPriority(.required, for: .vertical)
		backgroundView.addSubview(infoLabel)

		NSLayoutConstraint.activate([
			activityIndicator.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
			activityIndicator.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -20),

			infoLabel.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
			infoLabel.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
			infoLabel.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
			infoLabel.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),

			cancelButton.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
			cancelButton.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 20)
		])

		view = backgroundView
	}

	private var themeRegistered = false
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if !themeRegistered {
			themeRegistered = true
			Theme.shared.register(client: self)
		}
	}

	func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		view.backgroundColor = collection.css.getColor(.fill, selectors: [.table], for: view)
	}

	@objc func cancel() {
		cancelHandler?()
		cancelHandler = nil
	}
}
