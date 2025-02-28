//
//  OCItem+FileProviderItem.h
//  ownCloud File Provider
//
//  Created by Felix Schwarz on 08.06.18.
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

#import <ownCloudSDK/ownCloudSDK.h>

#if OC_FEATURE_AVAILABLE_FILEPROVIDER

@interface OCItem (FileProviderItem) <NSFileProviderItem>

- (void)setLocalFavoriteRank:(NSNumber *)localFavoriteRank;
- (void)setLocalTagData:(NSData *)localTagData;

- (void)setUploadingError:(NSError *)uploadingError;

@end

#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */
