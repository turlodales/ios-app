//
//  OCLicenseEMMProvider.m
//  ownCloudApp
//
//  Created by Felix Schwarz on 18.05.20.
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

#import "OCLicenseEMMProvider.h"

@implementation OCLicenseEMMProvider

#pragma mark - Init
- (instancetype)initWithUnlockedProductIdentifiers:(NSArray<OCLicenseProductIdentifier> *)unlockedProductIdentifiers
{
	if ((self = [super initWithIdentifier:OCLicenseProviderIdentifierEMM]) != nil)
	{
		_unlockedProductIdentifiers = unlockedProductIdentifiers;
		self.localizedName = OCLocalizedString(@"EMM", nil);
	}

	return (self);
}

+ (BOOL)isEMMVersion
{
	NSBundle *appBundle;

	if ((appBundle = NSBundle.mainBundle) != nil)
	{
		if ([appBundle.bundleURL.pathExtension isEqual:@"appex"])
		{
			// Find container app bundle (ownCloud.app/PlugIns/Extension.appex)
			appBundle = [NSBundle bundleWithURL:appBundle.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent];
		}

		return (
			[appBundle.bundleIdentifier hasSuffix:@".emm"] || // BundleID of the main bundle ending in ".emm"
			[appBundle.bundleIdentifier hasSuffix:@"-emm"]    // BundleID of the main bundle ending in "-emm"
			);
	}
	
	return NO;
}

- (void)startProvidingWithCompletionHandler:(OCLicenseProviderCompletionHandler)completionHandler
{
	if (OCLicenseEMMProvider.isEMMVersion)
	{
		NSMutableArray<OCLicenseEntitlement *> *entitlements = [NSMutableArray new];

		for (OCLicenseProductIdentifier productIdentifier in self.unlockedProductIdentifiers)
		{
			OCLicenseEntitlement *entitlement;

			entitlement = [OCLicenseEntitlement entitlementWithIdentifier:nil forProduct:productIdentifier type:OCLicenseTypePurchase valid:YES expiryDate:nil applicability:nil]; // Valid entitlement for all environments

			[entitlements addObject:entitlement];
		}

		self.entitlements = (entitlements.count > 0) ? entitlements : nil;
	}

	completionHandler(self, nil);
}

@end

OCLicenseProviderIdentifier OCLicenseProviderIdentifierEMM = @"emm";
