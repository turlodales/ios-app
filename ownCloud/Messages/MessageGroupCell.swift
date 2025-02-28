//
//  MessageGroupCell.swift
//  ownCloud
//
//  Created by Felix Schwarz on 25.05.20.
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
import ownCloudAppShared

protocol MessageGroupCellDelegate : AnyObject {
	func cell(_ cell: MessageGroupCell, showMessagesLike: OCMessage)
}

class MessageGroupCell: ThemeTableViewCell {

	weak var delegate: MessageGroupCellDelegate?
	weak var core : OCCore?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	// MARK: - Present item
	var messageGroup : MessageGroup? {
		didSet {
			if let newMessageGroup = messageGroup {
				if messageGroup?.identifier != oldValue?.identifier, let applyAllSwitch = applyAllSwitch {
					OnMainThread {
						applyAllSwitch.isOn = false
					}
				}

				updateWith(newMessageGroup, queue: OCMessageQueue.global)
			}
		}
	}

	var containerView : UIView?
	var alertView : AlertView?

	var applyAllContainer : UIView?
	var applyAllSwitch : UISwitch?
	var applyAllLabel : ThemeCSSLabel?
	var showAllButton : ThemeCSSButton?
	var badgeLabel : RoundedLabel?

	var noBottomSpacing : Bool = false

	private let applyAllSwitchVerticalInset : CGFloat = 10
	private let applyAllSwitchHorizontalInset : CGFloat = 20
	private let applyAllSwitchHorizontalSpacing : CGFloat = 10
	private let showAllSwitchHorizontalInset : CGFloat = 20
	private let alertSpacing : CGFloat = 20
	private let alertRadius : CGFloat = 10

