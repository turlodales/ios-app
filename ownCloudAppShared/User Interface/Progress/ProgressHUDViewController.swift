//
//  ProgressHUDViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 08.05.18.
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

open class ProgressHUDViewController: UIViewController {
	open var progressContainer : UIView?
	open var progressSpinner : UIActivityIndicatorView?
	open var progressLabel : UILabel?
	var transitionAnimator = ProgressHUDViewControllerAnimator()

	open var presenting : Bool = false

	open var actionWaitGroup = DispatchGroup()

	override open func loadView() {
		let rootView = UIView()

		rootView.backgroundColor = UIColor.init(white: 0.0, alpha: 0.5)

		progressContainer = UIView()
		progressContainer?.translatesAutoresizingMaskIntoConstraints = false

		progressSpinner = UIActivityIndicatorView(style: .large)
		progressSpinner?.translatesAutoresizingMaskIntoConstraints = false

		progressLabel = UILabel()
		progressLabel?.translatesAutoresizingMaskIntoConstraints = false
		progressLabel?.numberOfLines = 0
		progressLabel?.textColor = .white

		progressContainer?.addSubview(progressSpinner!)
		progressContainer?.addSubview(progressLabel!)

		progressSpinner?.centerXAnchor.constraint(equalTo: (progressContainer?.centerXAnchor)!).isActive = true
		progressLabel?.centerXAnchor.constraint(equalTo: (progressContainer?.centerXAnchor)!).isActive = true
		progressLabel?.leftAnchor.constraint(greaterThanOrEqualTo: (progressContainer?.leftAnchor)!, constant: 10).isActive = true
		progressLabel?.rightAnchor.constraint(lessThanOrEqualTo: (progressContainer?.rightAnchor)!, constant: -10).isActive = true

		progressSpinner?.topAnchor.constraint(equalTo: (progressContainer?.topAnchor)!, constant: 10).isActive = true
		progressLabel?.topAnchor.constraint(equalTo: (progressSpinner?.bottomAnchor)!, constant: 10).isActive = true
		progressLabel?.bottomAnchor.constraint(equalTo: (progressContainer?.bottomAnchor)!, constant: -10).isActive = true

		rootView.addSubview(progressContainer!)

		progressContainer?.centerYAnchor.constraint(equalTo: rootView.centerYAnchor).isActive = true
		progressContainer?.centerXAnchor.constraint(equalTo: rootView.centerXAnchor).isActive = true

		progressContainer?.leftAnchor.constraint(greaterThanOrEqualTo: rootView.leftAnchor, constant: 10).isActive = true
		progressContainer?.rightAnchor.constraint(lessThanOrEqualTo: rootView.rightAnchor, constant: -10).isActive = true

		self.view = rootView
	}

	public init(on viewController: UIViewController? = nil, label: String? = nil) {
		super.init(nibName: nil, bundle: nil)

		self.modalPresentationStyle = .overCurrentContext
		self.transitioningDelegate = transitionAnimator

		self.present(on: viewController, label: label)
	}

	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	open func updateLabel(with text: String?) {
		progressLabel?.text = text
	}

	open func present(on viewController: UIViewController?, label: String? = nil) {
		if label != nil, self.view != nil {
			self.updateLabel(with: label)
		}

		if viewController != nil {
			if !presenting {
				presenting = true

				actionWaitGroup.enter()

				viewController?.present(self, animated: true) {
					self.actionWaitGroup.leave()
				}
			}
		}
	}

	open func dismiss(completion: (() -> Void)? = nil) {
		if presenting {
			DispatchQueue.global(qos: .userInitiated).async {
				self.actionWaitGroup.wait()

				OnMainThread {
					if self.presenting {
						self.presentingViewController?.dismiss(animated: true, completion: { [weak self] in
							self?.presenting = false
							completion?()
						})
					}
				}
			}
		} else {
			completion?()
		}
	}

	override open var preferredStatusBarStyle : UIStatusBarStyle {
		return Theme.shared.activeCollection.css.getStatusBarStyle(for: self) ?? .default
	}

	override open func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		progressSpinner?.startAnimating()
	}

	override open func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		progressSpinner?.stopAnimating()
	}
}

internal class ProgressHUDViewControllerAnimator : NSObject, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {
	var isDismissing : Bool = false
	let duration = 0.4

	// MARK: - UIViewControllerTransitioningDelegate
	func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		isDismissing = true
		return self
	}

	func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		isDismissing = false
		return self
	}

	// MARK: - UIViewControllerAnimatedTransitioning
	func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		return duration
	}

	func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		let containerView = transitionContext.containerView

		if isDismissing {
			if let fromView = transitionContext.view(forKey: .from) {
				let fromViewController = transitionContext.viewController(forKey: .from)
				let hudViewController = fromViewController as? ProgressHUDViewController

				if fromViewController != nil {
					fromView.frame = transitionContext.initialFrame(for: fromViewController!)
				}

				containerView.addSubview(fromView)

				UIView.animate(withDuration: duration, animations: {
					fromView.alpha = 0
					hudViewController?.progressContainer?.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
				}, completion: { (_) in
					transitionContext.completeTransition(true)
				})
			}
		} else {
			if let toView = transitionContext.view(forKey: .to) {
				let toViewController = transitionContext.viewController(forKey: .to)
				let hudViewController = toViewController as? ProgressHUDViewController

				if toViewController != nil {
					toView.frame = transitionContext.finalFrame(for: toViewController!)
				}

				containerView.addSubview(toView)

				toView.alpha = 0
				hudViewController?.progressContainer?.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)

				UIView.animate(withDuration: duration, animations: {
					toView.alpha = 1
					hudViewController?.progressContainer?.transform = .identity
				}, completion: { (_) in
					transitionContext.completeTransition(true)
				})
			}
		}
	}
}
