//
//  ClientActivityCell.swift
//  ownCloud
//
//  Created by Felix Schwarz on 26.01.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
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

protocol ClientActivityCellDelegate : AnyObject {

	func showMessage(for activity: OCActivity)

	func hasMessage(for activity: OCActivity) -> Bool
}

class ClientActivityCell: ThemeTableViewCell {

	weak var delegate: ClientActivityCellDelegate?

	var descriptionLabel : UILabel = UILabel()
	var statusLabel : UILabel = UILabel()
	var statusCircle: ProgressView = ProgressView()
	var messageButton : UIButton = UIButton()

	var activeThumbnailRequestProgress : Progress?

	weak var core : OCCore?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		prepareViewAndConstraints()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	func prepareViewAndConstraints() {
		descriptionLabel.numberOfLines = 0
		descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
		statusLabel.translatesAutoresizingMaskIntoConstraints = false
		statusCircle.translatesAutoresizingMaskIntoConstraints = false
		messageButton.translatesAutoresizingMaskIntoConstraints = false

		descriptionLabel.font = .systemFont(ofSize: 17, weight: .semibold)
		statusLabel.font = .systemFont(ofSize: 14)
		statusLabel.textColor = .gray

		messageButton.setTitle("⚠️", for: .normal)
		messageButton.contentMode = .center
		messageButton.isPointerInteractionEnabled = true
		messageButton.isHidden = true
		messageButton.addTarget(self, action: #selector(messageButtonTapped), for: .touchUpInside)

		self.contentView.addSubview(descriptionLabel)
		self.contentView.addSubview(statusLabel)
		self.contentView.addSubview(statusCircle)
		self.contentView.addSubview(messageButton)

		descriptionLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
		statusLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
		statusCircle.setContentHuggingPriority(.required, for: .horizontal)

		NSLayoutConstraint.activate([
			descriptionLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 20),
			descriptionLabel.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -5),
			statusLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -20),

			descriptionLabel.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: 20),
			statusLabel.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: 20),

			descriptionLabel.rightAnchor.constraint(equalTo: statusCircle.leftAnchor, constant: -20),
			statusLabel.rightAnchor.constraint(equalTo: statusCircle.leftAnchor, constant: -20),

			statusCircle.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
			statusCircle.widthAnchor.constraint(equalToConstant: 50),
			statusCircle.rightAnchor.constraint(equalTo: self.contentView.rightAnchor),

			messageButton.leftAnchor.constraint(equalTo: statusCircle.leftAnchor),
			messageButton.rightAnchor.constraint(equalTo: statusCircle.rightAnchor),
			messageButton.topAnchor.constraint(equalTo: statusCircle.topAnchor),
			messageButton.bottomAnchor.constraint(equalTo: statusCircle.bottomAnchor)
		])
		
		self.secureView(core: core)
	}

	// MARK: - Message support
	@objc func messageButtonTapped() {
		if let activity = self.activity {
			self.delegate?.showMessage(for: activity)
		}
	}

	// MARK: - Present item
	var activity : OCActivity? {
		didSet {
			if let newActivity = activity {
				updateWith(newActivity)
			}
		}
	}

	func updateWith(_ activity: OCActivity) {
		descriptionLabel.text = activity.localizedDescription
		statusLabel.text = activity.localizedStatusMessage
		statusCircle.progress = activity.progress

		let hasMessage = self.delegate?.hasMessage(for: activity) ?? false

		statusCircle.isHidden = hasMessage
		messageButton.isHidden = !hasMessage

		self.accessoryType = .none
	}

	// MARK: - Themeing
	override func applyThemeCollectionToCellContents(theme: Theme, collection: ThemeCollection) {
		let itemState = ThemeItemState(selected: self.isSelected)

		self.descriptionLabel.applyThemeCollection(collection, itemStyle: .title, itemState: itemState)
		self.statusLabel.applyThemeCollection(collection, itemStyle: .message, itemState: itemState)

//		let moreTitle: NSMutableAttributedString = NSMutableAttributedString(attributedString: self.statusCircle.attributedTitle(for: .normal)!)
//		moreTitle.addAttribute(NSAttributedString.Key.foregroundColor, value: collection.tableRowColors.labelColor, range: NSRange(location:0, length:moreTitle.length))
//		self.statusCircle.setAttributedTitle(moreTitle, for: .normal)
	}
}
