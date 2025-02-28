//
//  AlertView.swift
//  ownCloud
//
//  Created by Felix Schwarz on 26.03.20.
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

open class AlertOption : NSObject {
	public typealias ChoiceHandler = (_: AlertView, _: AlertOption) -> Void

	public var label : String
	public var handler : ChoiceHandler
	public var type : OCIssueChoiceType
	public var accessibilityIdentifier : String?

	public init(label: String, type: OCIssueChoiceType, accessibilityIdentifier : String? = nil, handler: @escaping ChoiceHandler) {
		self.label = label
		self.type = type
		self.handler = handler
		self.accessibilityIdentifier = accessibilityIdentifier

		super.init()
	}
}

open class AlertView: ThemeCSSView {
	public var localizedHeader : String?

	public var localizedTitle : String
	public var localizedDescription : String

	public var options : [AlertOption]

	public var headerLabel : ThemeCSSLabel = ThemeCSSLabel()
	public var headerContainer : ThemeCSSView = ThemeCSSView(withSelectors: [.header])

	public var titleLabel : UILabel = ThemeCSSLabel(withSelectors: [.title])
	public var descriptionLabel : UILabel = ThemeCSSLabel(withSelectors: [.description])
	public var optionStackView : UIStackView?

	public var optionViews : [ThemeButton] = []

	public var textAlignment : NSTextAlignment

	public init(localizedHeader: String? = nil, localizedTitle: String, localizedDescription: String, contentPadding: CGFloat = 20, textAlignment : NSTextAlignment = .left, options: [AlertOption]) {
		self.localizedHeader = localizedHeader
		self.localizedTitle = localizedTitle
		self.localizedDescription = localizedDescription
		self.options = options
		self.contentPadding = contentPadding
		self.textAlignment = textAlignment

		super.init(frame: .zero)

		self.cssSelector = .alert

		prepareViewAndConstraints()
	}

	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public func createOptionViews() {
		var optionIdx : Int = 0

		for option in options {
			var cssSelector: ThemeCSSSelector

			switch option.type {
				case .cancel:
					cssSelector = .cancel

				case .destructive:
					cssSelector = .destructive

				case .regular, .default:
					cssSelector = .confirm
			}

			let optionButton = ThemeButton(withSelectors: [cssSelector])

			optionButton.setTitle(option.label, for: .normal)
			optionButton.tag = optionIdx
			optionButton.translatesAutoresizingMaskIntoConstraints = false
			optionButton.accessibilityIdentifier = option.accessibilityIdentifier

			optionButton.setContentHuggingPriority(.required, for: .vertical)
			optionButton.setContentCompressionResistancePriority(.required, for: .vertical)

			optionButton.addTarget(self, action: #selector(optionSelected(sender:)), for: .primaryActionTriggered)

			optionViews.append(optionButton)

			optionIdx += 1
		}
	}

	@objc public func optionSelected(sender: ThemeButton) {
		let option = options[sender.tag]

		self.selectOption(option: option)
	}

	public func selectOption(option: AlertOption) {
		option.handler(self, option)
	}

	private let headerTextHorizontalInset : CGFloat = 20
	private let headerTextVerticalInset : CGFloat = 7
	private let titleAndDescriptionSpacing : CGFloat = 5
	private var contentPadding : CGFloat = 20
	private let optionInnerSpacing : CGFloat = 10

	private let headerLabelFontSize : CGFloat = 14
	private let titleLabelFontSize : CGFloat = 17
	private let descriptionLabelFontSize : CGFloat = 14

	public func prepareViewAndConstraints() {
		headerLabel.numberOfLines = 1
		headerLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.numberOfLines = 0
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		descriptionLabel.numberOfLines = 0
		descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

		headerLabel.text = localizedHeader
		titleLabel.text = localizedTitle
		descriptionLabel.text = localizedDescription

		headerLabel.textAlignment = textAlignment
		titleLabel.textAlignment = textAlignment
		descriptionLabel.textAlignment = textAlignment

		headerLabel.font = .systemFont(ofSize: headerLabelFontSize, weight: .regular)
		headerLabel.textColor = .gray

		titleLabel.font = .systemFont(ofSize: titleLabelFontSize, weight: .semibold)

		descriptionLabel.font = .systemFont(ofSize: descriptionLabelFontSize)
		descriptionLabel.textColor = .gray

		createOptionViews()
		optionStackView = UIStackView(arrangedSubviews: optionViews)
		guard let optionStackView = optionStackView else { return }
		optionStackView.translatesAutoresizingMaskIntoConstraints = false

		optionStackView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
		optionStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		optionStackView.setContentHuggingPriority(.required, for: .vertical)
		optionStackView.setContentHuggingPriority(.required, for: .horizontal)
		optionStackView.distribution = .fillEqually
		optionStackView.axis = .horizontal
		optionStackView.spacing = optionInnerSpacing

		self.setContentCompressionResistancePriority(.required, for: .vertical)
		self.setContentHuggingPriority(.required, for: .vertical)

		self.addSubview(titleLabel)
		self.addSubview(descriptionLabel)
		self.addSubview(optionStackView)

		headerLabel.setContentHuggingPriority(.required, for: .vertical)
		titleLabel.setContentHuggingPriority(.required, for: .vertical)
		descriptionLabel.setContentHuggingPriority(.required, for: .vertical)

		headerLabel.setContentCompressionResistancePriority(.required, for: .vertical)
		titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
		descriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)

		let enclosure = self.safeAreaLayoutGuide

		if localizedHeader != nil {
			headerContainer.translatesAutoresizingMaskIntoConstraints = false
			headerContainer.setContentCompressionResistancePriority(.required, for: .vertical)
			headerContainer.setContentHuggingPriority(.required, for: .vertical)

			headerContainer.addSubview(headerLabel)
			self.addSubview(headerContainer)

			NSLayoutConstraint.activate([
				headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: headerTextHorizontalInset),
				headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -headerTextHorizontalInset),
				headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: headerTextVerticalInset),
				headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -headerTextVerticalInset),

