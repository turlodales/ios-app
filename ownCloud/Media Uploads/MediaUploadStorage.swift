//
//  MediaUploadStorage.swift
//  ownCloud
//
//  Created by Michael Neuwert on 21.11.2019.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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

import Foundation
import Photos
import ownCloudSDK
import ownCloudAppShared

class MediaUploadJob : NSObject, NSSecureCoding {

	var targetLocation : OCLocation? /// Target parent location of the upload
	var scheduledUploadLocalID: OCLocalID?

	static var supportsSecureCoding: Bool {
		return true
	}

	func encode(with coder: NSCoder) {
		coder.encode(targetLocation, forKey: "targetLocation")
		coder.encode(scheduledUploadLocalID, forKey: "scheduledUploadLocalID")
	}

	required init?(coder: NSCoder) {
		if let targetPath = coder.decodeObject(of: NSString.self, forKey: "targetPath") {
			self.targetLocation = OCLocation.legacyRootPath(targetPath as String)
		} else {
			self.targetLocation = coder.decodeObject(of: OCLocation.self, forKey: "targetLocation")
		}
		self.scheduledUploadLocalID = coder.decodeObject(forKey: "scheduledUploadLocalID") as? OCLocalID
	}

	init(_ targetLocation: OCLocation) {
		self.targetLocation = targetLocation
	}
}

class MediaUploadStorage : NSObject, NSSecureCoding {

	var queue: [String]
	var jobs: [String : [MediaUploadJob]]
	var processing: OCProcessSession?

	static var supportsSecureCoding: Bool {
		return true
	}

	var jobCount: Int {
		jobs.reduce(0) {$0 + $1.value.count }
	}

	func encode(with coder: NSCoder) {
		coder.encode(queue, forKey: "queue")
		coder.encode(jobs, forKey: "jobs")
		coder.encode(processing, forKey: "processing")
	}

	required init?(coder: NSCoder) {
		let storedQueue = coder.decodeObject(forKey: "queue") as? [String]
		self.queue = storedQueue != nil ? storedQueue! : [String]()

		let storedJobs =  coder.decodeObject(forKey: "jobs") as? [String : [MediaUploadJob]]
		jobs = storedJobs != nil ? storedJobs! : [String : [MediaUploadJob]]()

		processing = coder.decodeObject(forKey: "processing") as? OCProcessSession
	}

	override init() {
		queue = [String]()
		jobs = [String : [MediaUploadJob]]()
	}

	func addJob(with assetID:String, targetLocation: OCLocation) {
		if !queue.contains(assetID) {
			self.queue.append(assetID)
		}
		var existingJobs: [MediaUploadJob] = jobs[assetID] != nil ? jobs[assetID]! : [MediaUploadJob]()
		if existingJobs.filter({ (existingJob) in existingJob.targetLocation == targetLocation}).count == 0 {
			existingJobs.append(MediaUploadJob(targetLocation))
		}
		jobs[assetID] = existingJobs
	}

	func removeJob(with assetID:String, targetLocation: OCLocation) {
		if let remainingJobs = jobs[assetID]?.filter({ (existingJob) in existingJob.targetLocation != targetLocation}) {
			jobs[assetID] = remainingJobs
			if remainingJobs.count == 0 {
				if let assetIdQueueIndex = queue.firstIndex(of: assetID) {
					queue.remove(at: assetIdQueueIndex)
				}
			}
		}
	}

	func update(localItemID:OCLocalID, assetId:String, targetLocation: OCLocation) {
		jobs[assetId]?.filter({ (job) in job.targetLocation == targetLocation}).first?.scheduledUploadLocalID = localItemID
	}
}

typealias MediaUploadStorageModifier = (_ storage:MediaUploadStorage) -> MediaUploadStorage

extension OCKeyValueStore {
	func registerMediaUploadClasses() {
		// Check if NSCoding-compatible classes are not yet registered?
		if registeredClasses(forKey: OCBookmark.MediaUploadStorageKey) == nil {

			// This weird trickery is required since Set<AnyHashable> can't be created directly
			if let classSet = NSSet(array: [
				MediaUploadStorage.self,
				MediaUploadJob.self,
				OCProcessSession.self,
				NSArray.self,
				NSDictionary.self,
				NSString.self
			]) as? Set<AnyHashable> {
				registerClasses(classSet, forKey: OCBookmark.MediaUploadStorageKey)
			}
		}
	}
}

extension OCBookmark {
	static let MediaUploadStorageKey = OCKeyValueStoreKey(rawValue: "com.owncloud.media-upload-storage")

	//
	// NOTE: Deriving KV store from bookmark rather than from OCCore since it simplifies adding upload jobs
	// significantly without a need to initialize full blown core for that
	//

	static var cachedKeyValueStores : [UUID : OCKeyValueStore] = [ : ]

	var mediaUploadKeyValueStore : OCKeyValueStore? {
		var keyValueStore : OCKeyValueStore?
		var vault : OCVault?
		var migrateStorage : Bool = false

		OCSynchronized(OCBookmark.self) {
			// Retrieve Key Value Store for bookmark from cache
			keyValueStore = OCBookmark.cachedKeyValueStores[self.uuid]

			if keyValueStore == nil {
				// Create KVS instance for bookmark and add it to the cache
				vault = OCVault(bookmark: self)

				if let vaultRootURL = vault?.rootURL {
					keyValueStore = OCKeyValueStore(url: vaultRootURL.appendingPathComponent("mediaUploads.db", isDirectory: false), identifier: "\(uuid.uuidString).mediaUploads")
					keyValueStore?.registerMediaUploadClasses()

					OCBookmark.cachedKeyValueStores[uuid] = keyValueStore
				}
			}

			// Check if media uploads have been migrated
			let migrationKey = "MediaUploadsMigrated:\(uuid.uuidString)"

			if OCAppIdentity.shared.userDefaults?.bool(forKey: migrationKey) != true {
				OCAppIdentity.shared.userDefaults?.setValue(true, forKey: migrationKey)
				migrateStorage = true
			}
		}

		// Migrate from legacy to new store
		if migrateStorage, let vault = vault, let legacyStore = vault.keyValueStore, let keyValueStore = keyValueStore {
			legacyStore.registerMediaUploadClasses()

			// Read from "legacy" store
			if let mediaUploadStorage = legacyStore.readObject(forKey: OCBookmark.MediaUploadStorageKey) as? MediaUploadStorage {
				// Store in the dedicated store
				keyValueStore.storeObject(mediaUploadStorage, forKey: OCBookmark.MediaUploadStorageKey)

				// Remove from the "legacy" store
				legacyStore.storeObject(nil, forKey: OCBookmark.MediaUploadStorageKey)
			}
		}

		return keyValueStore
	}

	func modifyMediaUploadStorage(with modifier: @escaping MediaUploadStorageModifier) {
		mediaUploadKeyValueStore?.updateObject(forKey: OCBookmark.MediaUploadStorageKey, usingModifier: { (value, changesMadePtr) -> Any? in
			var storage = value as? MediaUploadStorage

			if storage == nil {
				storage = MediaUploadStorage()
			}

			storage = modifier(storage!)

			changesMadePtr.pointee = true

			return storage
		})
	}

	var mediaUploadStorage : MediaUploadStorage? {
		return mediaUploadKeyValueStore?.readObject(forKey: OCBookmark.MediaUploadStorageKey) as? MediaUploadStorage
	}
}
