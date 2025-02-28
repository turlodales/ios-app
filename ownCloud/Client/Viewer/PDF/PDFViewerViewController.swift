//
//  PDFViewerViewController.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 29/08/2018.
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
import ownCloudAppShared
import PDFKit

class PulsatingButton: UIButton {

	override func layoutSubviews() {
		super.layoutSubviews()
		self.layer.cornerRadius = bounds.size.height / 2
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupShapes()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setupShapes()
	}

	fileprivate func setupShapes() {
		setNeedsLayout()
		layoutIfNeeded()

		self.layer.masksToBounds = true
		self.backgroundColor = .darkGray
		self.titleLabel?.textColor = .white
		self.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)

		let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
		pulseAnimation.duration = 0.7
		pulseAnimation.fromValue = 1.0
		pulseAnimation.toValue = 0.85
		pulseAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
		pulseAnimation.autoreverses = true
		pulseAnimation.repeatCount = 2
		layer.add(pulseAnimation, forKey: "transformScale")
	}
}

class PDFViewerViewController: DisplayViewController, DisplayExtension, UIPopoverPresentationControllerDelegate {

	enum ThumbnailViewPosition {
		case left, right, bottom, none
		func isVertical() -> Bool {
			return self == .bottom ? false : true
		}
	}

	static let PDFGoToPageNotification = Notification(name: Notification.Name(rawValue: "PDFGoToPageNotification"))

	public let pdfView = PDFView()

	private var gotoPageNotificationObserver : Any?

	private let searchAnnotationDelay = 3.0
	private let thumbnailViewWidthMultiplier: CGFloat = 0.15
	private let thumbnailViewHeightMultiplier: CGFloat = 0.1
	private let filenameContainerTopMargin: CGFloat = 10.0
	private let thumbnailView = PDFThumbnailView()

	private let containerView = UIStackView()
	private let pageCountContainerView = UIView()
	private let pageCountButton = PulsatingButton()

	private var searchButtonItem: UIBarButtonItem?
	private var gotoButtonItem: UIBarButtonItem?
	private var outlineItem: UIBarButtonItem?

	private var thumbnailViewPosition : ThumbnailViewPosition = .bottom {
		didSet {
			switch thumbnailViewPosition {
				case .left, .right:
					thumbnailView.layoutMode = .vertical
				case .bottom:
					thumbnailView.layoutMode = .horizontal
				default:
					break
			}

			pageCountButton.isHidden = thumbnailViewPosition == .none ? true : false

			setupConstraints()
		}
	}

	private var activeViewConstraints: [NSLayoutConstraint] = [] {
		willSet {
			NSLayoutConstraint.deactivate(activeViewConstraints)
		}
		didSet {
			NSLayoutConstraint.activate(activeViewConstraints)
		}
	}

	private var fullScreen: Bool = false {
		didSet {
			browserNavigationViewController?.setNavigationBarHidden(fullScreen, animated: true)
			isFullScreenModeEnabled = fullScreen
			pageCountButton.isHidden = fullScreen
			pageCountContainerView.isHidden = fullScreen
			setupConstraints()
		}
	}

	// MARK: - DisplayExtension

	static var customMatcher: OCExtensionCustomContextMatcher?
	static var displayExtensionIdentifier: String = "org.owncloud.pdfViewer.default"
	static var supportedMimeTypes: [String]? = ["application/pdf", "application/illustrator"]
	static var features: [String : Any]? = [FeatureKeys.canEdit : false]

	deinit {
		NotificationCenter.default.removeObserver(self)
		if gotoPageNotificationObserver != nil {
			NotificationCenter.default.removeObserver(gotoPageNotificationObserver!)
		}

	}

	private var didSetupView : Bool = false

	public let searchResultsView = PDFSearchResultsView()

