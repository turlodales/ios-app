//
//  ProPhotoUploadSettingsSection.swift
//  ownCloud
//
//  Created by Michael Neuwert on 24.07.20.
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
import ownCloudAppShared
import AVFoundation
import ownCloudSDK

extension AVCaptureDevice {
	var supportsRaw : Bool {
		let session = AVCaptureSession()
		let output = AVCapturePhotoOutput()

		guard let input = try? AVCaptureDeviceInput(device: self) else {
			  return false
		}

		guard session.canAddInput(input) else { return false  }
		guard session.canAddOutput(output) else { return false }

		session.beginConfiguration()
		session.sessionPreset = .photo
		session.addInput(input)
		session.addOutput(output)
		session.commitConfiguration()

		guard let rawFileType = output.availableRawPhotoFileTypes.first else { return false }

		return !output.supportedRawPhotoPixelFormatTypes(for: rawFileType).isEmpty
	}

	class func rawCameraDeviceAvailable() -> Bool {
		let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
			[.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera],
																mediaType: .video, position: .unspecified)
		for device in discoverySession.devices {
			if device.supportsRaw {
				return true
			}
		}

		return false
	}
}

extension UserDefaults {
	enum ProMediaUploadSettingsKeys : String {
		case PreferOriginals = "pro-photo-upload-prefer-originals"
		case PreferRAW = "pro-photo-upload-prefer-raw"
		case PreferOriginalVideos = "pro-video-upload-prefer-originals"
	}

	public var preferOriginalPhotos: Bool {
		set {
			self.set(newValue, forKey: ProMediaUploadSettingsKeys.PreferOriginals.rawValue)
		}

		get {
			return self.bool(forKey: ProMediaUploadSettingsKeys.PreferOriginals.rawValue)
		}
	}

	public var preferRawPhotos: Bool {
		set {
			self.set(newValue, forKey: ProMediaUploadSettingsKeys.PreferRAW.rawValue)
		}

		get {
			return self.bool(forKey: ProMediaUploadSettingsKeys.PreferRAW.rawValue)
		}
	}

	public var preferOriginalVideos: Bool {
		set {
			self.set(newValue, forKey: ProMediaUploadSettingsKeys.PreferOriginalVideos.rawValue)
		}

		get {
			return self.bool(forKey: ProMediaUploadSettingsKeys.PreferOriginalVideos.rawValue)
		}
	}
}

class ProPhotoUploadSettingsSection: SettingsSection {

	override init(userDefaults: UserDefaults) {
		super.init(userDefaults: userDefaults)
		self.headerTitle = OCLocalizedString("Extended upload settings", nil)

		let preferOriginalsRow = StaticTableViewRow(switchWithAction: { (_, sender) in
			if let enableSwitch = sender as? UISwitch {
				userDefaults.preferOriginalPhotos = enableSwitch.isOn
			}
			}, title: OCLocalizedString("Prefer unedited photos", nil), value: self.userDefaults.preferOriginalPhotos, identifier: "prefer-originals")

		self.add(row: preferOriginalsRow)

        let preferRawRow = StaticTableViewRow(switchWithAction: { (_, sender) in
            if let enableSwitch = sender as? UISwitch {
                userDefaults.preferRawPhotos = enableSwitch.isOn
            }
            }, title: OCLocalizedString("Prefer RAW photos", nil), value: self.userDefaults.preferRawPhotos, identifier: "prefer-raw")

        self.add(row: preferRawRow)

		let preferOriginalVideosRow = StaticTableViewRow(switchWithAction: { (_, sender) in
			if let enableSwitch = sender as? UISwitch {
				userDefaults.preferOriginalVideos = enableSwitch.isOn
			}
			}, title: OCLocalizedString("Prefer original videos", nil), value: self.userDefaults.preferOriginalVideos, identifier: "prefer-original-videos")

		self.add(row: preferOriginalVideosRow)
	}
}
