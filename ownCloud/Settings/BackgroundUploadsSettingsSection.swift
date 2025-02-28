//
//  BackgroundUploadsSettingsSection.swift
//  ownCloud
//
//  Created by Michael Neuwert on 27.05.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
* Copyright (C) 2020, ownCloud GmbH.
*
* This code is covered by the GNU Public License Version 3.
*
* For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
* You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
*
*/

import UIKit
import CoreLocation
import UserNotifications
import ownCloudSDK
import ownCloudApp
import ownCloudAppShared

extension UserDefaults {

	enum BackgroundUploadsKeys : String {
		case MediaUploadsEnabled = "background-media-uploads-enabled"
		case MediaUploadsNotificationsEnabled = "background-media-uploads-notifications-enabled"
		case MediaUploadsLocationUpdatesEnabled = "background-media-uploads-location-updates-enabled"
	}

	public var backgroundMediaUploadsEnabled: Bool {
		set {
			self.set(newValue, forKey: BackgroundUploadsKeys.MediaUploadsEnabled.rawValue)
		}

		get {
			return self.bool(forKey: BackgroundUploadsKeys.MediaUploadsEnabled.rawValue)
		}
	}

	public var backgroundMediaUploadsNotificationsEnabled: Bool {
		set {
			self.set(newValue, forKey: BackgroundUploadsKeys.MediaUploadsNotificationsEnabled.rawValue)
		}

		get {
			return self.bool(forKey: BackgroundUploadsKeys.MediaUploadsNotificationsEnabled.rawValue)
		}
	}

	public var backgroundMediaUploadsLocationUpdatesEnabled: Bool {
		set {
			self.set(newValue, forKey: BackgroundUploadsKeys.MediaUploadsLocationUpdatesEnabled.rawValue)
		}

		get {
			return self.bool(forKey: BackgroundUploadsKeys.MediaUploadsLocationUpdatesEnabled.rawValue)
		}
	}
}

class BackgroundUploadsSettingsSection: SettingsSection {

	private var backgroundUploadsRow: StaticTableViewRow?
	private var backgroundLocationRow: StaticTableViewRow?
	private var notificationsRow: StaticTableViewRow?

	override init(userDefaults: UserDefaults) {
		super.init(userDefaults: userDefaults)
		self.headerTitle = OCLocalizedString("Background uploads (Lab Version)", nil)

		// Add option for iOS13 to use BackgroundTasks framework for background uploads
		backgroundUploadsRow = StaticTableViewRow(switchWithAction: { (_, sender) in
			if let enableSwitch = sender as? UISwitch {
				userDefaults.backgroundMediaUploadsEnabled = enableSwitch.isOn
			}
		}, title: OCLocalizedString("Use background refresh", nil), subtitle: OCLocalizedString("Allow this app to refresh the content when on Wi-Fi or mobile network in background.", nil), value: self.userDefaults.backgroundMediaUploadsEnabled, identifier: "background-refresh")

		self.add(row: backgroundUploadsRow!)

		// Add option to enable background location updates which will trigger background media uploads
		#if !DISABLE_BACKGROUND_LOCATION
		var locationServicesRowTitle: String = ""
		locationServicesRowTitle = OCLocalizedString("Use background location updates", nil)

		// Add section footer with detailed explanations
		var locationServicesRowSubtitle = ""
		locationServicesRowSubtitle += OCLocalizedString("If you would like background media uploads to be more reliable, you should enable background location updates.", nil)
		locationServicesRowSubtitle += " "
		locationServicesRowSubtitle += OCLocalizedString("Otherwise background media uploads using background refresh technology would depend on how frequently you use the app.", nil)

		let currentAuthStatus = CLLocationManager().authorizationStatus == .authorizedAlways
		backgroundLocationRow = StaticTableViewRow(switchWithAction: { (_, sender) in
			if let enableSwitch = sender as? UISwitch {
				if enableSwitch.isOn {
					if !ScheduledTaskManager.shared.requestLocationAuthorization() {
						enableSwitch.isOn = false
						self.showLocationDisabledAlert()
					}
				} else {
					ScheduledTaskManager.shared.stopLocationMonitoring()
				}
				userDefaults.backgroundMediaUploadsLocationUpdatesEnabled = enableSwitch.isOn
			}
		}, title: locationServicesRowTitle, subtitle: locationServicesRowSubtitle, value: (currentAuthStatus && userDefaults.backgroundMediaUploadsLocationUpdatesEnabled), identifier: "background-location")

		self.add(row: backgroundLocationRow!)
		#endif /* !DISABLE_BACKGROUND_LOCATION */

		// Add option to enable local notifications reporting that some number of media files got enqueued for upload
		notificationsRow = StaticTableViewRow(switchWithAction: { (_, sender) in
			if let enableSwitch = sender as? UISwitch {
				if enableSwitch.isOn {
					// Request authorization for notifications
					NotificationManager.shared.getNotificationSettings(completionHandler: { (settings) in
						if settings.authorizationStatus == .notDetermined {
							NotificationManager.shared.requestAuthorization(options: [.alert]) { (granted, _) in
								OnMainThread {
									enableSwitch.isOn = granted
									userDefaults.backgroundMediaUploadsNotificationsEnabled = granted
								}
							}
						} else if settings.authorizationStatus == .authorized {
							userDefaults.backgroundMediaUploadsNotificationsEnabled = true
						} else {
							userDefaults.backgroundMediaUploadsNotificationsEnabled = false
						}
					})
				} else {
					userDefaults.backgroundMediaUploadsNotificationsEnabled = false
				}
			}
			}, title: OCLocalizedString("Background upload notifications", nil), value: userDefaults.backgroundMediaUploadsNotificationsEnabled, identifier: "background-upload-notifications")

		self.add(row: notificationsRow!)

		// Update notifications option
		NotificationManager.shared.getNotificationSettings(completionHandler: { (settings) in
			OnMainThread {
				self.notificationsRow?.value = userDefaults.backgroundMediaUploadsNotificationsEnabled && settings.authorizationStatus == .authorized
			}
		})

		// Monitor media upload settings changes
		NotificationCenter.default.addObserver(self, selector: #selector(mediaUploadSettingsDidChange), name: UserDefaults.MediaUploadSettingsChangedNotification, object: nil)

		updateUI()
	}

	deinit {
		NotificationCenter.default.removeObserver(self, name: UserDefaults.MediaUploadSettingsChangedNotification, object: nil)
	}

	private func showLocationDisabledAlert() {
		let alertController = ThemedAlertController(with: OCLocalizedString("Location permission denied", nil),
												message: OCLocalizedString("Please re-enable location acquisition in system settings", nil))
		self.viewController?.present(alertController, animated: true, completion: nil)
	}

	public func updateUI() {
		let enableRows = self.userDefaults.instantUploadPhotos || self.userDefaults.instantUploadVideos
		backgroundUploadsRow?.enabled = enableRows
		backgroundLocationRow?.enabled = enableRows
		notificationsRow?.enabled = enableRows
	}

	@objc func mediaUploadSettingsDidChange() {
		updateUI()
	}

}