	override func renderItem(completion: @escaping (Bool) -> Void) {
		if let source = itemDirectURL, let document = PDFDocument(url: source) {
			if !didSetupView {
				didSetupView  = true

				self.thumbnailViewPosition = .none

				// Configure thumbnail view
				thumbnailView.translatesAutoresizingMaskIntoConstraints = false
				thumbnailView.pdfView = pdfView
				thumbnailView.isExclusiveTouch = true

				self.view.addSubview(thumbnailView)

				containerView.spacing = UIStackView.spacingUseSystem
				containerView.isLayoutMarginsRelativeArrangement = true
				containerView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: filenameContainerTopMargin, leading: 0, bottom: 0, trailing: 0)
				containerView.translatesAutoresizingMaskIntoConstraints = false
				containerView.axis = .vertical
				containerView.distribution = .fill

				// Configure PDFView instance
				pdfView.displayDirection = .horizontal
				pdfView.translatesAutoresizingMaskIntoConstraints = false
				pdfView.usePageViewController(true, withViewOptions: nil)
				pdfView.delegate = self
				containerView.addArrangedSubview(pdfView)

				pageCountButton.translatesAutoresizingMaskIntoConstraints = false
				pageCountButton.accessibilityLabel = OCLocalizedString("Go to page", nil)
				pageCountButton.addTarget(self, action: #selector(goToPage), for: .touchDown)
				pageCountContainerView.translatesAutoresizingMaskIntoConstraints = false
				pageCountContainerView.addSubview(pageCountButton)

				pageCountButton.centerXAnchor.constraint(equalTo: pageCountContainerView.centerXAnchor).isActive = true
				pageCountButton.centerYAnchor.constraint(equalTo: pageCountContainerView.centerYAnchor).isActive = true
				pageCountButton.widthAnchor.constraint(equalTo: pageCountContainerView.widthAnchor, multiplier: 0.25).isActive = true
				pageCountButton.heightAnchor.constraint(equalTo: pageCountContainerView.heightAnchor, multiplier: 0.5).isActive = true
				pageCountButton.heightAnchor.constraint(lessThanOrEqualToConstant: 22.0).isActive = true

				containerView.addArrangedSubview(pageCountContainerView)

				self.view.addSubview(containerView)

				self.view.backgroundColor = self.pdfView.backgroundColor
				thumbnailView.backgroundColor = self.pdfView.backgroundColor
				pageCountContainerView.backgroundColor = self.pdfView.backgroundColor

				setupConstraints()

				self.view.layoutIfNeeded()
			}

			pdfView.document = document

			setupSearchResultsView()

			pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
			pdfView.autoScales = true
			updatePageLabel()
			setThumbnailPosition()

			completion(true)

		} else {
			completion(false)
		}
	}

