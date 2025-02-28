//
//  LogSettingsViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 08.11.18.
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
import ownCloudAppShared

class LogSettingsViewController: StaticTableViewController {

	private let loggingSection = StaticTableViewSection(headerTitle: OCLocalizedString("Logging", nil))
	private var logLevelSection : StaticTableViewSection?
	private var logOutputSection : StaticTableViewSection?
	private var logBrowseSection : StaticTableViewSection?
	private var logTogglesSection : StaticTableViewSection?
	private var logPrivacySection : StaticTableViewSection?

	static let logLevelChangedNotificationName = NSNotification.Name("settings.log-level-changed")

	static var loggingEnabled : Bool {
		get {
			return OCLogger.logLevel.rawValue != OCLogLevel.off.rawValue
		}

		set {
			OCLogger.logLevel = newValue ? .debug : .off
			NotificationCenter.default.post(name: LogSettingsViewController.logLevelChangedNotificationName, object: nil)
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		self.navigationItem.title = OCLocalizedString("Logging", nil)

		// Logging
		loggingSection.add(row: StaticTableViewRow(switchWithAction: { [weak self] (row, _) in
			if let enabled = row.value as? Bool {
				LogSettingsViewController.loggingEnabled = enabled
				self?.updateSectionVisibility(animated: true)

				if enabled == false {
					for writer in OCLogger.shared.writers {
						if let fileWriter = writer as? OCLogFileWriter {
							fileWriter.rotate()
						}
					}
				}
			}
		}, title: OCLocalizedString("Enable logging", nil), value: LogSettingsViewController.loggingEnabled, identifier: "enable-logging"))

		let footerTitle = OCLocalizedString("When activated, logs may impact performance and include sensitive information. However the logs are not subject to automatic submission to %@ servers. Sharing logs with others is sole user responsibility.", nil)
		loggingSection.footerTitle = footerTitle.replacingOccurrences(of: "%@", with: VendorServices.shared.appName)

		// Update section visibility
		self.addSection(loggingSection)

		updateSectionVisibility(animated: false)
	}

	private func updateSectionVisibility(animated: Bool) {

		var addSections : [StaticTableViewSection] = []

		func createRequiredSections() {
			if logBrowseSection == nil {
				logBrowseSection = StaticTableViewSection(headerTitle: OCLocalizedString("Log Files", nil))

				// Creation of the frequency row.
				let logsRow = StaticTableViewRow(subtitleRowWithAction: { [weak self] (_, _) in
					let logFilesViewController = LogFilesViewController(style: .plain)
					self?.navigationController?.pushViewController(logFilesViewController, animated: true)
				}, title: OCLocalizedString("Browse", nil), accessoryType: .disclosureIndicator, identifier: "viewLogs")
				logBrowseSection?.add(row: logsRow)
				logBrowseSection?.footerTitle = OCLocalizedString("The last 10 archived logs are kept on the device - with each log covering up to 24 hours of usage. When sharing please bear in mind that logs may contain sensitive information such as server URLs and user-specific information.", nil)

				addSections.append(logBrowseSection!)
			}

			// Privacy
			// Reactivate the below code when the code base is reviewed in terms of correct masking of private data
			#if false
			if logPrivacySection == nil {
				logPrivacySection = StaticTableViewSection(headerTitle: OCLocalizedString("Privacy", nil))

				logPrivacySection?.add(row: StaticTableViewRow(switchWithAction: { (row, _) in
					if let maskPrivateData = row.value as? Bool {
						OCLogger.maskPrivateData = maskPrivateData
					}
				}, title: OCLocalizedString("Mask private data", nil), value: OCLogger.maskPrivateData, identifier: "mask-private-data"))
				logPrivacySection?.footerTitle = OCLocalizedString("Enabling this option will attempt to mask private data, so it does not become part of any log. Since logging is a development and debugging feature, though, we can't guarantee that the log file will be free of any private data even with this option enabled. Therefore, please look through any log file and verify its free of any data you're not comfortable sharing before sharing it with anybody.", nil)

				addSections.append(logPrivacySection!)
			}
			#endif
		}

		func removeAllSections() {
			var removeSections : [StaticTableViewSection] = []

			if logLevelSection != nil {
				removeSections.append(logLevelSection!)
				logLevelSection = nil
			}
			if logTogglesSection != nil {
				removeSections.append(logTogglesSection!)
				logTogglesSection = nil
			}
			if logOutputSection != nil {
				removeSections.append(logOutputSection!)
				logOutputSection = nil
			}

			if logBrowseSection != nil {
				removeSections.append(logBrowseSection!)
				logBrowseSection = nil
			}

			if logPrivacySection != nil {
				removeSections.append(logPrivacySection!)
				logPrivacySection = nil
			}

			self.removeSections(removeSections, animated: animated)
		}

		if LogSettingsViewController.loggingEnabled {

			removeAllSections()

			// Log level
			if logLevelSection == nil {
				logLevelSection = StaticTableViewSection(headerTitle: OCLocalizedString("Log Level", nil))

				let logLevels : [[String:Any]] = [
					[ OCLogLevel.verbose.label : OCLogLevel.verbose.rawValue ],
					[ OCLogLevel.debug.label   : OCLogLevel.debug.rawValue   ],
					[ OCLogLevel.info.label    : OCLogLevel.info.rawValue    ],
					[ OCLogLevel.warning.label : OCLogLevel.warning.rawValue ],
					[ OCLogLevel.error.label   : OCLogLevel.error.rawValue   ]
				]

				logLevelSection?.add(radioGroupWithArrayOfLabelValueDictionaries: logLevels, radioAction: { (row, _) in
					if let logLevel = row.value as? Int {
						OCLogger.logLevel = OCLogLevel(rawValue: logLevel)!

						NotificationCenter.default.post(name: LogSettingsViewController.logLevelChangedNotificationName, object: nil)
					}
				}, groupIdentifier: "log-level", selectedValue: OCLogger.logLevel.rawValue)

				addSections.append(logLevelSection!)
			}

			// Log toggles
			if logTogglesSection == nil {
				logTogglesSection = StaticTableViewSection(headerTitle: OCLocalizedString("Options", nil))

				for toggle in OCLogger.shared.toggles {
					let row = StaticTableViewRow(switchWithAction: { (row, _) in
						if let enabled = row.value as? Bool {
							toggle.enabled = enabled
						}
					}, title: toggle.localizedName, value: toggle.enabled, identifier: toggle.identifier.rawValue)

					logTogglesSection?.add(row: row)
				}

				addSections.append(logTogglesSection!)
			}

			// Log output
			if logOutputSection == nil {
				logOutputSection = StaticTableViewSection(headerTitle: OCLocalizedString("Log Destinations", nil))

				for writer in OCLogger.shared.writers {
					let row = StaticTableViewRow(switchWithAction: { (row, _) in
						if let enabled = row.value as? Bool {
							writer.enabled = enabled
						}
					}, title: writer.name, value: writer.enabled, identifier: writer.identifier.rawValue)

					logOutputSection?.add(row: row)
				}

				addSections.append(logOutputSection!)
			}

		} else {
			removeAllSections()
		}

		createRequiredSections()

		if addSections.count > 0 {
			self.addSections(addSections, animated: animated)
		}
	}
}
