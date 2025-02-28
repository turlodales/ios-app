//
//  SettingsViewController.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 30/04/2018.
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
import ownCloudApp
import ownCloudAppShared

class SettingsViewController: StaticTableViewController {

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		self.navigationItem.title = OCLocalizedString("Settings", nil)

		if self.navigationController?.isBeingPresented ?? false {
			let doneBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissAnimated))
			self.navigationItem.rightBarButtonItem = doneBarButtonItem
		}

		if let userDefaults = OCAppIdentity.shared.userDefaults {
			if AppLockManager.supportedOnDevice {
				self.addSection(SecuritySettingsSection(userDefaults: userDefaults))
			}
			self.addSection(UserInterfaceSettingsSection(userDefaults: userDefaults))
			self.addSection(DataSettingsSection(userDefaults: userDefaults))
			self.addSection(DisplaySettingsSection(userDefaults: userDefaults))
			self.addSection(MediaFilesSettingsSection(userDefaults: userDefaults))

			#if !DISABLE_APPSTORE_LICENSING
			if !OCLicenseEMMProvider.isEMMVersion, // Do not show purchases in the EMM version
			   // Do only show purchases section if there's at least one non-Enterprise account
			   OCLicenseEnterpriseProvider.numberOfEnterpriseAccounts < OCBookmarkManager.shared.bookmarks.count, !VendorServices.shared.isBranded // Do not show purchases in branded app
			{
				self.addSection(PurchasesSettingsSection(userDefaults: userDefaults))
			}
			#endif

			self.addSection(MoreSettingsSection(userDefaults: userDefaults))
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		VendorServices.shared.considerReviewPrompt()
	}
}