	// MARK: - View lifecycle management
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(handlePageChanged), name: .PDFViewPageChanged, object: nil)

		gotoPageNotificationObserver = NotificationCenter.default.addObserver(forName: PDFViewerViewController.PDFGoToPageNotification.name, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
			if let page = notification.object as? PDFPage {
				self?.pdfView.go(to: page)
			}
		}

		let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.toggleFullscreen(_:)))
		tapRecognizer.numberOfTapsRequired = 2
		pdfView.addGestureRecognizer(tapRecognizer)
		supportsFullScreenMode = true
	}

	@objc func toggleFullscreen(_ sender: UITapGestureRecognizer) {
		self.fullScreen.toggle()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
		pdfView.autoScales = true
		self.calculateThumbnailSize()
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		coordinator.animate(alongsideTransition: nil) { (_) in
			self.calculateThumbnailSize()
		}
	}

	override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
		coordinator.animate(alongsideTransition: nil) { (_) in
			self.setThumbnailPosition()
			self.calculateThumbnailSize()
		}
	}

	func save(item: OCItem) {
		if let source = itemDirectURL {
			editingDelegate?.save(item: item, fileURL: source)
		}
	}

	// MARK: - Handlers for PDF View notifications

	@objc func handlePageChanged() {
		updatePageLabel()
	}

	// MARK: - Toolbar actions

	@objc func goToPage() {

		guard let pdfDocument = pdfView.document else { return }

		let alertMessage = NSString(format: OCLocalizedString("This document has %@ pages", nil) as NSString, "\(pdfDocument.pageCount)") as String
		let alertController = ThemedAlertController(title: OCLocalizedString("Go to page", nil), message: alertMessage, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: OCLocalizedString("Cancel", nil), style: .cancel, handler: nil))

		alertController.addTextField(configurationHandler: { textField in
			textField.placeholder = OCLocalizedString("Page", nil)
			textField.keyboardType = .decimalPad
		})

		alertController.addAction(UIAlertAction(title: OCLocalizedString("OK", nil), style: .default, handler: { [unowned self] _ in
			if let pageLabel = alertController.textFields?.first?.text {
				self.selectPage(with: pageLabel)
			}
			self.view.endEditing(true)
		}))

		self.present(alertController, animated: true)
	}

	@objc func search(sender: UIBarButtonItem?) {
		guard let pdfDocument = pdfView.document else { return }

		let pdfSearchController = PDFSearchViewController()
		let searchNavigationController = ThemeNavigationController(rootViewController: pdfSearchController)
		pdfSearchController.pdfDocument = pdfDocument
		// Interpret the search text and all the matches returned by search view controller
		pdfSearchController.userSelectedMatchCallback = { [weak self] (_, matches, selection) in
			DispatchQueue.main.async { [weak self] in
				if matches.count > 1 {
					self?.searchResultsView.matches = matches
					self?.searchResultsView.currentMatch = selection
					self?.showSearchResultsView()
				} else {
					self?.jumpTo(selection)
				}
			}
		}

		if UIDevice.current.userInterfaceIdiom == .pad, let sender = sender {
			searchNavigationController.modalPresentationStyle = .popover
			searchNavigationController.popoverPresentationController?.barButtonItem = sender
		}

		self.present(searchNavigationController, animated: true)
	}

	@objc func showOutline(sender: UIBarButtonItem?) {
		guard let pdfDocument = pdfView.document else { return }

		let outlineViewController = PDFOutlineViewController()
		let searchNavigationController = ThemeNavigationController(rootViewController: outlineViewController)
		outlineViewController.pdfDocument = pdfDocument

		if UIDevice.current.userInterfaceIdiom == .pad, let sender = sender {
			searchNavigationController.modalPresentationStyle = .popover
			searchNavigationController.popoverPresentationController?.barButtonItem = sender
		}

		self.present(searchNavigationController, animated: true)
	}

	// MARK: - Private helpers

	private func setThumbnailPosition() {
		if !UIDevice.current.isIpad, UIScreen.main.traitCollection.verticalSizeClass == .regular {
			self.thumbnailViewPosition = .bottom
		} else {
			self.thumbnailViewPosition = .right
		}
	}

	private func calculateThumbnailSize() {
		let maxHeight = floor( min(self.thumbnailView.bounds.size.height, self.thumbnailView.bounds.size.width)  * 0.6)
		self.thumbnailView.thumbnailSize = CGSize(width: maxHeight, height: maxHeight)
	}

	private func setupConstraints() {

		if thumbnailView.superview == nil || pdfView.superview == nil {
			return
		}

		let guide = view.safeAreaLayoutGuide

		var constraints = [NSLayoutConstraint]()
		constraints.append(containerView.topAnchor.constraint(equalTo: guide.topAnchor))

		thumbnailView.isHidden = false

		switch (thumbnailViewPosition, fullScreen) {
			case (_, true):
				constraints.append(containerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
				constraints.append(containerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
				constraints.append(containerView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
				thumbnailView.isHidden = true
			case (.left, false):
				constraints.append(thumbnailView.topAnchor.constraint(equalTo: guide.topAnchor))
				constraints.append(thumbnailView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
				constraints.append(thumbnailView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
				constraints.append(thumbnailView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: thumbnailViewWidthMultiplier))

				constraints.append(containerView.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor))
				constraints.append(containerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
				constraints.append(containerView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))

			case (.right, false):
				constraints.append(thumbnailView.topAnchor.constraint(equalTo: guide.topAnchor))
				constraints.append(thumbnailView.leadingAnchor.constraint(equalTo: containerView.trailingAnchor))
				constraints.append(thumbnailView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
				constraints.append(thumbnailView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
				constraints.append(thumbnailView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: thumbnailViewWidthMultiplier))

				constraints.append(containerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
				constraints.append(containerView.trailingAnchor.constraint(equalTo: thumbnailView.leadingAnchor))
				constraints.append(containerView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))

			case (.bottom, false):
				constraints.append(thumbnailView.topAnchor.constraint(equalTo: containerView.bottomAnchor))
				constraints.append(thumbnailView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
				constraints.append(thumbnailView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
				constraints.append(thumbnailView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
				constraints.append(thumbnailView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: thumbnailViewHeightMultiplier))

				constraints.append(containerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
				constraints.append(containerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
				constraints.append(containerView.bottomAnchor.constraint(equalTo: thumbnailView.topAnchor))

			case (.none, _):
				constraints.append(containerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
				constraints.append(containerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
				constraints.append(containerView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
				thumbnailView.isHidden = true
		}

		self.activeViewConstraints = constraints

	}

	override func composedDisplayBarButtonItems(previous: [UIBarButtonItem]? = nil, itemName: String, itemRemoved: Bool = false) -> [UIBarButtonItem]? {
		searchButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(search))
		outlineItem = UIBarButtonItem(image: UIImage(named: "ic_pdf_outline"), style: .plain, target: self, action: #selector(showOutline))

		searchButtonItem?.accessibilityLabel = OCLocalizedString("Search PDF", nil)
		outlineItem?.accessibilityLabel = OCLocalizedString("Outline", nil)

		return [
			actionBarButtonItem,
			searchButtonItem!,
			outlineItem!
		]
	}

	// MARK: - Search results navigation

	private func setupSearchResultsView() {
		self.searchResultsView.isHidden = true

		self.pdfView.addSubview(searchResultsView)

		let viewDictionary = ["searchResulsView": searchResultsView]
		var constraints: [NSLayoutConstraint] = []

		let vertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-20-[searchResulsView(48)]-(>=1)-|", metrics: nil, views: viewDictionary)
		let horizontal = NSLayoutConstraint.constraints(withVisualFormat: "H:|-20-[searchResulsView]-20-|", metrics: nil, views: viewDictionary)
		constraints += vertical
		constraints += horizontal
		NSLayoutConstraint.activate(constraints)

		self.searchResultsView.updateHandler = { [weak self] selection in
			self?.jumpTo(selection)
		}

		self.searchResultsView.closeHandler = { [weak self] in
			self?.hideSearchResultsView()
		}
	}

	private func showSearchResultsView() {
		self.searchResultsView.isHidden = false
		self.searchResultsView.alpha = 0.0
		UIView.animate(withDuration: 0.25, animations: {
			self.searchResultsView.alpha = 1.0
		})
	}

	private func hideSearchResultsView() {
		UIView.animate(withDuration: 0.25, animations: {
			self.searchResultsView.alpha = 0.0
		}, completion: { (complete) in
			self.searchResultsView.isHidden = complete
		})
	}

	private func jumpTo(_ selection: PDFSelection) {
		selection.color = UIColor.yellow
		self.pdfView.go(to: selection)
		self.pdfView.setCurrentSelection(selection, animate: true)

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			self.pdfView.setCurrentSelection(nil, animate: true)
		}
	}

	// MARK: - Current page selection
	private func selectPage(with label:String) {
		guard let pdf = pdfView.document else { return }

		if let pageNr = Int(label) {
			if pageNr > 0 && pageNr <= pdf.pageCount {
				if let page = pdf.page(at: pageNr - 1) {
					self.pdfView.go(to: page)
				}
			} else {
				let alertController = ThemedAlertController(title: OCLocalizedString("Invalid Page", nil),
									    message: OCLocalizedString("The entered page number doesn't exist", nil),
									    preferredStyle: .alert)
				alertController.addAction(UIAlertAction(title: OCLocalizedString("OK", nil), style: .default, handler: nil))
				self.present(alertController, animated: true, completion: nil)
			}
		}
	}

	private func updatePageLabel() {
		guard let pdf = pdfView.document else { return }

		guard let page = pdfView.currentPage else { return }

		let pageNrText = "\(pdf.index(for: page) + 1)"
		let maxPageCountText = "\(pdf.pageCount)"
		let title = NSString(format: OCLocalizedString("%@ of %@", nil) as NSString, pageNrText, maxPageCountText) as String
		pageCountButton.setTitle(title, for: .normal)
	}
}

extension PDFViewerViewController : PDFViewDelegate {
    func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
    	VendorServices.shared.openSFWebView(on: self, for: url)
    }
}
