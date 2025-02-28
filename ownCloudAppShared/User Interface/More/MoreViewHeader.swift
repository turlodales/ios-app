//
//  MoreViewHeader.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 17/08/2018.
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

open class MoreViewHeader: UIView {
	private var iconView: ResourceViewHost
	private var labelContainerView : UIView
	private var titleLabel: UILabel
	private var detailLabel: UILabel
	private var favoriteButton: UIButton
	public var activityIndicator : UIActivityIndicatorView

	public var thumbnailSize = CGSize(width: 60, height: 60)
	public let favoriteSize = CGSize(width: 44, height: 44)

	public var showFavoriteButton: Bool
	public var showActivityIndicator: Bool
	public var adaptBackgroundColor : Bool

	public var item: OCItem
	public weak var core: OCCore?
	public var url: URL?

	public init(for item: OCItem, with core: OCCore, favorite: Bool = true, adaptBackgroundColor: Bool = false, showActivityIndicator: Bool = false) {
		self.item = item
		self.core = core
		self.showFavoriteButton = favorite && core.bookmark.hasCapability(.favorites)
		self.showActivityIndicator = showActivityIndicator

		iconView = ResourceViewHost()
		titleLabel = UILabel()
		detailLabel = UILabel()
		labelContainerView = UIView()
		favoriteButton = UIButton()
		activityIndicator = UIActivityIndicatorView(style: .medium)
		self.adaptBackgroundColor = adaptBackgroundColor

		super.init(frame: .zero)

		self.translatesAutoresizingMaskIntoConstraints = false

		render()
	}

	public init(url : URL) {
		self.showFavoriteButton = false
		self.showActivityIndicator = false
		self.adaptBackgroundColor = false
		self.item = OCItem()
		self.url = url

		iconView = ResourceViewHost()
		titleLabel = UILabel()
		detailLabel = UILabel()
		labelContainerView = UIView()
		favoriteButton = UIButton()
		activityIndicator = UIActivityIndicatorView(style: .medium)

		super.init(frame: .zero)

		self.translatesAutoresizingMaskIntoConstraints = false

		render()
	}

	deinit {
		Theme.shared.unregister(client: self)
	}

	private func render() {
		cssSelectors = [.more, .header]

		let contentContainerView = UIView()
		contentContainerView.translatesAutoresizingMaskIntoConstraints = false

		let wrappedContentContainerView = contentContainerView.withScreenshotProtection
		self.addSubview(wrappedContentContainerView)

		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		detailLabel.translatesAutoresizingMaskIntoConstraints = false
		iconView.translatesAutoresizingMaskIntoConstraints = false
		labelContainerView.translatesAutoresizingMaskIntoConstraints = false
		favoriteButton.translatesAutoresizingMaskIntoConstraints = false
		activityIndicator.translatesAutoresizingMaskIntoConstraints = false
		iconView.contentMode = .scaleAspectFit

		titleLabel.font = UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.semibold)
		detailLabel.font = UIFont.systemFont(ofSize: 14)

		labelContainerView.addSubview(titleLabel)
		labelContainerView.addSubview(detailLabel)

		titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
		detailLabel.setContentCompressionResistancePriority(.required, for: .vertical)
		labelContainerView.setContentCompressionResistancePriority(.required, for: .vertical)

		NSLayoutConstraint.activate([
			wrappedContentContainerView.topAnchor.constraint(equalTo: self.topAnchor),
			wrappedContentContainerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
			wrappedContentContainerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
			wrappedContentContainerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

			titleLabel.leadingAnchor.constraint(equalTo: labelContainerView.leadingAnchor),
			titleLabel.trailingAnchor.constraint(equalTo: labelContainerView.trailingAnchor),
			titleLabel.topAnchor.constraint(equalTo: labelContainerView.topAnchor),

			detailLabel.leadingAnchor.constraint(equalTo: labelContainerView.leadingAnchor),
			detailLabel.trailingAnchor.constraint(equalTo: labelContainerView.trailingAnchor),
			detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
			detailLabel.bottomAnchor.constraint(equalTo: labelContainerView.bottomAnchor)
		])

		contentContainerView.addSubview(iconView)
		contentContainerView.addSubview(labelContainerView)

		NSLayoutConstraint.activate([
			iconView.widthAnchor.constraint(equalToConstant: thumbnailSize.width),
			iconView.heightAnchor.constraint(equalToConstant: thumbnailSize.height),

			iconView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: 20),
			iconView.topAnchor.constraint(equalTo: self.topAnchor, constant: 20),
			iconView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20).with(priority: .defaultHigh),

