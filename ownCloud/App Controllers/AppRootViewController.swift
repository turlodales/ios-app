//
//  AppRootViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 15.11.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
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
import ownCloudAppShared

open class AppRootViewController: EmbeddingViewController, BrowserNavigationViewControllerDelegate, BrowserNavigationBookmarkRestore {
	var clientContext: ClientContext
	var controllerConfiguration: AccountController.Configuration

	var focusedBookmarkObservation: NSKeyValueObservation?

	init(with context: ClientContext, controllerConfiguration: AccountController.Configuration = .defaultConfiguration) {
		clientContext = context
		self.controllerConfiguration = controllerConfiguration
		super.init(nibName: nil, bundle: nil)
	}

	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - View Controllers
	var rootContext: ClientContext?

	public var leftNavigationController: ThemeNavigationController?
	public var sidebarViewController: ClientSidebarViewController?
	public var contentBrowserController: BrowserNavigationViewController = BrowserNavigationViewController()

	private var contentBrowserControllerObserver: NSKeyValueObservation?

	// MARK: - Message presentation
	var alertQueue : OCAsyncSequentialQueue = OCAsyncSequentialQueue()

	var notificationPresenter: NotificationMessagePresenter?
	var cardMessagePresenter: CardIssueMessagePresenter?

	@objc dynamic var focusedBookmark: OCBookmark? {
		willSet {
			// Remove message presenters
			if let notificationPresenter {
				OCMessageQueue.global.remove(presenter: notificationPresenter)
			}

			if let cardMessagePresenter {
				OCMessageQueue.global.remove(presenter: cardMessagePresenter)
			}
		}

		didSet {
			if let focusedBookmark {
				// Create message presenters
				notificationPresenter = NotificationMessagePresenter(forBookmarkUUID: focusedBookmark.uuid)
				cardMessagePresenter = CardIssueMessagePresenter(with: focusedBookmark.uuid as OCBookmarkUUID, limitToSingleCard: true, presenter: { [weak self] (viewController) in
					self?.presentAlertAsCard(viewController: viewController, withHandle: false, dismissable: true)
					// Log.debug("Present \(viewController.debugDescription)")
				})

				// Add message presenters
				if let notificationPresenter {
					OCMessageQueue.global.add(presenter: notificationPresenter)
				}

				if let cardMessagePresenter {
					OCMessageQueue.global.add(presenter: cardMessagePresenter)
				}
			}
		}
	}

	// MARK: - View Controller Events
	var noBookmarkCondition: DataSourceCondition?

	override open func viewDidLoad() {
		super.viewDidLoad()

		// Add icons
		AppRootViewController.addIcons()

		// Create client context, using contentBrowserController to manage content + sidebar
		rootContext = ClientContext(with: clientContext, rootViewController: self, alertQueue: alertQueue, modifier: { context in
			context.viewItemHandler = self
			context.moreItemHandler = self
			context.bookmarkEditingHandler = self
			context.browserController = self.contentBrowserController
		})

		// Build sidebar
		sidebarViewController = ClientSidebarViewController(context: rootContext!, controllerConfiguration: controllerConfiguration)
		sidebarViewController?.addToolbarItems(addAccount: Branding.shared.canAddAccount)

		leftNavigationController = ThemeNavigationController(rootViewController: sidebarViewController!)
		leftNavigationController?.cssSelectors = [ .sidebar ]
		leftNavigationController?.setToolbarHidden(false, animated: false)

		focusedBookmarkObservation = sidebarViewController?.observe(\.focusedBookmark, changeHandler: { [weak self] sidebarViewController, change in
			self?.focusedBookmark = self?.sidebarViewController?.focusedBookmark
		})

		// Build split view controller
		contentBrowserController.sidebarViewController = leftNavigationController

		// Make browser navigation view controller the content
		noBookmarkCondition = DataSourceCondition(.empty, with: OCBookmarkManager.shared.bookmarksDatasource, initial: true, action: { [weak self] condition in
			if condition.fulfilled == true {
				// No account available
				let configuration = BookmarkComposerConfiguration.newBookmarkConfiguration
				configuration.hasIntro = true
				self?.contentViewController = BookmarkSetupViewController(configuration: configuration)
			} else {
				// Account already available
				self?.contentViewController = self?.contentBrowserController
			}
		})

		// Observe browserController contentViewController and update sidebar selection accordingly
		contentBrowserController.delegate = self

		// Setup app icon badge message count
		setupAppIconBadgeMessageCount()
	}

