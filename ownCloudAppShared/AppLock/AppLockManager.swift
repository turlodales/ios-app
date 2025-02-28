//
//  AppLockManager.swift
//  ownCloud
//
//  Created by Javier Gonzalez on 06/05/2018.
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
import ownCloudApp
import LocalAuthentication

public class AppLockManager: NSObject {

	// MARK: - UI
	private var userDefaults: UserDefaults

	// MARK: - Availability
	public static var supportedOnDevice : Bool {
		if #available(iOS 14, *), ProcessInfo.processInfo.isiOSAppOnMac {
			return false
		}

		return true
	}

	// MARK: - State
	private var lastApplicationBackgroundedDate : Date? {
		get {
			if let archivedData = keychain?.readDataFromKeychainItem(forAccount: keychainAccount, path: keychainLockedDate) {
				guard let value = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: archivedData) else { return nil }
				return value as Date
			}

			return nil
		}
		set(newValue) {
			if let date = newValue {
				let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: date as NSDate, requiringSecureCoding: true)
				keychain?.write(archivedData, toKeychainItemForAccount: keychainAccount, path: keychainLockedDate)
			} else {
				_ = keychain?.removeItem(forAccount: keychainAccount, path: keychainLockedDate)
			}
		}
	}

	public var unlocked: Bool {
		get {
			if let archivedData = keychain?.readDataFromKeychainItem(forAccount: keychainAccount, path: keychainUnlocked) {
				guard let value = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSNumber.self, from: archivedData)?.boolValue else { return false}
				return value
			}

			return false
		}
		set(newValue) {
			let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: newValue as NSNumber, requiringSecureCoding: true)
			keychain?.write(archivedData, toKeychainItemForAccount: keychainAccount, path: keychainUnlocked)
		}
	}

	public static var isPassCodeEnabled : Bool {
		let defaults = OCAppIdentity.shared.userDefaults

		if let applockEnabled = defaults?.bool(forKey: "applock-lock-enabled") {
			return applockEnabled
		}

		return false
	}

	private var failedPasscodeAttempts: Int {
		get {
			return userDefaults.integer(forKey: "applock-failed-passcode-attempts")
		}
		set(newValue) {
			userDefaults.set(newValue, forKey: "applock-failed-passcode-attempts")

			if newValue == 0 {
				removeLockCountdown()
			} else if newValue > maximumToleratedFailedPasscodeAttempts {
				resetAndStartLockCountdown()
			}
		}
	}
	private var lockedSinceDate: Date? {
		get {
			return userDefaults.object(forKey: "applock-locked-since-date") as? Date
		}
		set(newValue) {
			userDefaults.set(newValue, forKey: "applock-locked-since-date")
		}
	}
	private var lockedSinceSystemUptime: TimeInterval? {
		get {
			return userDefaults.object(forKey: "applock-locked-since-system-uptime") as? TimeInterval
		}
		set(newValue) {
			userDefaults.set(newValue, forKey: "applock-locked-since-system-uptime")
		}
	}
	private var lockedUntilDate: Date? {
		get {
			return userDefaults.object(forKey: "applock-locked-until-date") as? Date
		}
		set(newValue) {
			userDefaults.set(newValue, forKey: "applock-locked-until-date")
		}
	}
	private var lockTimeoutDuration: TimeInterval {
		if failedPasscodeAttempts < maximumToleratedFailedPasscodeAttempts {
			return 0
		}

		return pow(powBaseDelay, Double(failedPasscodeAttempts))
	}
	private var biometricalAuthenticationSucceeded: Bool {
		get {
			return userDefaults.bool(forKey: "applock-biometrical-authentication-succeeded")
		}
		set(newValue) {
			userDefaults.set(newValue, forKey: "applock-biometrical-authentication-succeeded")
		}
	}

	private let maximumToleratedFailedPasscodeAttempts: Int = 3
	private let powBaseDelay: Double = 1.5
	private var lockTimer: Timer?

	// MARK: - Passcode
	private let keychainAccount = "app.passcode"
	private let keychainPasscodePath = "passcode"
	private let keychainLockedDate = "lockedDate"
	private let keychainUnlocked = "unlocked"

	private var keychain : OCKeychain? {
		return OCAppIdentity.shared.keychain
	}

	public var passcode: String? {
		get {
			if let passcodeData = keychain?.readDataFromKeychainItem(forAccount: keychainAccount, path: keychainPasscodePath) {
				return String(data: passcodeData, encoding: .utf8)
			}

			return nil
		}

		set(newPasscode) {
			if let passcode = newPasscode {
				_ = keychain?.write(passcode.data(using: .utf8), toKeychainItemForAccount: keychainAccount, path: keychainPasscodePath)
			} else {
				_ = keychain?.removeItem(forAccount: keychainAccount, path: keychainPasscodePath)
			}
		}
	}

	// Set a view controller only, if you want to use it in an extension, when UIWindow is not working
	public var passwordViewHostViewController: UIViewController?

	private var biometricalSecurityEnabled: Bool {
		return AppLockSettings.shared.biometricalSecurityEnabled
	}

	// MARK: - Init
	public static var shared = AppLockManager()

	public override init() {
		userDefaults = OCAppIdentity.shared.userDefaults!

		super.init()

		if AppLockManager.supportedOnDevice {
			NotificationCenter.default.addObserver(self, selector: #selector(self.appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(self.appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(self.significantTimeChangeOccurred), name: UIApplication.significantTimeChangeNotification, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(self.updateLockscreens), name: ThemeWindow.themeWindowListChangedNotification, object: nil)
		}
	}

	deinit {
		if AppLockManager.supportedOnDevice {
			NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
			NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
			NotificationCenter.default.removeObserver(self, name: UIApplication.significantTimeChangeNotification, object: nil)
			NotificationCenter.default.removeObserver(self, name: ThemeWindow.themeWindowListChangedNotification, object: nil)
		}
	}

	// MARK: - Show / Dismiss Passcode View
	public func showLockscreenIfNeeded(forceShow: Bool = false, setupMode: Bool = false, context: LAContext? = nil) {
		if shouldDisplayLockscreen || forceShow || setupMode {
			lockscreenOpenForced = forceShow
			lockscreenOpen = true

			// The following code needs to be executed after a short delay, because in the share sheet the biometrical unlock UI can block adding the PasscodeViewController UI
			var delay = 0.0
			if passwordViewHostViewController != nil {
				delay = 0.5
			}
			OnMainThread(after: delay) {
				// Show biometrical
				if !forceShow, !self.shouldDisplayCountdown, self.biometricalAuthenticationSucceeded {
					self.showBiometricalAuthenticationInterface(context: context)
				} else if setupMode {
					self.showBiometricalAuthenticationInterface(context: context)
				}
			}
		} else {
			dismissLockscreen(animated: true)
		}
	}

	public func dismissLockscreen(animated:Bool) {
		if animated {
			let animationGroup = DispatchGroup()

			for themeWindow in ThemeWindow.themeWindows {
				if let appLockWindow = applockWindowByWindow.object(forKey: themeWindow) {
					animationGroup.enter()

					appLockWindow.hideWindowAnimation {
						appLockWindow.isHidden = true
						animationGroup.leave()
					}
				}
			}

			animationGroup.notify(queue: .main) {
				self.lockscreenOpen = false
			}
		} else {
			lockscreenOpen = false
		}
		successAction?()
	}

	// MARK: - Lock window management
	private var lockscreenOpenForced : Bool = false
	private var lockscreenOpen : Bool = false {
		didSet {
			updateLockscreens()
		}
	}

	private var passcodeControllerByWindow : NSMapTable<ThemeWindow, PasscodeViewController> = NSMapTable.weakToStrongObjects()
	private var applockWindowByWindow : NSMapTable<ThemeWindow, AppLockWindow> = NSMapTable.weakToStrongObjects()

	open var biometricCancelLabel : String?

	open var cancelAction : (() -> Void)?
	open var successAction : (() -> Void)?

	@objc private func cancelPressed () {
		cancelAction?()
	}

	@objc func updateLockscreens() {
		if lockscreenOpen {
			if let passwordViewHostViewController = passwordViewHostViewController {
				if let passcodeViewController = passwordViewHostViewController.children.last as? PasscodeViewController {
					passcodeViewController.screenBlurringEnabled = lockscreenOpenForced
				} else {
					let passcodeViewController = passwordViewController()
					let navigationController = ThemeNavigationController(rootViewController: passcodeViewController)
					navigationController.modalPresentationStyle = .overFullScreen

					if cancelAction != nil {
						let itemCancel = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPressed))
						passcodeViewController.navigationItem.setRightBarButton(itemCancel, animated: false)
					}
					passcodeViewController.navigationItem.title = VendorServices.shared.appName

					passwordViewHostViewController.present(navigationController, animated: false, completion: nil)

					showOrHideLockCountdownAsNeeded()
				}
			} else {
				for themeWindow in ThemeWindow.themeWindows {
					if let passcodeViewController = passcodeControllerByWindow.object(forKey: themeWindow) {
						passcodeViewController.screenBlurringEnabled = lockscreenOpenForced
					} else {
						var appLockWindow : AppLockWindow
						let passcodeViewController = passwordViewController()

						if let windowScene = themeWindow.windowScene {
							appLockWindow = AppLockWindow(windowScene: windowScene)
						} else {
							appLockWindow = AppLockWindow(frame: UIScreen.main.bounds)
						}

						/*
						Workaround to the lack of status bar animation when returning true for prefersStatusBarHidden in
						PasscodeViewController.

						The documentation notes that "The ordering of windows within a given window level is not guaranteed.",
						so that with a future iOS update this might break and the status bar be displayed regardless. In that
						case, implement prefersStatusBarHidden in PasscodeViewController to return true and remove the dismiss
						animation (the re-appearance of the status bar will lead to a jump in the UI otherwise).
						*/
						appLockWindow.windowLevel = UIWindow.Level.statusBar
						appLockWindow.rootViewController = passcodeViewController
						appLockWindow.makeKeyAndVisible()

						passcodeControllerByWindow.setObject(passcodeViewController, forKey: themeWindow)
						applockWindowByWindow.setObject(appLockWindow, forKey: themeWindow)

						showOrHideLockCountdownAsNeeded()
					}
				}
			}
		} else {
			if let passwordViewHostViewController = passwordViewHostViewController, let passcodeViewController = passwordViewHostViewController.topMostViewController as? PasscodeViewController {
				passcodeViewController.dismiss(animated: false, completion: nil)
			} else {
				for themeWindow in ThemeWindow.themeWindows {
					if let appLockWindow = applockWindowByWindow.object(forKey: themeWindow) {
						appLockWindow.isHidden = true

						passcodeControllerByWindow.removeObject(forKey: themeWindow)
						applockWindowByWindow.removeObject(forKey: themeWindow)
					}
				}
			}
		}
	}

	func passwordViewController() -> PasscodeViewController {
		var passcodeViewController : PasscodeViewController

		passcodeViewController = PasscodeViewController(biometricalHandler: { (passcodeViewController) in
			if !self.shouldDisplayCountdown {
				self.showBiometricalAuthenticationInterface()
			}
		}, completionHandler: { (viewController: PasscodeViewController, passcode: String) in
			self.attemptUnlock(with: passcode, passcodeViewController: viewController)
		}, requiredLength: AppLockManager.shared.passcode?.count ?? AppLockSettings.shared.requiredPasscodeDigits)

		passcodeViewController.message = OCLocalizedString("Enter code", nil)
		passcodeViewController.cancelButtonAvailable = false

		passcodeViewController.screenBlurringEnabled = lockscreenOpenForced && !shouldDisplayLockscreen

		return passcodeViewController
	}

	// MARK: - App Events
	@objc public func appDidEnterBackground() {
		if unlocked {
			lastApplicationBackgroundedDate = Date()
		} else {
			lastApplicationBackgroundedDate = nil
		}

		showLockscreenIfNeeded(forceShow: true)
	}

	@objc func appWillEnterForeground() {
		if shouldDisplayLockscreen {
			dismissLockscreen(animated: false)
			showLockscreenIfNeeded()
		} else {
			dismissLockscreen(animated: false)
		}
	}

	@objc func significantTimeChangeOccurred() {
		if !unlocked, lockedUntilDate != nil {
			resetAndStartLockCountdown()
		}
	}

	// MARK: - Unlock
	func attemptUnlock(with testPasscode: String?, customErrorMessage: String? = nil, passcodeViewController: PasscodeViewController? = nil) {
		if testPasscode == passcode {
			unlocked = true
			failedPasscodeAttempts = 0
			dismissLockscreen(animated: true)
		} else {
			unlocked = false
			lastApplicationBackgroundedDate = nil
			passcodeViewController?.errorMessage = (customErrorMessage != nil) ? customErrorMessage! : OCLocalizedString("Incorrect code", nil)

			failedPasscodeAttempts += 1

			passcodeViewController?.passcode = nil
		}
	}

	// MARK: - Status
	private var shouldDisplayLockscreen: Bool {
		if !AppLockSettings.shared.lockEnabled {
			return false
		}

		if unlocked, !shouldDisplayCountdown {
			if let backgroundedDate = lastApplicationBackgroundedDate {
				if backgroundedDate.timeIntervalSinceNow > 0 {
					// Device time is earlier than lastApplicationBackgroundedDate,
					// which should not be possible. Clear unlocked state immediately
					// to protect against this or other attempts to gain access by
					// changing the device's clock time to a moment in the past
					unlocked = false
					lastApplicationBackgroundedDate = nil

					Log.error(tagged: ["Security"], "Current device time \(Date().description) preceeds last application backgrounded date \(backgroundedDate.description), possibly indicating device time manipulation. Unlock status cleared.")

					return true
				} else {
					if Int(-backgroundedDate.timeIntervalSinceNow) < AppLockSettings.shared.lockDelay {
						// Unlock still valid
						return false
					}
				}
			}
		}

		// Clear unlocked state immediately if it has expired, so subsequently
		// changing the device's clock time can't lead to an unlock
		unlocked = false
		lastApplicationBackgroundedDate = nil

		return true
	}

	private var shouldDisplayCountdown : Bool {
		var shouldDisplayCountdown = false

		if let lockedUntilDate {
			if determineIfTimeHasBeenTampered(andResetIf: true) {
				shouldDisplayCountdown = true
			} else {
				shouldDisplayCountdown = lockedUntilDate > Date()
			}

			if !shouldDisplayCountdown {
				removeLockCountdown()
			}
		}

		return shouldDisplayCountdown
	}

	// MARK: - Countdown
	private func resetAndStartLockCountdown() {
		let currentDate = Date()
		let currentSystemUptime = ProcessInfo.processInfo.systemUptime

		lockedSinceDate = currentDate
		lockedSinceSystemUptime = currentSystemUptime

		lockedUntilDate = currentDate.addingTimeInterval(lockTimeoutDuration)

		showOrHideLockCountdownAsNeeded()
	}

	private func removeLockCountdown() {
		lockedSinceDate = nil
		lockedSinceSystemUptime = nil
		lockedUntilDate = nil

		showOrHideLockCountdownAsNeeded()
	}

	private var timeHasBeenTamperedWith: Bool {
		// Check for noticable discrepancies between the progress of the clock time and system up time
		// to mitigate a circumvention tactic that would quit the app, set the date to a distant future date
		// and launch the app again, allowing the user to have another (sooner) opportunity to try a passcode.
		let currentDate = Date()
		let currentSystemUptime = ProcessInfo.processInfo.systemUptime

		guard let lockedSinceDate, let lockedSinceSystemUptime else { return false }

		let clockTimePassedSinceLockStart = currentDate.timeIntervalSince(lockedSinceDate) // Time that passed in clock time since the lock started
		let systemUptimePassedSinceLockStart = currentSystemUptime - lockedSinceSystemUptime // Time that passed in system uptime since the lock started
		let differenceBetweenPassedClockTimeAndSystemUptime = abs(clockTimePassedSinceLockStart - systemUptimePassedSinceLockStart) // Discrepancy between time passed in clock time and system uptime
		let allowedCorridor: TimeInterval = 5 // Maximum allowed discrepancy between the two time intervals

		if differenceBetweenPassedClockTimeAndSystemUptime > allowedCorridor {
			// Discrepancy higher than allowed corridor => system time appears to have changed
			return true
		}

		return false
	}

	private func determineIfTimeHasBeenTampered(andResetIf reset: Bool = true) -> Bool {
		if timeHasBeenTamperedWith {
			if reset {
				resetAndStartLockCountdown()
			}
			return true
		}
		return false
	}

	// MARK: - UI updates
	private func showOrHideLockCountdownAsNeeded() {
		if shouldDisplayCountdown {
			performPasscodeViewControllerUpdates { (passcodeViewController) in
				passcodeViewController.keypadButtonsHidden = true
				passcodeViewController.view.setNeedsLayout()
			}

			updateLockCountdown()

			lockTimer?.invalidate()
			lockTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateLockCountdown), userInfo: nil, repeats: true)
		}
	}

	@objc private func updateLockCountdown() {
		if let lockedUntilDate {
			let remainingInterval = Int(lockedUntilDate.timeIntervalSinceNow)
			let remainingSeconds = remainingInterval % 60
			let remainingMinutes = (remainingInterval / 60) % 60
			let remainingHours = (remainingInterval / 3600)
			let formattedTime: String

			if remainingHours > 0 {
				formattedTime = String(format: "%02d:%02d:%02d", remainingHours, remainingMinutes, remainingSeconds)
			} else {
				formattedTime = String(format: "%02d:%02d", remainingMinutes, remainingSeconds)
			}

			let timeoutMessage: String = NSString(format: OCLocalizedString("Please try again in %@", nil) as NSString, formattedTime) as String

			performPasscodeViewControllerUpdates { (passcodeViewController) in
				passcodeViewController.timeoutMessage = timeoutMessage
			}

			if lockedUntilDate <= Date(), !determineIfTimeHasBeenTampered(andResetIf: true) {
				// Time elapsed, allow entering passcode again
				lockTimer?.invalidate()
				lockTimer = nil

				performPasscodeViewControllerUpdates { (passcodeViewController) in
					passcodeViewController.keypadButtonsHidden = false
					passcodeViewController.timeoutMessage = nil
					passcodeViewController.errorMessage = nil
				}

				removeLockCountdown()
			}
		}
	}

	private func performPasscodeViewControllerUpdates(_ updateHandler: (_: PasscodeViewController) -> Void) {
		if let passwordViewHostViewController = passwordViewHostViewController, let passcodeViewController = passwordViewHostViewController.topMostViewController as? PasscodeViewController {
			updateHandler(passcodeViewController)
		} else {
			for themeWindow in ThemeWindow.themeWindows {
				if let passcodeViewController = passcodeControllerByWindow.object(forKey: themeWindow) {
					updateHandler(passcodeViewController)
				}
			}
		}
	}

	// MARK: - Biometrical Unlock
	private var biometricalAuthenticationInterfaceShown : Bool = false

	func showBiometricalAuthenticationInterface(context inContext: LAContext? = nil) {

		if shouldDisplayLockscreen, biometricalSecurityEnabled, !biometricalAuthenticationInterfaceShown {
			// Check if we should perform biometrical authentication - or redirect
			if let targetURL = AppLockSettings.shared.biometricalAuthenticationRedirectionTargetURL {
				// Unfortunately, opening the URL closes the share sheet just like invoking
				// biometric auth - so in those instances where we'd want to use it to work around
				// that.
				passwordViewHostViewController?.openURL(targetURL)
				return
			}

			// Perform biometrical authentication
			let context = inContext ?? LAContext()
			var evaluationError: NSError?

			// Check if the device can evaluate the policy.
			if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &evaluationError) {
				let reason = NSString.init(format: OCLocalizedString("Unlock %@", nil) as NSString, VendorServices.shared.appName) as String

				performPasscodeViewControllerUpdates { (passcodeViewController) in
					OnMainThread {
						passcodeViewController.errorMessage = nil
					}
				}

				context.localizedCancelTitle = biometricCancelLabel ?? OCLocalizedString("Enter code", nil)
				context.localizedFallbackTitle = ""

				biometricalAuthenticationInterfaceShown = true

				context.evaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (success, error) in
					self.biometricalAuthenticationInterfaceShown = false

					if success {
						self.biometricalAuthenticationSucceeded = true
						// Fill the passcode dots
						OnMainThread {
							self.performPasscodeViewControllerUpdates { (passcodeViewController) in
								passcodeViewController.passcode = self.passcode
							}
						}

						// Remove the passcode after small delay to give user feedback after use the biometrical unlock
						var delay = 0.3
						// If the AppLockManager was called from an extension, like File Provider, the delay causes that the UI cannot be unlocked. Delay is not possible in extension.
						if self.passwordViewHostViewController != nil {
							delay = 0.0
						}
						OnMainThread(after: delay) {
							self.attemptUnlock(with: self.passcode)
						}
					} else {
						self.biometricalAuthenticationSucceeded = false
						if let error = error {
							switch error {
								case LAError.biometryLockout:
									OnMainThread {
										self.performPasscodeViewControllerUpdates { (passcodeViewController) in
											passcodeViewController.errorMessage = error.localizedDescription
										}
									}

								case LAError.authenticationFailed:
									OnMainThread {
										self.attemptUnlock(with: nil, customErrorMessage: OCLocalizedString("Biometric authentication failed", nil))
									}

								default: break
							}
						}
					}
				}
			} else {
				if let error = evaluationError, biometricalSecurityEnabled {
					OnMainThread {
						self.performPasscodeViewControllerUpdates { (passcodeViewController) in
							passcodeViewController.errorMessage = error.localizedDescription
						}
					}
				}
			}
		}
	}
}