			labelContainerView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 15),
			labelContainerView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
			labelContainerView.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor, constant: 20),
			labelContainerView.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor, constant: -20).with(priority: .defaultHigh)
		])

		if showFavoriteButton {
			updateFavoriteButtonImage()
			favoriteButton.addTarget(self, action: #selector(toogleFavoriteState), for: UIControl.Event.touchUpInside)
			contentContainerView.addSubview(favoriteButton)
			favoriteButton.isPointerInteractionEnabled = true

			NSLayoutConstraint.activate([
				favoriteButton.widthAnchor.constraint(equalToConstant: favoriteSize.width),
				favoriteButton.heightAnchor.constraint(equalToConstant: favoriteSize.height),
				favoriteButton.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -10),
				favoriteButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
				favoriteButton.leadingAnchor.constraint(equalTo: labelContainerView.trailingAnchor, constant: 10)
				])
		} else if showActivityIndicator {
			contentContainerView.addSubview(activityIndicator)

			NSLayoutConstraint.activate([
				activityIndicator.centerYAnchor.constraint(equalTo: self.centerYAnchor),
				activityIndicator.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -15),
				activityIndicator.leadingAnchor.constraint(equalTo: labelContainerView.trailingAnchor, constant: 10)
				])
		} else {
			NSLayoutConstraint.activate([
				labelContainerView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -20)
			])
		}

		if let url = url {
			titleLabel.attributedText = NSAttributedString(string: url.lastPathComponent, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .semibold)])

			do {
				let attr = try FileManager.default.attributesOfItem(atPath: url.path)

				if let fileSize = attr[FileAttributeKey.size] as? UInt64 {
					let byteCountFormatter = ByteCountFormatter()
					byteCountFormatter.countStyle = .file
					let size = byteCountFormatter.string(fromByteCount: Int64(fileSize))

					detailLabel.attributedText =  NSAttributedString(string: size, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14, weight: .regular)])
				}
			} catch {
				print("Error: \(error)")
			}
		} else {
			var itemName = item.name

			if item.isRoot {
				if let core, core.useDrives, let driveID = item.driveID {
					if let drive = core.drive(withIdentifier: driveID, attachedOnly: false) {
						itemName = drive.name
					}
				} else {
					itemName = OCLocalizedString("Files", nil)
				}
			}

			titleLabel.attributedText = NSAttributedString(string: itemName?.redacted() ?? "", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .semibold)])

			let byteCountFormatter = ByteCountFormatter()
			byteCountFormatter.countStyle = .file
			var size = byteCountFormatter.string(fromByteCount: Int64(item.size))

			if item.size < 0 {
				size = OCLocalizedString("Pending", nil)
			}

			let dateString = item.lastModifiedLocalized

			let detail = size + " - " + dateString

			detailLabel.attributedText =  NSAttributedString(string: detail, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14, weight: .regular)])
		}

		let iconRequest = OCResourceRequestItemThumbnail.request(for: item, maximumSize: thumbnailSize, scale: 0, waitForConnectivity: true, changeHandler: nil)
		self.iconView.request = iconRequest
		core?.vault.resourceManager?.start(iconRequest)

		titleLabel.numberOfLines = 0

		self.secureView(core: core)
	}

	public func updateHeader(title: String, subtitle: String) {
		titleLabel.text = title.redacted()
		detailLabel.text = subtitle.redacted()
	}

	public required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc public func toogleFavoriteState() {
		if item.isFavorite == true {
			item.isFavorite = false
		} else {
			item.isFavorite = true
		}
		self.updateFavoriteButtonImage()
		core?.update(item, properties: [OCItemPropertyName.isFavorite], options: nil, resultHandler: { (error, _, _, _) in
			if error == nil {
				OnMainThread {
					self.updateFavoriteButtonImage()
				}
			}
		})
	}

	public func updateFavoriteButtonImage() {
		if item.isFavorite == true {
			favoriteButton.cssSelectors = [.favorite]
			favoriteButton.setImage(UIImage(named: "star"), for: .normal)
			favoriteButton.accessibilityLabel = OCLocalizedString("Unfavorite item", nil)
		} else {
			favoriteButton.cssSelectors = [.disabled, .favorite]
			favoriteButton.setImage(UIImage(named: "unstar"), for: .normal)
			favoriteButton.accessibilityLabel = OCLocalizedString("Favorite item", nil)
		}

		favoriteButton.tintColor = Theme.shared.activeCollection.css.getColor(.stroke, for: favoriteButton)
	}

	private var _hasRegistered = false
	open override func didMoveToWindow() {
		super.didMoveToWindow()

		if window != nil, !_hasRegistered {
			_hasRegistered = true
			Theme.shared.register(client: self)
		}
	}
}

extension MoreViewHeader: Themeable {
	public func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		titleLabel.applyThemeCollection(collection)
		detailLabel.applyThemeCollection(collection, itemStyle: .message)
		activityIndicator.style = collection.css.getActivityIndicatorStyle(for: activityIndicator) ?? .medium

		if adaptBackgroundColor {
			backgroundColor = collection.css.getColor(.fill, for: self)
		}

		updateFavoriteButtonImage()
	}
}
