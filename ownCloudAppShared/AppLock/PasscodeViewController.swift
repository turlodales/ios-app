//
//  PasscodeViewController.swift
//  ownCloud
//
//  Created by Javier Gonzalez on 03/05/2018.
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
import ownCloudApp
import LocalAuthentication

public typealias PasscodeViewControllerCancelHandler = ((_ passcodeViewController: PasscodeViewController) -> Void)
public typealias PasscodeViewControllerBiometricalHandler = ((_ passcodeViewController: PasscodeViewController) -> Void)
public typealias PasscodeViewControllerCompletionHandler = ((_ passcodeViewController: PasscodeViewController, _ passcode: String) -> Void)

public class PasscodeViewController: UIViewController, Themeable {

	// MARK: - Constants
	fileprivate var passCodeCompletionDelay: TimeInterval = 0.1

	// MARK: - Views
	@IBOutlet private var messageLabel: UILabel?
	@IBOutlet private var errorMessageLabel: UILabel?
	@IBOutlet private var passcodeLabel: UILabel?
	@IBOutlet private var timeoutMessageLabel: UILabel?

	@IBOutlet private var lockscreenContainerView : UIView?
	@IBOutlet private var backgroundBlurView : UIVisualEffectView?

	@IBOutlet private var keypadContainerView : UIView?
	@IBOutlet private var keypadButtons: [ThemeRoundedButton]?
	@IBOutlet private var deleteButton: ThemeButton?
	@IBOutlet public var cancelButton: ThemeButton?
	@IBOutlet public var biometricalButton: ThemeButton?
	@IBOutlet public var compactHeightPasscodeTextField: UITextField?

	// MARK: - Properties
	private var passcodeLength: Int

	public var passcode: String? {
		didSet {
			self.updatePasscodeDots()
		}
	}

	public var message: String? {
		didSet {
			self.messageLabel?.text = message ?? " "
		}
	}

	public var errorMessage: String? {
		didSet {
			self.errorMessageLabel?.text = errorMessage ?? " "

			if errorMessage != nil {
				self.passcodeLabel?.shakeHorizontally()
			}
		}
	}

	var timeoutMessage: String? {
		didSet {
			self.timeoutMessageLabel?.text = timeoutMessage ?? ""
		}
	}

	var screenBlurringEnabled : Bool {
		didSet {
			self.backgroundBlurView?.isHidden = !screenBlurringEnabled
			self.lockscreenContainerView?.isHidden = screenBlurringEnabled
		}
	}

	var keypadButtonsEnabled: Bool {
		didSet {
			if let buttons = self.keypadButtons {
				for button in buttons {
					button.isEnabled = keypadButtonsEnabled
					button.alpha = keypadButtonsEnabled ? 1.0 : (keypadButtonsHidden ? 1.0 : 0.5)
				}
			}

			if keypadButtonsEnabled {
				self.cssSelectors = [ .modal, .passcode ]
			} else {
				self.cssSelectors = [ .modal, .passcode, .disabled ]
			}

			self.applyThemeCollection(theme: Theme.shared, collection: Theme.shared.activeCollection, event: .update)
		}
	}

	var keypadButtonsHidden : Bool {
		didSet {
			keypadContainerView?.isUserInteractionEnabled = !keypadButtonsHidden

			if oldValue != keypadButtonsHidden {
				updateKeypadButtons()
			}
		}
	}

	var cancelButtonAvailable: Bool {
		didSet {
			cancelButton?.isEnabled = cancelButtonAvailable
			cancelButton?.isHidden = !cancelButtonAvailable
		}
	}

	var biometricalButtonHidden: Bool = false {
		didSet {
			biometricalButton?.isEnabled = !biometricalButtonHidden
			biometricalButton?.isHidden = biometricalButtonHidden

			if let biometricalImage = LAContext().biometricsAuthenticationImage() {
				biometricalButton?.setImage(biometricalImage, for: .normal)
			}
		}
	}