	var shownFirstTime = true

	open override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		ClientSessionManager.shared.add(delegate: self)

		if AppLockManager.shared.passcode == nil && AppLockSettings.shared.isPasscodeEnforced {
			PasscodeSetupCoordinator(parentViewController: self, action: .setup).start()
		} else if let passcode = AppLockManager.shared.passcode, passcode.count < AppLockSettings.shared.requiredPasscodeDigits {
			PasscodeSetupCoordinator(parentViewController: self, action: .upgrade).start()
		}

		// Release Notes, Beta warning, Review prompts…
		considerLaunchPopups()

		shownFirstTime = false
	}

	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		ClientSessionManager.shared.remove(delegate: self)
	}

	// MARK: - Interface orientations
	open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		if let contentViewController {
			return contentViewController.supportedInterfaceOrientations
		}

		return super.supportedInterfaceOrientations
	}

	open override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
		if let contentViewController {
			return contentViewController.preferredInterfaceOrientationForPresentation
		}

		return super.preferredInterfaceOrientationForPresentation
	}

	// MARK: - Status Bar style
	open override var childForStatusBarStyle: UIViewController? {
		return contentViewController
	}

	open override var contentViewController: UIViewController? {
		didSet {
			setNeedsStatusBarAppearanceUpdate()
			if #available(iOS 16, *) {
				setNeedsUpdateOfSupportedInterfaceOrientations()
			}
		}
	}

	// MARK: - BrowserNavigationViewControllerDelegate
	public func browserNavigation(viewController: ownCloudAppShared.BrowserNavigationViewController, contentViewControllerDidChange toViewController: UIViewController?) {
		sidebarViewController?.updateSelection(for: toViewController?.navigationBookmark)
	}

	// MARK: - BrowserNavigationBookmarkRestore
	public func restore(navigationBookmark: BrowserNavigationBookmark, in viewController: UIViewController?, with context: ClientContext?, completion: @escaping ((Error?, UIViewController?) -> Void)) {
		if let bookmarkUUID = navigationBookmark.bookmarkUUID, let accountController = sidebarViewController?.accountController(for: bookmarkUUID) {
			if let specialItem = navigationBookmark.specialItem,
			   let viewController = accountController.provideViewController(for: specialItem, in: context) {
				completion(nil, viewController)
				return
			}
		}

		completion(NSError(ocError: .insufficientParameters), nil)
	}

	// MARK: - App Badge: Message Counts
	var messageCountSelector: MessageSelector?

	func setupAppIconBadgeMessageCount() {
		messageCountSelector = MessageSelector(filter: nil, handler: { (messages, _, _) in
			var unresolvedMessagesCount = 0

			if let messages = messages {
				for message in messages {
					if !message.resolved {
						unresolvedMessagesCount += 1
					}
				}
			}

			OnMainThread {
				if !ProcessInfo.processInfo.arguments.contains("UI-Testing") {
					NotificationManager.shared.requestAuthorization(options: .badge) { (granted, _) in
						if granted {
							OnMainThread {
								UIApplication.shared.applicationIconBadgeNumber = unresolvedMessagesCount
							}
						}
					}
				}
			}
		})
	}

	// MARK: - Launch popups
	func considerLaunchPopups() {
		var shownPopup = false

		if VendorServices.shared.showBetaWarning, shownFirstTime, !shownPopup {
			shownPopup = considerLaunchPopupBetaWarning()
		}

		if shownFirstTime, !shownPopup {
			shownPopup = considerLaunchPopupReleaseNotes()
		}

		if !shownFirstTime {
			VendorServices.shared.considerReviewPrompt()
		}
	}

	// MARK: - Beta warning
	func considerLaunchPopupBetaWarning() -> Bool {
		let lastBetaWarningCommit = OCAppIdentity.shared.userDefaults?.string(forKey: "LastBetaWarningCommit")

		Log.log("Show beta warning: \(String(describing: VendorServices.classSetting(forOCClassSettingsKey: .showBetaWarning) as? Bool))")

		if VendorServices.classSetting(forOCClassSettingsKey: .showBetaWarning) as? Bool == true,
			let lastGitCommit = GitInfo.app.lastCommit,
			(lastBetaWarningCommit == nil) || (lastBetaWarningCommit != lastGitCommit) {
			// Beta warning has never been shown before - or has last been shown for a different release
			let betaAlert = ThemedAlertController(with: OCLocalizedString("Beta Warning", nil), message: OCLocalizedString("\nThis is a BETA release that may - and likely will - still contain bugs.\n\nYOU SHOULD NOT USE THIS BETA VERSION WITH PRODUCTION SYSTEMS, PRODUCTION DATA OR DATA OF VALUE. YOU'RE USING THIS BETA AT YOUR OWN RISK.", nil), okLabel: OCLocalizedString("Agree", nil)) {
				OCAppIdentity.shared.userDefaults?.set(lastGitCommit, forKey: "LastBetaWarningCommit")
				OCAppIdentity.shared.userDefaults?.set(NSDate(), forKey: "LastBetaWarningAcceptDate")
			}

			self.present(betaAlert, animated: true, completion: nil)

			return true
		}

		return false
	}

	// MARK: - Release notes
	func considerLaunchPopupReleaseNotes() -> Bool {
		defer {
			ReleaseNotesDatasource.updateLastSeenAppVersion()
		}

		if ReleaseNotesDatasource.shouldShowReleaseNotes {
			let releaseNotesHostController = ReleaseNotesHostViewController()
			releaseNotesHostController.modalPresentationStyle = .formSheet
			self.present(releaseNotesHostController, animated: true, completion: nil)

			return true
		}

		return false
	}
}

