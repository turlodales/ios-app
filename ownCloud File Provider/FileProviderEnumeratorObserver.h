//
//  FileProviderEnumeratorObserver.h
//  ownCloud File Provider
//
//  Created by Felix Schwarz on 18.07.18.
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

#import <Foundation/Foundation.h>
#import <FileProvider/FileProvider.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface FileProviderEnumeratorObserver : NSObject

@property(strong) id<NSFileProviderEnumerationObserver> enumerationObserver;
@property(strong) NSFileProviderPage enumerationStartPage;
@property(assign) BOOL didProvideInitialItems;

@property(strong) id<NSFileProviderChangeObserver> changeObserver;
@property(strong) NSFileProviderSyncAnchor changesFromSyncAnchor;

@property(copy) dispatch_block_t enumerationCompletionHandler;

- (void)completeEnumeration;

@end