	var hasCompactHeight: Bool {
		if self.traitCollection.verticalSizeClass == .compact {
			return true
		}

		return false
	}

	// MARK: - Handlers
	public var cancelHandler: PasscodeViewControllerCancelHandler?
	public var biometricalHandler: PasscodeViewControllerBiometricalHandler?
	public var completionHandler: PasscodeViewControllerCompletionHandler?

	// MARK: - Init
	public init(cancelHandler: PasscodeViewControllerCancelHandler? = nil, biometricalHandler: PasscodeViewControllerBiometricalHandler? = nil, completionHandler: @escaping PasscodeViewControllerCompletionHandler, hasCancelButton: Bool = true, keypadButtonsEnabled: Bool = true, requiredLength: Int) {
		self.cancelHandler = cancelHandler
		self.biometricalHandler = biometricalHandler
		self.completionHandler = completionHandler
		self.keypadButtonsEnabled = keypadButtonsEnabled
		self.cancelButtonAvailable = hasCancelButton
		self.keypadButtonsHidden = false
		self.screenBlurringEnabled = false
		self.passcodeLength = requiredLength

		super.init(nibName: "PasscodeViewController", bundle: Bundle(for: PasscodeViewController.self))

		self.cssSelector = .passcode

		self.modalPresentationStyle = .fullScreen
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - View Controller Events
	public override func viewDidLoad() {
		super.viewDidLoad()

		self.title = VendorServices.shared.appName
		self.cancelButton?.setTitle(OCLocalizedString("Cancel", nil), for: .normal)
		self.cancelButton?.cssSelector =  .cancel

		self.messageLabel?.cssSelector = .title
		self.passcodeLabel?.cssSelector = .code
		self.errorMessageLabel?.cssSelector = .subtitle
		self.timeoutMessageLabel?.cssSelectors = [.title, .timeout]

		self.message = { self.message }()
		self.errorMessage = { self.errorMessage }()
		self.timeoutMessage = { self.timeoutMessage }()

		self.cancelButtonAvailable = { self.cancelButtonAvailable }()
		self.keypadButtonsEnabled = { self.keypadButtonsEnabled }()
		self.keypadButtonsHidden = { self.keypadButtonsHidden }()
		self.screenBlurringEnabled = { self.screenBlurringEnabled }()
		self.errorMessageLabel?.minimumScaleFactor = 0.5
		self.errorMessageLabel?.adjustsFontSizeToFitWidth = true
		self.biometricalButtonHidden = (!AppLockSettings.shared.biometricalSecurityEnabled || !AppLockSettings.shared.lockEnabled || cancelButtonAvailable) // cancelButtonAvailable is true for setup tasks/settings changes only
		updateKeypadButtons()
		if let biometricalSecurityName = LAContext().supportedBiometricsAuthenticationName() {
			self.biometricalButton?.accessibilityLabel = biometricalSecurityName
		}

		if let keypadButtons {
			let keypadFont = UIFont.systemFont(ofSize: 34)

			for button in keypadButtons {
				if button != deleteButton, button != biometricalButton {
					button.cssSelector = .digit
				}

				button.buttonFont = keypadFont

				PointerEffect.install(on: button, effectStyle: .highlight)
			}

			deleteButton?.cssSelector = .backspace
			biometricalButton?.cssSelector = .biometrical
		}
		PointerEffect.install(on: cancelButton!, effectStyle: .highlight)
		PointerEffect.install(on: deleteButton!, effectStyle: .highlight)
		PointerEffect.install(on: biometricalButton!, effectStyle: .highlight)
	}

	public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		self.keypadContainerView?.isHidden = true
		self.compactHeightPasscodeTextField?.resignFirstResponder()

		super.viewWillTransition(to: size, with: coordinator)
		coordinator.animate(alongsideTransition: nil) { _ in
			self.updateKeypadButtons()
		}
	}

	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		Theme.shared.register(client: self)

