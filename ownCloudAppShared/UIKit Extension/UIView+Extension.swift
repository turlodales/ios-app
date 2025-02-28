//
//  UIView+Extension.swift
//  ownCloud
//
//  Created by Felix Schwarz on 07.05.18.
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

public extension UIView {
	// MARK: - Animation
	func shakeHorizontally(amplitude : CGFloat = 20, duration : CFTimeInterval = 0.5) {
		let animation : CAKeyframeAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")

		animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
		animation.duration = duration
		animation.values = [ 0, -amplitude, amplitude, -amplitude, amplitude, -amplitude, amplitude, 0 ]

		self.layer.add(animation, forKey: "shakeHorizontally")
	}

	func beginPulsing(duration: TimeInterval = 1) {
		let pulseAnimation = CABasicAnimation(keyPath: "opacity")

		pulseAnimation.fromValue = 1
		pulseAnimation.toValue = 0.3
		pulseAnimation.repeatCount = .infinity
		pulseAnimation.autoreverses = true
		pulseAnimation.duration = duration

		layer.add(pulseAnimation, forKey: "opacity")
	}

	func endPulsing() {
		layer.removeAnimation(forKey: "opacity")
	}

	// MARK: - View hierarchy
	func findSubviewInTree(where filter: (UIView) -> Bool) -> UIView? {
		for subview in subviews {
			if filter(subview) {
				return subview
			} else {
				if let foundSubview = subview.findSubviewInTree(where: filter) {
					return foundSubview
				}
			}
		}

		return nil
	}

	// MARK: - View controller
	var hostingViewController: UIViewController? {
		var responder: UIResponder? = self
		var hostViewController: UIViewController?

		while hostViewController == nil && responder != nil {
			if let viewController = responder as? UIViewController {
				hostViewController = viewController
			}

			responder = responder?.next
		}

		return hostViewController
	}
}