// MARK: - Authentication: bookmark editing
extension AppRootViewController: AccountAuthenticationHandlerBookmarkEditingHandler {
	public func handleAuthError(for viewController: UIViewController, error: NSError, editBookmark: OCBookmark?, preferredAuthenticationMethods: [OCAuthenticationMethodIdentifier]?) {
		BookmarkViewController.showBookmarkUI(on: viewController, edit: editBookmark, performContinue: true, attemptLoginOnSuccess: true, removeAuthDataFromCopy: true)
	}
}

// MARK: - Message presentation
extension AppRootViewController : ClientSessionManagerDelegate {
	var selectedAccountConnection: AccountController? {
		if let accountControllerSection = self.sidebarViewController?.sectionOfCurrentSelection as? AccountControllerSection {
			return accountControllerSection.accountController
		}

		return nil
	}

	func canPresent(bookmark: OCBookmark, message: OCMessage?) -> OCMessagePresentationPriority {
		if let themeWindow = self.viewIfLoaded?.window as? ThemeWindow, themeWindow.themeWindowInForeground {
			if !OCBookmarkManager.isLocked(bookmark: bookmark) {
				if let selectedAccountConnection {
					if selectedAccountConnection.connection?.bookmark.uuid == bookmark.uuid {
						return .high
					} else {
						return .default
					}
				} else if presentedViewController == nil {
					return .high
				}
			}

			return .low
		}

		return .wontPresent
	}

	func present(bookmark: OCBookmark, message: OCMessage?) {
		OnMainThread {
			/*
			if self.presentedViewController == nil {
				self.connect(to: bookmark, lastVisibleItemId: nil, animated: true, present: message)
			} else {
			*/

			if let message = message {
				self.presentInClient(message: message)
			}
		}
	}

