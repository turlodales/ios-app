//
//  NamingViewController.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 02/08/2018.
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

public typealias StringValidatorResult = (Bool, String?, String?) // (validationPassed, validationErrorTitle, validationErrorMessage)
public typealias StringValidatorHandler = (_ stringToCheck: String) -> StringValidatorResult

open class NamingViewController: UIViewController {
	weak open var item: OCItem?
	weak open var core: OCCore?
	open var completion: (String?, NamingViewController) -> Void
	open var stringValidator: StringValidatorHandler?
	open var defaultName: String?
	open var requiredFileExtension: String?

	private var blurView: UIVisualEffectView

	private var stackView: UIStackView

	private var thumbnailContainer: UIView
	private var thumbnailImageView: ResourceViewHost

	private var nameContainer: UIView
	private var nameTextField: ThemeCSSTextField

	private var textfieldTopAnchorConstraint: NSLayoutConstraint
	private var textfieldCenterYAnchorConstraint: NSLayoutConstraint
	private var thumbnailContainerWidthAnchorConstraint: NSLayoutConstraint
	private var thumbnailHeightAnchorConstraint: NSLayoutConstraint

	private var stackViewLeftAnchorConstraint: NSLayoutConstraint?
	private var stackViewRightAnchorConstraint: NSLayoutConstraint?

	private var cancelButton: UIBarButtonItem?
	private var doneButton: UIBarButtonItem?

	private let thumbnailSize = CGSize(width: 150.0, height: 150.0)

	open var fallbackIcon: OCResource?

	public init(with item: OCItem? = nil, core: OCCore? = nil, defaultName: String? = nil, stringValidator: StringValidatorHandler? = nil, fallbackIcon: OCResource? = nil, completion: @escaping (String?, NamingViewController) -> Void) {
		self.item = item
		self.core = core
		self.completion = completion
		self.stringValidator = stringValidator
		self.defaultName = defaultName
		self.fallbackIcon = fallbackIcon

		blurView = UIVisualEffectView(effect: UIBlurEffect(style: Theme.shared.activeCollection.css.getBlurEffectStyle()))

		stackView = UIStackView(frame: .zero)

		thumbnailContainer = UIView(frame: .zero)

		thumbnailImageView = ResourceViewHost()

		nameContainer = UIView(frame: .zero)
		nameTextField = ThemeCSSTextField()
		nameTextField.accessibilityIdentifier = "name-text-field"

		textfieldCenterYAnchorConstraint = nameTextField.centerYAnchor.constraint(equalTo: nameContainer.centerYAnchor)
		textfieldTopAnchorConstraint = nameTextField.topAnchor.constraint(equalTo: nameContainer.topAnchor, constant: 15)
		thumbnailContainerWidthAnchorConstraint = thumbnailContainer.widthAnchor.constraint(equalToConstant: 200)
		thumbnailContainerWidthAnchorConstraint.priority = .init(999)
		thumbnailHeightAnchorConstraint = thumbnailImageView.heightAnchor.constraint(equalToConstant: 150)

		super.init(nibName: nil, bundle: nil)
	}

	convenience public init(with item: OCItem, core: OCCore? = nil, stringValidator: StringValidatorHandler? = nil, fallbackIcon: OCResource? = nil, completion: @escaping (String?, NamingViewController) -> Void) {
		self.init(with: item, core: core, defaultName: nil, stringValidator: stringValidator, fallbackIcon: fallbackIcon, completion: completion)
	}