				headerContainer.topAnchor.constraint(equalTo: enclosure.topAnchor),
				headerContainer.leadingAnchor.constraint(equalTo: enclosure.leadingAnchor),
				headerContainer.trailingAnchor.constraint(equalTo: enclosure.trailingAnchor)
			])
		}

		if localizedHeader == nil, localizedTitle == "", localizedDescription == "" {
			titleLabel.removeFromSuperview()
			descriptionLabel.removeFromSuperview()

			NSLayoutConstraint.activate([
				optionStackView.topAnchor.constraint(equalTo: enclosure.topAnchor, constant: contentPadding),
				optionStackView.bottomAnchor.constraint(equalTo: enclosure.bottomAnchor, constant: -contentPadding),

				optionStackView.leadingAnchor.constraint(equalTo: enclosure.leadingAnchor, constant: contentPadding),
				optionStackView.trailingAnchor.constraint(equalTo: enclosure.trailingAnchor, constant: -contentPadding)
			])
		} else {
			NSLayoutConstraint.activate([
				titleLabel.topAnchor.constraint(equalTo: ((localizedHeader != nil) ? headerContainer.bottomAnchor : enclosure.topAnchor), constant: contentPadding),
				titleLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor, constant: -titleAndDescriptionSpacing),
				descriptionLabel.bottomAnchor.constraint(equalTo: optionStackView.topAnchor, constant: -contentPadding),
				optionStackView.bottomAnchor.constraint(equalTo: enclosure.bottomAnchor, constant: -contentPadding),

				titleLabel.leadingAnchor.constraint(equalTo: enclosure.leadingAnchor, constant: contentPadding),
				titleLabel.trailingAnchor.constraint(equalTo: enclosure.trailingAnchor, constant: -contentPadding),

				descriptionLabel.leadingAnchor.constraint(equalTo: enclosure.leadingAnchor, constant: contentPadding),
				descriptionLabel.trailingAnchor.constraint(equalTo: enclosure.trailingAnchor, constant: -contentPadding),

				optionStackView.leadingAnchor.constraint(equalTo: enclosure.leadingAnchor, constant: contentPadding),
				optionStackView.trailingAnchor.constraint(equalTo: enclosure.trailingAnchor, constant: -contentPadding)
			])
		}
	}
}