	func updateWith(_ messageGroup: MessageGroup, queue: OCMessageQueue) {
		var options : [AlertOption] = []

		// Remove old views
		alertView?.removeFromSuperview()
		alertView = nil

		applyAllContainer?.removeFromSuperview()

		containerView?.removeFromSuperview()

		guard let message = messageGroup.messages.first else {
			return
		}

		let messages = messageGroup.messages
		let multiMessage = messages.count > 1
		let multiMessageCount = messages.count

		if let choices = message.choices {
			for choice in choices {
				let option = AlertOption(label: choice.label, type: choice.type, handler: { [weak self] (_, _) in
					if let applyAllSwitch = self?.applyAllSwitch, applyAllSwitch.isOn {
						if let messages = self?.messageGroup?.messages {
							for message in messages {
								if let messageChoice = message.choice(withIdentifier: choice.identifier) {
									queue.resolveMessage(message, with: messageChoice)
								}
							}
						}
					} else {
						queue.resolveMessage(message, with: choice)
					}
				})

				options.append(option)
			}
		}

		if let title = message.localizedTitle, let description = message.localizedDescription {
			if containerView == nil {
				containerView = UIView()
				containerView?.translatesAutoresizingMaskIntoConstraints = false
			}

			alertView = AlertView(localizedTitle: title, localizedDescription: description, options: options)
			alertView?.translatesAutoresizingMaskIntoConstraints = false

			containerView?.layer.cornerRadius = alertRadius
			containerView?.layer.masksToBounds = true
			containerView?.backgroundColor = UIColor(white: 0.70, alpha: 0.15)

			if multiMessage {
				var setupLayout : Bool = false

				if applyAllContainer == nil {
					applyAllContainer = UIView()
					applyAllContainer?.translatesAutoresizingMaskIntoConstraints = false
					applyAllContainer?.backgroundColor = UIColor(white: 0.60, alpha: 0.10)

					setupLayout = true
				}

				if applyAllLabel == nil {
					applyAllLabel = ThemeCSSLabel()
					applyAllLabel?.translatesAutoresizingMaskIntoConstraints = false
					applyAllLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
					applyAllLabel?.text = OCLocalizedString("Apply to all", nil)
					applyAllLabel?.lineBreakMode = .byTruncatingTail

					applyAllContainer?.addSubview(applyAllLabel!)
				}

				if applyAllSwitch == nil {
					applyAllSwitch = UISwitch()
					applyAllSwitch?.translatesAutoresizingMaskIntoConstraints = false
					applyAllSwitch?.accessibilityLabel = OCLocalizedString("Apply choice to all similar issues", nil)
					applyAllSwitch?.addTarget(self, action: #selector(applyAllSwitchChanged), for: .primaryActionTriggered)

					applyAllContainer?.addSubview(applyAllSwitch!)
				}

				if badgeLabel == nil {
					badgeLabel = RoundedLabel(text: "", style: .token)
					badgeLabel?.translatesAutoresizingMaskIntoConstraints = false
				}

				badgeLabel?.isHidden = true

				if showAllButton == nil {
					showAllButton = ThemeCSSButton(type: .system)
					showAllButton?.translatesAutoresizingMaskIntoConstraints = false
					showAllButton?.addTarget(self, action: #selector(showAllIssues), for: .primaryActionTriggered)

					applyAllContainer?.addSubview(showAllButton!)
				}

				showAllButton?.setTitle("\(OCLocalizedString("Show all", nil)) (\(multiMessageCount))", for: .normal)

				if setupLayout, let applyAllContainer = applyAllContainer, let applyAllSwitch = applyAllSwitch, let applyAllLabel = applyAllLabel, let showAllButton = showAllButton {
					NSLayoutConstraint.activate([
						applyAllSwitch.topAnchor.constraint(equalTo: applyAllContainer.topAnchor, constant: applyAllSwitchVerticalInset),
						applyAllSwitch.leftAnchor.constraint(equalTo: applyAllContainer.leftAnchor, constant: applyAllSwitchHorizontalInset),
						applyAllSwitch.bottomAnchor.constraint(equalTo: applyAllContainer.bottomAnchor, constant: -applyAllSwitchVerticalInset),

						applyAllLabel.leftAnchor.constraint(equalTo: applyAllSwitch.rightAnchor, constant: applyAllSwitchHorizontalSpacing),
						applyAllLabel.centerYAnchor.constraint(equalTo: applyAllSwitch.centerYAnchor),

						showAllButton.leftAnchor.constraint(greaterThanOrEqualTo: applyAllLabel.rightAnchor, constant: showAllSwitchHorizontalInset),
						showAllButton.rightAnchor.constraint(equalTo: applyAllContainer.rightAnchor, constant: -showAllSwitchHorizontalInset),
						showAllButton.centerYAnchor.constraint(equalTo: applyAllSwitch.centerYAnchor)
					])
				}

				self.applyThemeCollection(theme: Theme.shared, collection: Theme.shared.activeCollection, event: .initial)
			}

			if let alertView = alertView, let containerView = containerView {
				self.contentView.addSubview(containerView)

				containerView.addSubview(alertView)

				if multiMessage, let applyAllContainer = applyAllContainer, let badgeLabel = badgeLabel {
					containerView.addSubview(applyAllContainer)
					containerView.addSubview(badgeLabel)
				}

				NSLayoutConstraint.activate([
					containerView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: alertSpacing),
					containerView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -alertSpacing),
					containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: alertSpacing),
					containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: noBottomSpacing ? 0 : -alertSpacing),

					alertView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
					alertView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
					alertView.topAnchor.constraint(equalTo: containerView.topAnchor)
				])

				if multiMessage, let applyAllContainer = applyAllContainer, let badgeLabel = badgeLabel {
					NSLayoutConstraint.activate([
						alertView.bottomAnchor.constraint(equalTo: applyAllContainer.topAnchor),
						applyAllContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
						applyAllContainer.leftAnchor.constraint(equalTo: containerView.leftAnchor),
						applyAllContainer.rightAnchor.constraint(equalTo: containerView.rightAnchor),

						badgeLabel.centerYAnchor.constraint(equalTo: alertView.titleLabel.centerYAnchor),
						badgeLabel.rightAnchor.constraint(equalTo: alertView.titleLabel.rightAnchor)
					])
				} else {
					NSLayoutConstraint.activate([
						alertView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
					])
				}
			}
		}

		self.accessoryType = .none
	}

	@objc func applyAllSwitchChanged() {
		badgeLabel?.labelText = NSString(format: OCLocalizedString("+ %ld more", nil) as NSString, ((messageGroup?.messages.count ?? 0) - 1)) as String

		if let applyAllOn = self.applyAllSwitch?.isOn, let badgeLabel = badgeLabel, badgeLabel.isHidden != !applyAllOn {
			badgeLabel.alpha = applyAllOn ? 0 : 1
			badgeLabel.isHidden = false

			UIView.animate(withDuration: 0.2, animations: {
				badgeLabel.alpha = applyAllOn ? 1 : 0
			}, completion: { (_) in
				badgeLabel.isHidden = !applyAllOn
			})
		}
	}

	@objc func showAllIssues() {
		if let message = messageGroup?.messages.first {
			delegate?.cell(self, showMessagesLike: message)
		}
	}
}