	convenience public init(with core: OCCore? = nil, defaultName: String, stringValidator: StringValidatorHandler? = nil, fallbackIcon: OCResource? = nil, completion: @escaping (String?, NamingViewController) -> Void) {
		self.init(with: nil, core: core, defaultName: defaultName, stringValidator: stringValidator, fallbackIcon: fallbackIcon, completion: completion)
	}

	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
	}

	override open func viewDidLoad() {
		super.viewDidLoad()

		stackViewLeftAnchorConstraint = stackView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 0)
		stackViewRightAnchorConstraint = stackView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0)

		if let item = item, let core = core {
			nameTextField.text = item.name

			let thumbnailRequest = OCResourceRequestItemThumbnail.request(for: item, maximumSize: thumbnailSize, scale: 0, waitForConnectivity: true, changeHandler: nil)
			thumbnailImageView.request = thumbnailRequest

			core.vault.resourceManager?.start(thumbnailRequest)
		} else {
			nameTextField.text = defaultName
			thumbnailImageView.activeViewProvider = (fallbackIcon as? OCViewProvider) ?? ResourceItemIcon.folder
		}

		// Navigation buttons
		cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
		cancelButton?.accessibilityIdentifier = "cancel-button"
		navigationItem.leftBarButtonItem = cancelButton

		doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
		doneButton?.accessibilityIdentifier = "done-button"
		navigationItem.rightBarButtonItem = doneButton

		//Blur View
		blurView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(blurView)
		NSLayoutConstraint.activate([
			blurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			blurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			blurView.leftAnchor.constraint(equalTo: view.leftAnchor),
			blurView.rightAnchor.constraint(equalTo: view.rightAnchor)
			])

		// Thumbnail image view
		thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
		thumbnailContainer.addSubview(thumbnailImageView)
		NSLayoutConstraint.activate([
			thumbnailHeightAnchorConstraint,
			thumbnailImageView.widthAnchor.constraint(equalTo: thumbnailImageView.heightAnchor),
			thumbnailImageView.centerXAnchor.constraint(equalTo: thumbnailContainer.centerXAnchor),
			thumbnailImageView.centerYAnchor.constraint(equalTo: thumbnailContainer.centerYAnchor)
		])

		// Thumbnail container View
		thumbnailContainer.translatesAutoresizingMaskIntoConstraints = false
		stackView.addArrangedSubview(thumbnailContainer)

		// Name textfield
		nameTextField.translatesAutoresizingMaskIntoConstraints = false
		nameTextField.requiredFileExtension = requiredFileExtension
		nameContainer.addSubview(nameTextField)
		NSLayoutConstraint.activate([
			nameTextField.heightAnchor.constraint(equalToConstant: 40),
			nameTextField.leftAnchor.constraint(equalTo: nameContainer.leftAnchor, constant: 30),
			nameTextField.rightAnchor.constraint(equalTo: nameContainer.rightAnchor, constant: -20)
			])

		nameTextField.delegate = self
		nameTextField.textAlignment = .center
		nameTextField.becomeFirstResponder()
		nameTextField.addTarget(self, action: #selector(textfieldDidChange(_:)), for: .editingChanged)
		nameTextField.enablesReturnKeyAutomatically = true
		nameTextField.autocorrectionType = .no
		nameTextField.borderStyle = .roundedRect
		nameTextField.clearButtonMode = .always
		nameTextField.accessibilityLabel = OCLocalizedString("Folder name", nil)

		// Name container view
		nameContainer.translatesAutoresizingMaskIntoConstraints = false
		stackView.addArrangedSubview(nameContainer)

		// Stack View
		stackView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(stackView)
		NSLayoutConstraint.activate([
			stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
			stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
			stackViewLeftAnchorConstraint!,
			stackViewRightAnchorConstraint!
			])
		render(newTraitCollection: traitCollection)
		stackView.alignment = .fill
	}

	private func render(newTraitCollection: UITraitCollection) {

		switch (newTraitCollection.horizontalSizeClass, newTraitCollection.verticalSizeClass) {
		case (.compact, .regular):
			stackViewLeftAnchorConstraint?.constant = 0
			stackViewRightAnchorConstraint?.constant = 0

			NSLayoutConstraint.deactivate([
				textfieldCenterYAnchorConstraint,
				thumbnailContainerWidthAnchorConstraint
				])

			NSLayoutConstraint.activate([
				textfieldTopAnchorConstraint
				])

			stackView.axis = .vertical
			stackView.distribution = .fillEqually
			self.stackView.transform = CGAffineTransform.identity

		default:

			NSLayoutConstraint.deactivate([
				textfieldTopAnchorConstraint
				])

			NSLayoutConstraint.activate([
				textfieldCenterYAnchorConstraint,
				thumbnailContainerWidthAnchorConstraint
				])
			stackView.axis = .horizontal
			stackView.distribution = .fill
		}

		switch (newTraitCollection.horizontalSizeClass, newTraitCollection.verticalSizeClass) {
		case (.regular, .regular):
			stackViewLeftAnchorConstraint?.constant = 100
			stackViewRightAnchorConstraint?.constant = -100
			thumbnailHeightAnchorConstraint.constant = 150

			// Tweak for small PPI devices
			if UIDevice.current.userInterfaceIdiom == .phone && UIScreen.main.nativeBounds.height == 1136 {
				thumbnailHeightAnchorConstraint.constant = 100
			}

		case (.compact, .compact):
			thumbnailHeightAnchorConstraint.constant = 100
			stackViewLeftAnchorConstraint?.constant = 0
			stackViewRightAnchorConstraint?.constant = 0

			// Tweak for small PPI devices
			if UIDevice.current.userInterfaceIdiom == .phone && UIScreen.main.nativeBounds.height == 1136 {
				thumbnailHeightAnchorConstraint.constant = 80
			}

		default:
			stackViewLeftAnchorConstraint?.constant = 0
			stackViewRightAnchorConstraint?.constant = 0
			thumbnailHeightAnchorConstraint.constant = 150

			// Tweak for small PPI devices
			if UIDevice.current.userInterfaceIdiom == .phone && UIScreen.main.nativeBounds.height == 1136 {
				thumbnailHeightAnchorConstraint.constant = 100
			}
		}
	}

	override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)

		render(newTraitCollection: traitCollection)
	}

	@objc private func cancelButtonPressed() {
		nameTextField.resignFirstResponder()
		self.dismiss(animated: true) {
			self.completion(nil, self)
		}
	}

	@objc open func textfieldDidChange(_ sender: UITextField) {
		let filename = sender.text

		if filename != "", requiredFileExtension == nil || ((requiredFileExtension != nil) && filename != ".\(requiredFileExtension!)") {
			doneButton?.isEnabled = true
		} else {
			doneButton?.isEnabled = false
		}
	}

	@objc private func doneButtonPressed() {

		if let item = item, self.nameTextField.text == item.name {
			nameTextField.resignFirstResponder()
			self.dismiss(animated: true) {
				self.completion(nil, self)
			}
		} else {
			if let stringValidator = self.stringValidator {
				let (validationPassed, validationErrorTitle, validationErrorMessage) = stringValidator(nameTextField.text!)

				if validationPassed {
					nameTextField.resignFirstResponder()
					self.dismiss(animated: true) {
						self.completion(self.nameTextField.text!, self)
					}
				} else {
					let controller = ThemedAlertController(title: validationErrorTitle ?? OCLocalizedString("Forbidden Characters", nil), message: validationErrorMessage, preferredStyle: .alert)
					controller.view.accessibilityIdentifier = "forbidden-characters-alert"
					let okAction = UIAlertAction(title: OCLocalizedString("OK", nil), style: .default)
					controller.addAction(okAction)
					self.present(controller, animated: true)
				}
			} else {
				nameTextField.resignFirstResponder()
				self.dismiss(animated: true) {
					self.completion(self.nameTextField.text!, self)
				}
			}
		}
	}

	@objc open func keyboardWillShow(notification: NSNotification) {
		if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
			if self.view.frame.origin.y == 0 {
				// TODO: Improve this for center the stackview with the keyboard not only when the keyboard partialy cover the thumbnailImage
				let thumbnailImageMaxY = self.view.convert(self.thumbnailImageView.frame, from:stackView).maxY
				let thumbnailTopSpace = self.view.convert(self.thumbnailImageView.frame, from:stackView).minY - self.navigationController!.navigationBar.frame.maxY
				let keyboardY = self.view.frame.height - keyboardSize.height
				let firstYTranslation = thumbnailImageMaxY  - (keyboardY)
				let finalYTranslation = firstYTranslation + ((thumbnailTopSpace - firstYTranslation) / 2)

				// if the keyboard is above the thumbnailView
				if thumbnailImageMaxY >= keyboardY {
					let animation = UIViewPropertyAnimator(duration: 0.7, dampingRatio: 1.0) {
						self.stackView.transform = CGAffineTransform.init(translationX: 0, y: -(finalYTranslation))
					}
					animation.startAnimation()
				}
			}
		}
	}

	override open func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardDidShowNotification, object: nil)
	}

}

