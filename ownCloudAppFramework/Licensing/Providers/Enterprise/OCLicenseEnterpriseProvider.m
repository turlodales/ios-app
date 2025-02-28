//
//  OCLicenseEnterpriseProvider.m
//  ownCloudApp
//
//  Created by Felix Schwarz on 05.12.19.
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

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCLicenseEntitlement.h"
#import "OCLicenseEnterpriseProvider.h"
#import "OCLicenseProduct.h"
#import "OCLicenseFeature.h"

#import "OCBookmark+AppExtensions.h"
#import "OCLicenseManager.h"

@implementation OCLicenseEnterpriseProvider

+ (NSUInteger)numberOfEnterpriseAccounts
{
	NSUInteger enterpriseAccounts = 0;

	for (OCBookmark *bookmark in OCBookmarkManager.sharedBookmarkManager.bookmarks)
	{
		if ([((NSDictionary *)bookmark.userInfo[@"statusInfo"])[@"edition"] isEqual:@"Enterprise"])
		{
			enterpriseAccounts++;
		}
	}

	return (enterpriseAccounts);
}

#pragma mark - Init
- (instancetype)initWithUnlockedProductIdentifiers:(NSArray<OCLicenseProductIdentifier> *)unlockedProductIdentifiers
{
	if ((self = [super initWithIdentifier:OCLicenseProviderIdentifierEnterprise]) != nil)
	{
		_unlockedProductIdentifiers = unlockedProductIdentifiers;
		self.localizedName = OCLocalizedString(@"Enterprise", nil);
	}

	return (self);
}

- (void)startProvidingWithCompletionHandler:(OCLicenseProviderCompletionHandler)completionHandler
{
	NSMutableArray<OCLicenseEntitlement *> *entitlements = [NSMutableArray new];

	for (OCLicenseProductIdentifier productIdentifier in self.unlockedProductIdentifiers)
	{
		OCLicenseEntitlement *entitlement;

		entitlement = [OCLicenseEntitlement entitlementWithIdentifier:nil forProduct:productIdentifier type:OCLicenseTypePurchase valid:YES expiryDate:nil applicability:@"core.connection.serverEdition == \"Enterprise\" || bookmark.userInfo.statusInfo.edition == \"Enterprise\""];

		[entitlements addObject:entitlement];
	}

	self.entitlements = (entitlements.count > 0) ? entitlements : nil;

	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_sendIAPMessageChangedNotification) name:OCBookmarkManagerListChanged object:nil];

	[self _sendIAPMessageChangedNotification];

	completionHandler(self, nil);
}

- (void)stopProvidingWithCompletionHandler:(OCLicenseProviderCompletionHandler)completionHandler
{
	[NSNotificationCenter.defaultCenter removeObserver:self name:OCBookmarkManagerListChanged object:nil];

	completionHandler(self, nil);
}

- (void)_sendIAPMessageChangedNotification
{
	[NSNotificationCenter.defaultCenter postNotificationName:OCLicenseProviderInAppPurchaseMessageChangedNotification object:self];
}

- (nullable OCLicenseProduct *)_unlockedProductForFeature:(OCLicenseFeatureIdentifier)featureIdentifier
{
	for (OCLicenseProductIdentifier productIdentifier in self.unlockedProductIdentifiers)
	{
		OCLicenseProduct *product;

		if ((product = [self.manager productWithIdentifier:productIdentifier]) != nil)
		{
			if (featureIdentifier != nil)
			{
				if ([product.contents containsObject:featureIdentifier])
				{
					return (product);
				}
			}
			else
			{
				return (product);
			}
		}
	}

	return (nil);
}

- (NSString *)inAppPurchaseMessageForFeature:(OCLicenseFeatureIdentifier)featureIdentifier
{
	NSString *iapMessage = nil;
	OCLicenseProduct *unlockedProduct = nil;
	OCLicenseFeature *feature = nil;
	NSMutableSet<NSString *> *serverNames = [NSMutableSet new];

	if (featureIdentifier != nil)
	{
		feature = [self.manager featureWithIdentifier:featureIdentifier];
	}

	if ((unlockedProduct = [self _unlockedProductForFeature:featureIdentifier]) != nil)
	{
		for (OCBookmark *bookmark in OCBookmarkManager.sharedBookmarkManager.bookmarks)
		{
			if ([((NSDictionary *)bookmark.userInfo[@"statusInfo"])[@"edition"] isEqual:@"Enterprise"])
			{
				NSString *host = (bookmark.originURL.host != nil) ? bookmark.originURL.host : bookmark.url.host;

				if (host != nil)
				{
					[serverNames addObject:host];
				}
			}
		}

		if (serverNames.count > 0)
		{
			NSString *subject = (feature.localizedName != nil) ? feature.localizedName : unlockedProduct.localizedName;

			iapMessage = [NSString stringWithFormat:OCLocalizedString(@"%@ already unlocked for %@.", nil), subject, [serverNames.allObjects componentsJoinedByString:@", "]];
		}
	}

	return (iapMessage);
}

@end

OCLicenseProviderIdentifier OCLicenseProviderIdentifierEnterprise = @"enterprise";