	func presentInClient(message: OCMessage) {
		if let cardMessagePresenter {
			OnMainThread { // Wait for next runloop cycle
				OCMessageQueue.global.present(message, with: cardMessagePresenter)
			}
		}
	}

	func presentAlertAsCard(viewController: UIViewController, withHandle: Bool = false, dismissable: Bool = true) {
		alertQueue.async { [weak self] (queueCompletionHandler) in
			if let startViewController = self {
				var hostViewController : UIViewController = startViewController

				while hostViewController.presentedViewController != nil,
				      hostViewController.presentedViewController?.isBeingDismissed == false {
					hostViewController = hostViewController.presentedViewController!
				}

				hostViewController.present(asCard: viewController, animated: true, withHandle: withHandle, dismissable: dismissable, completion: {
					queueCompletionHandler()
				})
			} else {
				queueCompletionHandler()
			}
		}
	}
}

// MARK: - Sidebar toolbar
extension ClientSidebarViewController {
	// MARK: - Add toolbar items
	func addToolbarItems(addAccount: Bool = true, settings addSettings: Bool = true) {
		var toolbarItems: [UIBarButtonItem] = []

		if addAccount {
			let addAccountBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction(handler: { [weak self] action in
				self?.addBookmark()
			}))

			toolbarItems.append(addAccountBarButtonItem)
		}

		if addSettings {
			let settingsBarButtonItem = UIBarButtonItem(title: OCLocalizedString("Settings", nil), style: UIBarButtonItem.Style.plain, target: self, action: #selector(settings))
			settingsBarButtonItem.accessibilityIdentifier = "settingsBarButtonItem"

			toolbarItems.append(contentsOf: [
				UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil),
				settingsBarButtonItem
			])
		}

		self.toolbarItems = toolbarItems
	}

	// MARK: - Open settings
	@IBAction func settings() {
		let navigationViewController = ThemeNavigationController(rootViewController: SettingsViewController())
		navigationViewController.modalPresentationStyle = .fullScreen
		present(navigationViewController, animated: true)
	}

	// MARK: - Add account
	func addBookmark() {
		BookmarkViewController.showBookmarkUI(on: self, attemptLoginOnSuccess: true)
	}

	// MARK: - Update selection
	public func section(for bookmarkUUID: UUID) -> AccountControllerSection? {
		for section in allSections {
			if let accountControllerSection = section as? AccountControllerSection,
			   let sectionBookmark = accountControllerSection.accountController.bookmark,
			   sectionBookmark.uuid == bookmarkUUID {
				return accountControllerSection
			}
		}

		return nil
	}

	public func accountController(for bookmarkUUID: UUID) -> AccountController? {
		return section(for: bookmarkUUID)?.accountController
	}

	public func itemReferences(for itemReferences: [OCDataItemReference], inSectionFor bookmarkUUID: UUID?) -> [ItemRef]? {
		if let bookmarkUUID, let section = section(for: bookmarkUUID) {
			return section.collectionViewController?.wrap(references: itemReferences, forSection: section.identifier)
		}

		return nil
	}

	func updateSelection(for navigationBookmark: BrowserNavigationBookmark?) {
		if let sideBarItemRefs = navigationBookmark?.representationSideBarItemRefs,
		   let bookmarkUUID = navigationBookmark?.bookmarkUUID,
		   let selectionItemRefs = itemReferences(for: sideBarItemRefs, inSectionFor: bookmarkUUID),
		   let highlightAction = CollectionViewAction(kind: .highlight(animated: false, scrollPosition: []), itemReferences: selectionItemRefs) {
			// Highlight all
			addActions([
				highlightAction
			])
		} else {
			// Unhighlight all
			addActions([
				CollectionViewAction(kind: .unhighlightAll(animated: false))
			])
		}
	}
}

// MARK: - Branding
public extension AppRootViewController {
	static func addIcons() {
		Theme.shared.add(tvgResourceFor: "icon-available-offline")
		Theme.shared.add(tvgResourceFor: "status-flash")
		Theme.shared.add(tvgResourceFor: "owncloud-logo")

		OCItem.registerIcons()
	}
}