extension NamingViewController: UITextFieldDelegate {
	open func textFieldDidBeginEditing(_ textField: UITextField) {

		if let name = nameTextField.text,
			let fileExtension = item?.fileExtension,
			let range = name.range(of: ".\(fileExtension)"),
			let position: UITextPosition = nameTextField.position(from: nameTextField.beginningOfDocument, offset: range.lowerBound.utf16Offset(in: name)) {

			textField.selectedTextRange = nameTextField.textRange(from: nameTextField.beginningOfDocument, to:position)

		} else if let name = textField.text,
		  	  let range = name.range(of: ".", options: .backwards),
			  let position: UITextPosition = nameTextField.position(from: nameTextField.beginningOfDocument, offset: range.lowerBound.utf16Offset(in: name)) {
			textField.selectedTextRange = nameTextField.textRange(from: nameTextField.beginningOfDocument, to:position)
		} else {
			textField.selectedTextRange = nameTextField.textRange(from: nameTextField.beginningOfDocument, to: nameTextField.endOfDocument)
		}
	}

	public func textFieldShouldClear(_ textField: UITextField) -> Bool {
		if let requiredFileExtension {
			textField.text = "." + requiredFileExtension
			textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.beginningOfDocument)
			return false
		}
		return true
	}

	open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField.text == "" {
			return false
		}
		doneButtonPressed()
		return true
	}
}
