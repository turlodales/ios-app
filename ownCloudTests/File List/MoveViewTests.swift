//
//  MoveViewTests.swift
//  ownCloudTests
//
//  Created by Javier Gonzalez on 21/02/2019.
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

import XCTest
import EarlGrey
import ownCloudSDK
import ownCloudMocking

@testable import ownCloud

class MoveViewTests: XCTestCase {

	override func setUp() {
		super.setUp()
		OCBookmarkManager.deleteAllBookmarks(waitForServerlistRefresh: true)
		OCMockManager.shared.removeAllMockingBlocks()
	}

	override func tearDown() {
		super.tearDown()
		OCMockManager.shared.removeAllMockingBlocks()
	}

	/*
	* PASSED if: MoveView is shown
	*/
	func testShowMoveView() {

		if let bookmark: OCBookmark = UtilsTests.getBookmark() {
			//Mocks
			OCMockSwizzlingFileList.mockOCoreForBookmark(mockBookmark: bookmark)
			OCMockSwizzlingFileList.mockQueryPropfindResults(resourceName: "PropfindResponse", basePath: "/remote.php/dav/files/admin", state: .contentsFromCache)
			self.showFileList(bookmark: bookmark)

			//Actions
			EarlGrey.select(elementWithMatcher: grey_accessibilityID("ownCloud Manual.pdf-actions")).perform(grey_tap())

			//Mock again
			OCMockManager.shared.removeMockingBlock(atLocation: OCMockLocation.ocQueryRequestChangeSetWithFlags)
			OCMockSwizzlingFileList.mockQueryPropfindResults(resourceName: "PropfindResponseFolders", basePath: "/remote.php/dav/files/admin", state: .contentsFromCache)

			EarlGrey.select(elementWithMatcher: grey_accessibilityID("com.owncloud.action.move")).perform(grey_tap())

			//Asserts
			EarlGrey.select(elementWithMatcher: grey_accessibilityID("picker-select-button")).assert(grey_sufficientlyVisible())

			//Reset status
			EarlGrey.select(elementWithMatcher: grey_accessibilityID("picker-cancel-button")).perform(grey_tap())
			EarlGrey.select(elementWithMatcher: grey_allOf([grey_accessibilityLabel("Back"), grey_accessibilityTrait(UIAccessibilityTraits.staticText)])).perform(grey_tap())
		} else {
			assertionFailure("File list not loaded because Bookmark is nil")
		}
	}

	/*
	* PASSED if: All the flow of move a file to a different folder works
	*/
	func testNavigateMoreView() {

		if let bookmark: OCBookmark = UtilsTests.getBookmark() {
			//Mocks
			OCMockSwizzlingFileList.mockOCoreForBookmark(mockBookmark: bookmark)
			OCMockSwizzlingFileList.mockQueryPropfindResults(resourceName: "PropfindResponse", basePath: "/remote.php/dav/files/admin", state: .contentsFromCache)
			self.showFileList(bookmark: bookmark)

			//Actions
			EarlGrey.select(elementWithMatcher: grey_accessibilityID("ownCloud Manual.pdf-actions")).perform(grey_tap())

			//Mock again
			OCMockManager.shared.removeMockingBlock(atLocation: OCMockLocation.ocQueryRequestChangeSetWithFlags)
			OCMockSwizzlingFileList.mockQueryPropfindResults(resourceName: "PropfindResponseFolders", basePath: "/remote.php/dav/files/admin", state: .contentsFromCache)

			EarlGrey.select(elementWithMatcher: grey_accessibilityID("com.owncloud.action.move")).perform(grey_tap())

			EarlGrey.select(elementWithMatcher: grey_accessibilityID("picker-select-button")).assert(grey_sufficientlyVisible())

			//Mock again
			OCMockManager.shared.removeMockingBlock(atLocation: OCMockLocation.ocQueryRequestChangeSetWithFlags)
			OCMockSwizzlingFileList.mockQueryPropfindResults(resourceName: "PropfindResponseEmptyFolder", basePath: "/remote.php/dav/files/admin", state: .contentsFromCache)

			EarlGrey.select(elementWithMatcher: grey_accessibilityID("Photos")).perform(grey_tap())

			//Mock again
			OCMockManager.shared.removeMockingBlock(atLocation: OCMockLocation.ocQueryRequestChangeSetWithFlags)
			OCMockSwizzlingFileList.mockQueryPropfindResults(resourceName: "PropfindResponse", basePath: "/remote.php/dav/files/admin", state: .contentsFromCache)

			EarlGrey.select(elementWithMatcher: grey_accessibilityID("picker-select-button")).perform(grey_tap())

			//Assert
			EarlGrey.select(elementWithMatcher: grey_text("Server name")).assert(grey_sufficientlyVisible())

			//Reset status
			EarlGrey.select(elementWithMatcher: grey_allOf([grey_accessibilityLabel("Back"), grey_accessibilityTrait(UIAccessibilityTraits.staticText)])).perform(grey_tap())
		} else {
			assertionFailure("File list not loaded because Bookmark is nil")
		}
	}

	func showFileList(bookmark: OCBookmark, issue: OCIssue? = nil) {
		if let appDelegate: AppDelegate = UIApplication.shared.delegate as? AppDelegate {

			let query = MockOCQuery(path: "/")
			let core = MockOCCore(query: query, bookmark: bookmark, issue: issue)

			let rootViewController: MockClientRootViewController = MockClientRootViewController(core: core, query: query, bookmark: bookmark)

			appDelegate.serverListTableViewController?.navigationController?.navigationBar.prefersLargeTitles = false
			appDelegate.serverListTableViewController?.navigationController?.navigationItem.largeTitleDisplayMode = .never
			appDelegate.serverListTableViewController?.navigationController?.pushViewController(viewController: rootViewController, animated: true, completion: {
				appDelegate.serverListTableViewController?.navigationController?.setNavigationBarHidden(true, animated: false)
			})
		}
	}
}
