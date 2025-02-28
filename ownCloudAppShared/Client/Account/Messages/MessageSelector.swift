//
//  MessageSelector.swift
//  ownCloud
//
//  Created by Felix Schwarz on 25.03.20.
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
import ownCloudSDK

public typealias MessageSelectorFilter = (_ message: OCMessage) -> Bool
public typealias MessageSelectorChangeHandler = (_ messages: [OCMessage]?, _ groups : [MessageGroup]?, _ syncRecordIDs : Set<OCSyncRecordID>?) -> Void

public extension OCMessageCategoryIdentifier {
	static let other : OCMessageCategoryIdentifier = OCMessageCategoryIdentifier(rawValue: "_other")
}

public class MessageSelector: NSObject {
	private var observer : NSKeyValueObservation?
	private var rateLimiter : OCRateLimiter
	private var filter : MessageSelectorFilter?

	public var queue : OCMessageQueue?
	public var handler : MessageSelectorChangeHandler?
	private var provideGroupedSelection : Bool = false
	private var provideSyncRecordIDs : Bool = false

	private var selectionUUIDs : [OCMessageUUID] = []
	public var selection : [OCMessage]? {
		didSet {
			self.handler?(selection, groupedSelection, syncRecordIDsInSelection)
		}
	}
	public var groupedSelection : [MessageGroup]?
	public var syncRecordIDsInSelection : Set<OCSyncRecordID>?

	public init(from messageQueue: OCMessageQueue = .global, filter messageFilter: MessageSelectorFilter?, provideGroupedSelection: Bool = false, provideSyncRecordIDs: Bool = false, handler: MessageSelectorChangeHandler?) {
		rateLimiter = OCRateLimiter(minimumTime: 0.2)

		filter = messageFilter
		queue = messageQueue
		self.provideGroupedSelection = provideGroupedSelection
		self.provideSyncRecordIDs = provideSyncRecordIDs
		self.handler = handler

		super.init()

		observer = messageQueue.observe(\OCMessageQueue.messages, options: .initial, changeHandler: { [weak self] (_, _) in
			self?.rateLimiter.runRateLimitedBlock {
				self?.updateFromQueue()
			}
		})
	}

	private func updateFromQueue() {
		if let messages = queue?.messages {
			let filteredMessages = (filter != nil) ? messages.filter(filter!) : messages
			var filteredMessageUUIDs : [OCMessageUUID] = []

			for message in filteredMessages {
				filteredMessageUUIDs.append(message.uuid as OCMessageUUID)
			}

			if (filteredMessageUUIDs.count != selectionUUIDs.count) || !filteredMessageUUIDs.elementsEqual(selectionUUIDs) {
				if provideGroupedSelection {
					var messageGroupsByIdentifier : [OCMessageCategoryIdentifier : MessageGroup] = [:]
					var messageGroups : [MessageGroup] = []

					for message in filteredMessages {
						var messageGroup : MessageGroup?

						if let categoryIdentifier = message.categoryIdentifier {
							messageGroup = messageGroupsByIdentifier[categoryIdentifier]
						}

						if messageGroup == nil {
							messageGroup = MessageGroup(with: message)

							if let messageGroup = messageGroup {
								if let categoryIdentifier = message.categoryIdentifier {
									messageGroupsByIdentifier[categoryIdentifier] = messageGroup
								}
								messageGroups.append(messageGroup)
							}
						} else {
							messageGroup?.messages.append(message)
						}
					}

					groupedSelection = messageGroups
				}

				if provideSyncRecordIDs {
					var syncRecordIDs : Set<OCSyncRecordID>?

					for message in filteredMessages {
						if let messageSyncRecordID = message.syncIssue?.syncRecordID {
							if syncRecordIDs == nil {
								syncRecordIDs = Set()
							}
							syncRecordIDs!.insert(messageSyncRecordID)
						}
					}

					syncRecordIDsInSelection = syncRecordIDs
				}

				selectionUUIDs = filteredMessageUUIDs
				selection = filteredMessages
			}
		} else {
			selectionUUIDs = []
			groupedSelection = nil
			selection = nil
		}
	}
}
