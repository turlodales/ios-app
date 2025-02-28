//
//  NSObject+AnnotatedProperties.h
//  ownCloud
//
//  Created by Felix Schwarz on 09.09.19.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (AnnotatedProperties)

- (id)valueForAnnotatedProperty:(NSString *)annotatedPropertyName withGenerator:(id(^)(void))generator;

- (nullable id)valueForAnnotatedProperty:(NSString *)annotatedPropertyName;
- (void)setValue:(nullable id)value forAnnotatedProperty:(NSString *)annotatedPropertyName;

@end

NS_ASSUME_NONNULL_END
