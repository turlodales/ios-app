//
//  OCScanJobActivity+DiagnosticGenerator.swift
//  ownCloud
//
//  Created by Felix Schwarz on 01.08.20.
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

extension OCScanJobActivity : DiagnosticNodeGenerator {
	var isDiagnosticNodeGenerationAvailable : Bool {
		return DiagnosticManager.shared.enabled
	}

	func provideDiagnosticNode(for context: OCDiagnosticContext, completion: @escaping (OCDiagnosticNode?, DiagnosticViewController.Style) -> Void) {
		var diagnosticNodes : [OCDiagnosticNode] = []

		diagnosticNodes.append(OCDiagnosticNode.withLabel(OCLocalizedString("Completed update scans", nil), content: "\(self.completedUpdateJobs)"))
		diagnosticNodes.append(OCDiagnosticNode.withLabel(OCLocalizedString("Total update scans", nil), content: "\(self.totalUpdateJobs)"))

		completion(OCDiagnosticNode.withLabel(OCLocalizedString("Update Status", nil), children: diagnosticNodes), .flat)
	}
}