		self.updatePasscodeDots()
	}

	public override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		Theme.shared.unregister(client: self)
	}

	// MARK: - UI updates

	private func updateKeypadButtons() {
		if keypadButtonsHidden {
			self.compactHeightPasscodeTextField?.resignFirstResponder()
			UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
				self.keypadContainerView?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
				self.keypadContainerView?.alpha = 0
			}, completion: { (_) in
				self.keypadContainerView?.isHidden = self.keypadButtonsHidden
			})
		} else {
			if !self.hasCompactHeight {
				self.keypadContainerView?.isHidden = self.keypadButtonsHidden
				self.compactHeightPasscodeTextField?.resignFirstResponder()

				UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
					self.keypadContainerView?.transform = .identity
					self.keypadContainerView?.alpha = 1
				}, completion: nil)
			} else {
				self.keypadContainerView?.isHidden = true
				self.compactHeightPasscodeTextField?.becomeFirstResponder()
			}
		}
	}

	private func updatePasscodeDots() {
		var placeholders = ""
		let enteredDigits = passcode?.count ?? 0

		for index in 1...passcodeLength {
			if index > 1 {
				placeholders += "  "
			}
			if index <= enteredDigits {
				placeholders += "●"
			} else {
				placeholders += "○"
			}
		}

		self.compactHeightPasscodeTextField?.text = passcode
		self.passcodeLabel?.text = placeholders
	}

	// MARK: - Actions
	@IBAction func appendDigit(_ sender: UIButton) {
		appendDigit(digit: String(sender.tag))
	}

	public func appendDigit(digit: String) {
		if !keypadButtonsEnabled || keypadButtonsHidden {
			return
		}

		if let currentPasscode = passcode {
			// Enforce length limit
			if currentPasscode.count < passcodeLength {
				self.passcode = currentPasscode + digit
			}
		} else {
			self.passcode = digit
		}

		// Check if passcode is complete
		if let enteredPasscode = passcode {
			if enteredPasscode.count == passcodeLength {
				// Delay to give feedback to user after the last digit was added
				OnMainThread(after: passCodeCompletionDelay) {
					self.completionHandler?(self, enteredPasscode)
				}
			}
		}
	}

	@IBAction func deleteLastDigit(_ sender: UIButton) {
		deleteLastDigit()
	}

	public func deleteLastDigit() {
		if passcode != nil, passcode!.count > 0 {
			passcode?.removeLast()
			updatePasscodeDots()
		}
	}

	@IBAction func cancel(_ sender: UIButton) {
		cancelHandler?(self)
	}

	@IBAction func biometricalAction(_ sender: UIButton) {
		biometricalHandler?(self)
	}

	// MARK: - Themeing
	public override var preferredStatusBarStyle : UIStatusBarStyle {
		if VendorServices.shared.isBranded {
			return .darkContent
		}

		return Theme.shared.activeCollection.css.getStatusBarStyle(for: self) ?? .default
	}

	open func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		lockscreenContainerView?.apply(css: collection.css, properties: [.fill])

		messageLabel?.applyThemeCollection(collection, itemStyle: .title, itemState: keypadButtonsEnabled ? .normal : .disabled)

		messageLabel?.apply(css: collection.css, properties: [.stroke])
		errorMessageLabel?.apply(css: collection.css, properties: [.stroke])
		passcodeLabel?.apply(css: collection.css, properties: [.stroke])
		timeoutMessageLabel?.apply(css: collection.css, properties: [.stroke])
	}
}

extension PasscodeViewController: UITextFieldDelegate {
	open func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

		if range.length > 0 {
			deleteLastDigit()
		} else {
			appendDigit(digit: string)
		}

		return false
	}
}

extension ThemeCSSSelector {
	static let passcode = ThemeCSSSelector(rawValue: "passcode")
	static let digit = ThemeCSSSelector(rawValue: "digit")
	static let code = ThemeCSSSelector(rawValue: "code")
	static let backspace = ThemeCSSSelector(rawValue: "backspace")
	static let biometrical = ThemeCSSSelector(rawValue: "biometrical")
	static let timeout = ThemeCSSSelector(rawValue: "timeout")
}
