//
//  Settings.swift
//  ownCloudTests
//
//  Created by Jesús Recio on 27/02/2019.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

import XCTest
import EarlGrey
import ownCloudSDK
import ownCloudMocking

@testable import ownCloud

class SettingsTests: XCTestCase {

	override func setUp() {
		EarlGrey.select(elementWithMatcher: grey_text("Settings".localized)).perform(grey_tap())
	}

	/*
	* PASSED if: Theme and Logging are displayed as part of the "User Interface" section of Settings
	*/
	func testCheckUserInferfaceItems () {

		//Assert
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("theme")).assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("logging")).assert(grey_sufficientlyVisible())

		//Reset status
		EarlGrey.select(elementWithMatcher: grey_text("ownCloud".localized)).perform(grey_tap())
	}
	
	/*
	* PASSED if: Show hidden files and folders are displayed as part of the "Display Settings" section of Settings
	*/
	func testCheckDisplaySettings () {
		
		//Assert
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("show-hidden-files-switch")).assert(grey_sufficientlyVisible())
		
		//Reset status
		EarlGrey.select(elementWithMatcher: grey_text(OCAppIdentity.shared.appName!)).perform(grey_tap())
	}
	
	/*
	* PASSED if: Media upload options are displayed as part of the "Media Upload" section of Settings
	*/
	func testCheckMediaUploadSettings () {
		
		//Assert
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("convert_heic_to_jpeg")).assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("convert_to_mp4")).assert(grey_sufficientlyVisible())
		
		//Reset status
		EarlGrey.select(elementWithMatcher: grey_text(OCAppIdentity.shared.appName!)).perform(grey_tap())
	}


	/*
	* PASSED if: "More" options "are displayed
	*/
	func testCheckMoreItems () {

		//Assert
		EarlGrey.select(elementWithMatcher: grey_text("SECURITY".localized))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_accessibilityID("help".localized))
			.assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("SECURITY".localized))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_accessibilityID("send-feedback".localized))
			.assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("SECURITY".localized))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_accessibilityID("recommend-friend".localized))
			.assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("SECURITY".localized))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_accessibilityID("privacy-policy".localized))
			.assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("SECURITY".localized))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_text("Acknowledgements".localized))
			.assert(grey_sufficientlyVisible())

		//Reset status
		EarlGrey.select(elementWithMatcher: grey_text("ownCloud".localized)).perform(grey_tap())
	}

	/*
	* PASSED if: All UI components in Logging view are displayed and correctly visible when option is enabled.
	*/
	func testCheckLoggingInterfaceLoggingEnabled () {

		//Actions
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("logging")).perform(grey_tap())

		//Assert
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("enable-logging")).assert(grey_switchWithOnState(true))
		EarlGrey.select(elementWithMatcher: grey_text("Debug".localized)).assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Info".localized)).assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Warning".localized)).assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Error".localized)).assert(grey_sufficientlyVisible())

		EarlGrey.select(elementWithMatcher: grey_accessibilityID("Logging"))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_text("Log HTTP requests and responses"))
			.assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("Logging"))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_text("Standard error output".localized))
			.assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("Logging"))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_text("Log file".localized))
			.assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("Logging"))
			.usingSearch(grey_scrollInDirection(GREYDirection.down, 100), onElementWith: grey_text("Browse".localized))
			.assert(grey_sufficientlyVisible())

		//Reset status
		EarlGrey.select(elementWithMatcher: grey_text("Settings".localized)).perform(grey_tap())
		EarlGrey.select(elementWithMatcher: grey_text("ownCloud".localized)).perform(grey_tap())
	}

	/*
	* PASSED if: Log level is changed to "Warning".
	*/
	func testSwitchLogLevel () {

		//Actions
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("logging")).perform(grey_tap())
		EarlGrey.select(elementWithMatcher: grey_text("Warning".localized)).perform(grey_tap())
		EarlGrey.select(elementWithMatcher: grey_text("Settings".localized)).perform(grey_tap())

		//Assert
		EarlGrey.select(elementWithMatcher: grey_text("Warning".localized)).assert(grey_sufficientlyVisible())

		//Reset status
		EarlGrey.select(elementWithMatcher: grey_text(OCAppIdentity.shared.appName!)).perform(grey_tap())
	}

	/*
	* PASSED if: All UI components in Logging view are not displayed when option is disabled.
	*/
	func testCheckLoggingInterfaceLoggingDisabled () {

		//Actions
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("logging")).perform(grey_tap())
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("enable-logging")).perform(grey_turnSwitchOn(false))

		//Assert
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("enable-logging")).assert(grey_switchWithOnState(false))
		EarlGrey.select(elementWithMatcher: grey_text("Debug".localized)).assert(grey_notVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Info".localized)).assert(grey_notVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Warning".localized)).assert(grey_notVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Error".localized)).assert(grey_notVisible())

		EarlGrey.select(elementWithMatcher: grey_text("OCLogOptionLogRequestsAndResponses")).assert(grey_notVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Standard error output".localized)).assert(grey_notVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Log file".localized)).assert(grey_notVisible())

		//Reset status
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("enable-logging")).perform(grey_turnSwitchOn(true))
		EarlGrey.select(elementWithMatcher: grey_text("Settings".localized)).perform(grey_tap())
		EarlGrey.select(elementWithMatcher: grey_text("ownCloud".localized)).perform(grey_tap())
	}

	/*
	* PASSED if: All themes available are displayed
	*/
	func testCheckThemesAvailable () {

		//Actions
		EarlGrey.select(elementWithMatcher: grey_accessibilityID("theme")).perform(grey_tap())

		//Assert
		EarlGrey.select(elementWithMatcher: grey_text("Dark".localized)).assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Light".localized)).assert(grey_sufficientlyVisible())
		EarlGrey.select(elementWithMatcher: grey_text("Classic".localized)).assert(grey_sufficientlyVisible())

		//Reset status
		EarlGrey.select(elementWithMatcher: grey_text("Settings".localized)).perform(grey_tap())
		EarlGrey.select(elementWithMatcher: grey_text("ownCloud".localized)).perform(grey_tap())
	}

}
