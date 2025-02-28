//
//  FileProviderExtension.m
//  ownCloud File Provider
//
//  Created by Felix Schwarz on 07.06.18.
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

// BEGIN: Shared with ownCloudApp.framework
#import "Branding.h"
#import "BrandingClassSettingsSource.h"
#import "NotificationManager.h"
#import "NotificationMessagePresenter.h"
#import "NotificationAuthErrorForwarder.h"
#import "OCBookmark+AppExtensions.h"
#import "OCBookmark+FPServices.h"
#import "OCCore+BundleImport.h"
#import "OCFileProviderSettings.h"
#import "VFSManager.h"
#import "AppLockSettings.h"
// END: shared with ownCloudApp.framework

#import "FileProviderExtension.h"
#import "OCItem+FileProviderItem.h"
#import "FileProviderExtensionThumbnailRequest.h"
#import "NSError+MessageResolution.h"
#import "FileProviderServiceSource.h"
#import "FileProviderContentEnumerator.h"

@interface FileProviderExtension ()
{
	NSFileCoordinator *_fileCoordinator;
	NotificationMessagePresenter *_messagePresenter;

	OCVFSCore *_vfsCore;

	BOOL _skipAuthorizationFailure;
}

@property (nonatomic, readonly, strong) NSFileManager *fileManager;

@end

@implementation FileProviderExtension

@synthesize core;
@synthesize bookmark;

- (instancetype)init
{
	[OCLogger logLevel]; // Make sure +logLevel is called in File Provider, to properly set up the log level

	NSDictionary *bundleInfoDict = [[NSBundle bundleForClass:[FileProviderExtension class]] infoDictionary];

	OCAppIdentity.sharedAppIdentity.appIdentifierPrefix = bundleInfoDict[@"OCAppIdentifierPrefix"];
	OCAppIdentity.sharedAppIdentity.keychainAccessGroupIdentifier = bundleInfoDict[@"OCKeychainAccessGroupIdentifier"];
	OCAppIdentity.sharedAppIdentity.appGroupIdentifier = bundleInfoDict[@"OCAppGroupIdentifier"];

	if (self = [super init]) {
		_fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		_fileManager = [NSFileManager new];
	}

	[OCHTTPPipelineManager setupPersistentPipelines]; // Set up HTTP pipelines

	[self addObserver:self forKeyPath:@"domain" options:0 context:(__bridge void *)self];

	// [self postAlive];

	return self;
}

//- (void)postAlive
//{
//	OCLogDebug(@"Alive…");
//
//	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//		[self postAlive];
//	});
//}

- (OCVFSCore *)vfsCore
{
	if (_vfsCore == nil)
	{
		_vfsCore = [VFSManager.sharedManager vfsForBookmark:self.bookmark];
	}

	return (_vfsCore);
}

- (void)dealloc
{
	OCLogDebug(@"Deallocating FileProvider %@", self);

	[_fileCoordinator cancel];

	[self removeObserver:self forKeyPath:@"domain" context:(__bridge void *)self];

	if (_core != nil)
	{
		if (_messagePresenter != nil)
		{
			OCLogDebug(@"Removing Message Presenter for FileProvider %@", self);
			[core.messageQueue removePresenter:_messagePresenter];
		}

		OCLogDebug(@"Returning OCCore for FileProvider %@", self);
		[[OCCoreManager sharedCoreManager] returnCoreForBookmark:self.bookmark completionHandler:nil];
		_core = nil;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	if ((context == (__bridge void *)self) && [keyPath isEqual:@"domain"])
	{
		OCLogDebug(@"Domain set: %@", self.domain);

		if (self.bookmark != nil)
		{
			if (![OCVault vaultInitializedForBookmark:self.bookmark])
			{
				OCLogDebug(@"Initial root container scan..");

				OCQuery *query = [OCQuery queryForLocation:OCLocation.legacyRootLocation];
				__weak OCCore *weakCore = self.core;

				query.changesAvailableNotificationHandler = ^(OCQuery *query) {
					if (query.state == OCQueryStateIdle)
					{
						[weakCore stopQuery:query];
					}

				};

				[self.core startQuery:query];
			}
		}

		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - ItemIdentifier & URL lookup
- (NSFileProviderItem)itemForIdentifier:(NSFileProviderItemIdentifier)identifier error:(NSError *__autoreleasing  _Nullable *)outError
{
	NSFileProviderItem item = nil;
	NSError *returnError = nil;

	if (identifier == nil)
	{
		returnError = OCError(OCErrorInvalidParameter);
	}

	if (returnError == nil)
	{
		if ([identifier isEqual:NSFileProviderRootContainerItemIdentifier] || [identifier isEqual:OCVFSItemIDRoot])
		{
			item = (NSFileProviderItem)self.vfsCore.rootNode;
		}
		else
		{
			item = (NSFileProviderItem)[self.vfsCore itemForIdentifier:(OCVFSItemID)identifier error:&returnError];
		}
	}

	OCLogDebug(@"-itemForIdentifier:error: %@ resolved into %@ / %@", identifier, item, returnError);

	if ((item == nil) && (returnError == nil) && (identifier != nil))
	{
		returnError = [NSError fileProviderErrorForNonExistentItemWithIdentifier:identifier];
	}

	OCLogDebug(@"-itemForIdentifier:error: %@ returned as %@ / %@", identifier, item, returnError);

	if (outError != NULL)
	{
		*outError = [returnError translatedError];
	}

	return (item);
}

- (OCItem *)ocItemForIdentifier:(NSFileProviderItemIdentifier)identifier vfsNode:(OCVFSNode **)outNode error:(NSError *__autoreleasing  _Nullable *)outError
{
	id item;
	NSError *resolutionError = nil;

	if ((item = [self itemForIdentifier:identifier error:&resolutionError]) != nil)
	{
		if ([item isKindOfClass:OCItem.class])
		{
			return (item);
		}

		if ([item isKindOfClass:OCVFSNode.class])
		{
			OCVFSNode *vfsNode = (OCVFSNode *)item;

			if (outNode != NULL)
			{
				*outNode = vfsNode;
			}

			if (vfsNode.location != nil)
			{
				return (vfsNode.locationItem);
			}
		}
	}

	OCLogDebug(@"-ocItemForIdentifier:%@ could not find/return OCItem (resolutionError=%@)", identifier, resolutionError);

	if (outError != NULL)
	{
		NSError *error;

		if (identifier != nil)
		{
			error = [NSError fileProviderErrorForNonExistentItemWithIdentifier:identifier];
		}
		else
		{
			error = (resolutionError != nil) ? resolutionError : OCError(OCErrorInvalidParameter);
		}

		*outError = [error translatedError];
	}

	return (nil);
}

- (NSURL *)URLForItemWithPersistentIdentifier:(NSFileProviderItemIdentifier)identifier
{
//	OCItem *item;
	NSURL *url = nil;

	url = [self.vfsCore urlForItemIdentifier:(OCVFSItemID)identifier];

//	if ((item = (OCItem *)[self itemForIdentifier:identifier error:NULL]) != nil)
//	{
//		url = [self.core localURLForItem:item];
//	}

	// OCLogDebug(@"-URLForItemWithPersistentIdentifier: %@ => %@", identifier, url);

	return (url);

	/*
	// resolve the given identifier to a file on disk

	// in this implementation, all paths are structured as <base storage directory>/<item identifier>/<item file name>
	NSFileProviderManager *manager = [NSFileProviderManager defaultManager];
	NSURL *perItemDirectory = [manager.documentStorageURL URLByAppendingPathComponent:identifier isDirectory:YES];

	return [perItemDirectory URLByAppendingPathComponent:item.filename isDirectory:NO];
	*/
}

- (NSFileProviderItemIdentifier)persistentIdentifierForItemAtURL:(NSURL *)url
{
	// resolve the given URL to a persistent identifier using a database

	// OCLogDebug(@"-persistentIdentifierForItemAtURL: %@", (pathComponents[pathComponents.count - 2]));

	if ([url.lastPathComponent isEqual:self.bookmark.fpServicesURLComponentName])
	{
		return (url.lastPathComponent);
	}

	return ([self.vfsCore itemIdentifierForURL:url]);
}

- (nullable OCItem *)cachedItemInParent:(OCItem *)parentItem withName:(NSString *)name isDirectory:(BOOL)isDirectory error:(__autoreleasing NSError * _Nullable * _Nullable)outError
{
	OCItem *item;

	if ((item = [self.core cachedItemInParent:parentItem withName:name isDirectory:isDirectory error:outError]) != nil)
	{
		item.bookmarkUUID = self.core.bookmark.uuid.UUIDString;
	}

	return (item);
}

- (void)providePlaceholderAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
	NSFileProviderItemIdentifier identifier = [self persistentIdentifierForItemAtURL:url];
	if (identifier == nil)
	{
		completionHandler([NSError errorWithDomain:NSFileProviderErrorDomain code:NSFileProviderErrorNoSuchItem userInfo:nil]);
		return;
	}

	NSError *error = nil;
	NSFileProviderItem fileProviderItem = [self itemForIdentifier:identifier error:&error];
	if (fileProviderItem == nil)
	{
		completionHandler(error);
		return;
	}
	NSURL *placeholderURL = [NSFileProviderManager placeholderURLForURL:url];

	[[NSFileManager defaultManager] createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:NULL];

	if (![NSFileProviderManager writePlaceholderAtURL:placeholderURL withMetadata:fileProviderItem error:&error]) {
		completionHandler(error);
		return;
	}
	completionHandler(nil);
}

- (void)startProvidingItemAtURL:(NSURL *)provideAtURL completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	NSFileProviderItemIdentifier itemIdentifier = nil;
	NSFileProviderItem item = nil;

	FPLogCmdBegin(@"StartProviding", @"Start of startProvidingItemAtURL=%@", provideAtURL);

	if ((itemIdentifier = [self persistentIdentifierForItemAtURL:provideAtURL]) != nil)
	{
		 if ((item = [self itemForIdentifier:itemIdentifier error:&error]) != nil)
		 {
			FPLogCmdBegin(@"StartProviding", @"Downloading %@", item);

			if (((OCItem *)item).type == OCItemTypeCollection) {
				// Can't download folders
				completionHandler([NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{}]);
				return;
			}

			[self.core downloadItem:(OCItem *)item options:@{

				OCCoreOptionAddFileClaim : [OCClaim claimForLifetimeOfCore:core explicitIdentifier:OCClaimExplicitIdentifierFileProvider withLockType:OCClaimLockTypeRead]

			} resultHandler:^(NSError *error, OCCore *core, OCItem *item, OCFile *file) {
				OCLogDebug(@"Starting to provide file:\nPAU: %@\nFURL: %@\nID: %@\nErr: %@\nlocalRelativePath: %@", provideAtURL, file.url, item.itemIdentifier, error, item.localRelativePath);

				if ([error isOCErrorWithCode:OCErrorCancelled])
				{
					// If we provide a real error here, the Files app will show an error "File not found".
					error = nil;
				}

				FPLogCmd(@"Completed with error=%@", error);

				completionHandler([error translatedError]);
			}];

			return;
		 }
	}

	FPLogCmd(@"Completed with featureUnsupportedError");

	completionHandler([NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{}]);

	// ### Apple template comments: ###

	// Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler

	/* TODO:
	 This is one of the main entry points of the file provider. We need to check whether the file already exists on disk,
	 whether we know of a more recent version of the file, and implement a policy for these cases. Pseudocode:

	 if (!fileOnDisk) {
	 downloadRemoteFile();
	 callCompletion(downloadErrorOrNil);
	 } else if (fileIsCurrent) {
	 callCompletion(nil);
	 } else {
	 if (localFileHasChanges) {
	 // in this case, a version of the file is on disk, but we know of a more recent version
	 // we need to implement a strategy to resolve this conflict
	 moveLocalFileAside();
	 scheduleUploadOfLocalFile();
	 downloadRemoteFile();
	 callCompletion(downloadErrorOrNil);
	 } else {
	 downloadRemoteFile();
	 callCompletion(downloadErrorOrNil);
	 }
	 }
	 */
}


- (void)itemChangedAtURL:(NSURL *)changedItemURL
{
	NSError *error = nil;
	NSFileProviderItemIdentifier itemIdentifier = nil;
	NSFileProviderItem item = nil, parentItem = nil;

	if ((itemIdentifier = [self persistentIdentifierForItemAtURL:changedItemURL]) != nil)
	{
		 if ((item = [self itemForIdentifier:itemIdentifier error:&error]) != nil)
		 {
			if ((parentItem = [self itemForIdentifier:item.parentItemIdentifier error:&error]) != nil)
			{
				OCItem *ocItem = OCTypedCast(item, OCItem);
				OCItem *ocParentItem = OCTypedCast(parentItem, OCItem);

				if ((ocParentItem == nil) && (ocItem != nil))
				{
					// If parentItem is returned as a OCVFSNode, fetch the parent folder OCItem from the cache
					OCLocation *parentLocation = ocItem.location.parentLocation;

					if (parentLocation != nil)
					{
						ocParentItem = [self.core cachedItemAtLocation:ocItem.location.parentLocation error:&error];
					}
				}

				if ((ocItem != nil) && (ocParentItem != nil))
				{
					[self.core reportLocalModificationOfItem:(OCItem *)item parentItem:(OCItem *)ocParentItem withContentsOfFileAtURL:changedItemURL isSecurityScoped:NO options:nil placeholderCompletionHandler:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
						OCLogDebug(@"Upload of update finished with error=%@ item=%@", error, item);
					}];

					return;
				}
			}
		 }
	}

	OCLogError(@"-itemChangedAtURL: called, but item and/or parentItem couldn't be resolved properly: item=%@, parentItem=%@", item, parentItem);

	// ### Apple template comments: ###

	// Called at some point after the file has changed; the provider may then trigger an upload

	/* TODO:
	 - mark file at <url> as needing an update in the model
	 - if there are existing NSURLSessionTasks uploading this file, cancel them
	 - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
	 - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
	 */
}

- (void)stopProvidingItemAtURL:(NSURL *)url
{
	NSError *error = nil;
	NSFileProviderItemIdentifier itemIdentifier = nil;
	NSFileProviderItem item = nil;

	FPLogCmdBegin(@"StopProviding", @"Start of stopProvidingItemAtURL=%@", url);

	if ((itemIdentifier = [self persistentIdentifierForItemAtURL:url]) != nil)
	{
		 if ((item = [self itemForIdentifier:itemIdentifier error:&error]) != nil)
		 {
			NSArray <NSProgress *> *downloadProgress = nil;

		 	// Cancel download if the item is currently downloading
		 	if (item.isDownloading)
		 	{
				if ((downloadProgress = [self.core progressForItemWithLocalID:((OCItem *)item).localID matchingEventType:OCEventTypeDownload]) != nil)
		 		{
		 			[downloadProgress makeObjectsPerformSelector:@selector(cancel)];
				}
			}

			FPLogCmd(@"Item %@ is downloading %d: %@", item, item.isDownloading, downloadProgress);

			// Remove temporary FileProvider claim
			[core removeClaimsWithExplicitIdentifier:OCClaimExplicitIdentifierFileProvider onItem:(OCItem *)item refreshItem:YES completionHandler:nil];
		 }
	}

	// ### Apple template comments: ###

	// Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.

	// TODO: look up whether the file has local changes
	//	BOOL fileHasLocalChanges = NO;
	//
	//	if (!fileHasLocalChanges) {
	//		// remove the existing file to free up space
	//		[[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
	//
	//		// write out a placeholder to facilitate future property lookups
	//		[self providePlaceholderAtURL:url completionHandler:^(NSError * __nullable error) {
	//			// TODO: handle any error, do any necessary cleanup
	//		}];
	//	}
}

#pragma mark - Actions

// ### Apple template comments: ###

/* TODO: implement the actions for items here
 each of the actions follows the same pattern:
 - make a note of the change in the local model
 - schedule a server request as a background task to inform the server of the change
 - call the completion block with the modified item in its post-modification state
 */

- (void)createDirectoryWithName:(NSString *)directoryName inParentItemIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable, NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	OCItem *parentItem;

	if (!OCFileProviderSettings.browseable)
	{
		completionHandler(nil, [OCErrorWithDescription(OCErrorInternal, OCLocalizedString(@"File Provider access has been disabled by the administrator. Please use the app to create new folders.", nil)) translatedError]);
		return;
	}

	FPLogCmdBegin(@"CreateDir", @"Start of createDirectoryWithName=%@, inParentItemIdentifier=%@", directoryName, parentItemIdentifier);

	if ((parentItem = [self ocItemForIdentifier:parentItemIdentifier vfsNode:NULL error:&error]) != nil)
	{
		// Detect collission with existing items
		FPLogCmd(@"Creating folder %@ inside %@", directoryName, parentItem.path);

		if (!self.skipLocalErrorChecks)
		{
			OCItem *existingItem;

			if ((existingItem = [self cachedItemInParent:parentItem withName:directoryName isDirectory:YES error:NULL]) != nil)
			{
				FPLogCmd(@"Completed with collission with existingItem=%@ (locally detected)", existingItem);
				if (@available(iOS 13.3, *))
				{
					completionHandler(nil, [NSError fileProviderErrorForCollisionWithItem:existingItem]); // This is what we should do according to docs
				}
				else
				{
					completionHandler(nil, [OCError(OCErrorItemAlreadyExists) translatedError]); // This is what we need to do to avoid users running into issues using the broken Files "Duplicate" action
				}
				return;
			}
		}

		__block BOOL calledCompletionHandler = NO;

		[self.core createFolder:directoryName inside:parentItem options:nil placeholderCompletionHandler:^(NSError * _Nullable error, OCItem * _Nullable item) {
			FPLogCmd(@"Completed placeholder creation with item=%@, error=%@", item, error);

			if (!calledCompletionHandler)
			{
				calledCompletionHandler = YES;
				completionHandler(item, [error translatedError]);
			}
		} resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
			if (error != nil)
			{
				if (error.HTTPStatus.code == OCHTTPStatusCodeMETHOD_NOT_ALLOWED)
				{
					// Folder already exists on the server
					OCItem *existingItem;

					if ((existingItem = [self cachedItemInParent:parentItem withName:directoryName isDirectory:YES error:NULL]) != nil)
					{
						FPLogCmd(@"Completed with collission with existingItem=%@ (server response)", existingItem);
						if (@available(iOS 13.3, *))
						{
							if (!calledCompletionHandler)
							{
								calledCompletionHandler = YES;
								completionHandler(nil, [NSError fileProviderErrorForCollisionWithItem:existingItem]); // This is what we should do according to docs
							}
						}
						else
						{
							if (!calledCompletionHandler)
							{
								calledCompletionHandler = YES;
								completionHandler(nil, [OCError(OCErrorItemAlreadyExists) translatedError]); // This is what we need to do to avoid users running into issues using the broken Files "Duplicate" action
							}
						}
						return;
					}
				}
			}

			FPLogCmd(@"Completed with item=%@, error=%@", item, error);

			if (!calledCompletionHandler)
			{
				calledCompletionHandler = YES;
				completionHandler(item, [error translatedError]);
			}
		}];
	}
	else
	{
		FPLogCmd(@"Completed with parentItemNotFoundFor=%@, error=%@", parentItemIdentifier, error);

		completionHandler(nil, error);
	}
}

- (void)reparentItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier toParentItemWithIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier newName:(NSString *)newName completionHandler:(void (^)(NSFileProviderItem _Nullable reparentedItem, NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	OCItem *item=nil, *parentItem=nil;

	FPLogCmdBegin(@"Reparent", @"Start of reparentItemWithIdentifier=%@, toParentItemWithIdentifier=%@, newName=%@", itemIdentifier, parentItemIdentifier, newName);

	if (((item = [self ocItemForIdentifier:itemIdentifier vfsNode:NULL error:&error]) != nil) &&
	    ((parentItem = [self ocItemForIdentifier:parentItemIdentifier vfsNode:NULL error:&error]) != nil))
	{
		FPLogCmd(@"Moving %@ to %@ as %@", item, parentItem, ((newName != nil) ? newName : item.name));

		[self.core moveItem:item to:parentItem withName:((newName != nil) ? newName : item.name) options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
			FPLogCmd(@"Completed with item=%@, error=%@", item, error);

			completionHandler(item, [error translatedError]);
		}];
	}
	else
	{
		if (([error.domain isEqual:NSFileProviderErrorDomain] && error.code == NSFileProviderErrorNoSuchItem) && (parentItem == nil) && (item != nil))
		{
			// When moving files from one OC bookmark to another, the Files app will call with the ID of the item to move on this server
			// and the ID on the destination server for the item to move to. For now, we provide an error message covering that case. A
			// future release could possibly go through the bookmarks, request the cores, search for the item IDs, etc. - and then implement
			// a cross-server move using OCCore actions. The complexity of such an undertaking should not be underestimated, though, as in
			// the case of moving folders, we'd have to download and upload entire hierarchies of files - that could change while we're at it.
			FPLogCmd(@"parentItem not found. Likely a cross-domain move. Changing error message accordingly.");
			error = OCErrorWithDescription(OCErrorItemNotFound, OCLocalizedString(@"The destination folder couldn't be found on this server. Moving items across servers is currently not supported.", nil));
		}

		FPLogCmd(@"Completed with item=%@ or parentItem=%@ not found, error=%@", item, parentItem, error);
		completionHandler(nil, [error translatedError]);
	}
}

- (void)renameItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier toName:(NSString *)itemName completionHandler:(void (^)(NSFileProviderItem renamedItem, NSError *error))completionHandler
{
	NSError *error = nil;
	OCItem *item;

	FPLogCmdBegin(@"Rename", @"Start of renameItemWithIdentifier=%@, toName=%@", itemIdentifier, itemName);

	if ((item = [self ocItemForIdentifier:itemIdentifier vfsNode:NULL error:&error]) != nil)
	{
		FPLogCmd(@"Renaming %@ in %@ to %@", item, item.path.parentPath, itemName);

		[self.core renameItem:item to:itemName options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
			FPLogCmd(@"Completed with item=%@, error=%@", item, error);
			completionHandler(item, [error translatedError]);
		}];
	}
	else
	{
		FPLogCmd(@"Completed with item=%@ not found, error=%@", item, error);
		completionHandler(nil, error);
	}
}

- (void)deleteItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	OCItem *item;
	OCVFSNode *vfsNode = nil;

	FPLogCmdBegin(@"Delete", @"Start of deleteItemWithIdentifier=%@", itemIdentifier);

	item = [self ocItemForIdentifier:itemIdentifier vfsNode:&vfsNode error:&error];

//	if (vfsNode != nil)
//	{
//		FPLogCmd(@"Rejecting deletion of %@", vfsNode);
//		completionHandler([NSError fileProviderErrorForRejectedDeletionOfItem:]);
//		return;
//	}

	if (item != nil)
	{
		FPLogCmd(@"Deleting %@", item);

		[self.core deleteItem:item requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
			FPLogCmd(@"Completed with error=%@", error);
			completionHandler([error translatedError]);
		}];
	}
	else
	{
		FPLogCmd(@"Completed with item=%@ not found, error=%@", item, error);
		completionHandler(error);
	}
}

- (void)importDocumentAtURL:(NSURL *)fileURL toParentItemIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable, NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	BOOL stopAccess = NO;

	if (!OCFileProviderSettings.browseable)
	{
		completionHandler(nil, [OCErrorWithDescription(OCErrorInternal, OCLocalizedString(@"File Provider access has been disabled by the administrator. Please use the share extension to import files.", nil)) translatedError]);
		return;
	}

	if (![Branding.sharedBranding isImportMethodAllowed:BrandingFileImportMethodFileProvider])
	{
		completionHandler(nil, [OCErrorWithDescription(OCErrorInternal, OCLocalizedString(@"Importing files through the File Provider is not allowed on this device.", nil)) translatedError]);

		return;
	}

	if ([fileURL startAccessingSecurityScopedResource])
	{
		stopAccess = YES;
	}

	FPLogCmdBegin(@"Import", @"Start of importDocumentAtURL=%@, toParentItemIdentifier=%@, attributes=%@", fileURL, parentItemIdentifier, [NSFileManager.defaultManager attributesOfItemAtPath:fileURL.path error:nil]);

	[_fileCoordinator coordinateReadingItemAtURL:fileURL options:NSFileCoordinatorReadingWithoutChanges|NSFileCoordinatorReadingForUploading error:&error byAccessor:^(NSURL * _Nonnull readURL) {
		NSError *error = nil;
		BOOL isImportingFromVault = NO;
		BOOL importByCopying = NO;
		NSString *importFileName = readURL.lastPathComponent;
		OCItem *parentItem;

		FPLogCmd(@"Coordinated read of readURL=%@, toParentItemIdentifier=%@, attributes=%@", readURL, parentItemIdentifier, [NSFileManager.defaultManager attributesOfItemAtPath:readURL.path error:nil]);

		// Detect import of documents from our own internal storage (=> used by Files.app for duplication of files)
		isImportingFromVault = [readURL.path hasPrefix:self.core.vault.filesRootURL.path];

		if (isImportingFromVault)
		{
			NSFileProviderItemIdentifier sourceItemIdentifier;

			// Determine source item
			if (((sourceItemIdentifier = [self persistentIdentifierForItemAtURL:readURL]) != nil) &&
			    ([self itemForIdentifier:sourceItemIdentifier error:nil] != nil))
			{
				importByCopying = YES;
			}
		}

		if ((parentItem = [self ocItemForIdentifier:parentItemIdentifier vfsNode:NULL error:&error]) != nil)
		{
			// Detect name collissions
			OCItem *existingItem;

			if ((existingItem = [self cachedItemInParent:parentItem withName:importFileName isDirectory:NO error:NULL]) != nil)
			{
				// Return collission error
				FPLogCmd(@"Completed with collission with existingItem=%@ (local)", existingItem);
				completionHandler(nil, [NSError fileProviderErrorForCollisionWithItem:existingItem]);
				return;
			}

			FPLogCmd(@"Importing %@ at %@ readURL %@", importFileName, parentItem, readURL);

			// Import item
			[self.core importItemNamed:importFileName at:parentItem fromURL:readURL isSecurityScoped:YES options:@{
				OCCoreOptionImportByCopying : @(importByCopying)
			} placeholderCompletionHandler:^(NSError *error, OCItem *item) {
				FPLogCmd(@"Completed with placeholderItem=%@, error=%@", item, error);
				item.bookmarkUUID = self.core.bookmark.uuid.UUIDString; // ensure bookmarkUUID is present so that vfsItemID / itemIdentifier succeed
				completionHandler(item, [error translatedError]);
			} resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
				if ([error.domain isEqual:OCHTTPStatusErrorDomain] && (error.code == OCHTTPStatusCodePRECONDITION_FAILED))
				{
					// Collission: file already exists
					if ((parameter != nil) && ([parameter isKindOfClass:[OCItem class]]))
					{
						OCItem *placeholderItem = (OCItem *)parameter;

						// TODO (defunct):
						// Upload errors (such as NSFileProviderErrorInsufficientQuota) should be handled
						// with a subsequent update to the [placeholder] item, setting its uploadingError property.

						// TODO (not yet implemented):
						// Upload errors should not prevent creating or importing a document, because they
						// can be resolved at a later date (for example, when the user has quota again.)

						if (placeholderItem.isPlaceholder)
						{
							FPLogCmd(@"Completed with fileAlreadyExistsAs=%@", placeholderItem);
							[placeholderItem setUploadingError:[NSError fileProviderErrorForCollisionWithItem:placeholderItem]];
						}
					}
				}
			}];
		}
		else
		{
			FPLogCmd(@"Completed with parentItem=%@ not found, error=%@", parentItem, error);
			completionHandler(nil, error);
		}

		if (stopAccess)
		{
			[readURL stopAccessingSecurityScopedResource];
		}
	}];

	FPLogCmd(@"File Coordinator returned with error=%@", error);

	if (error != nil)
	{
		completionHandler(nil, error);
	}

}

- (void)setFavoriteRank:(NSNumber *)favoriteRank forItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable, NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	OCItem *item;

	FPLogCmdBegin(@"FavoriteRank", @"Start of setFavoriteRank=%@, forItemIdentifier=%@", favoriteRank, itemIdentifier);

	if ((item = [self ocItemForIdentifier:itemIdentifier vfsNode:NULL error:&error]) != nil)
	{
//		item.isFavorite = @(favoriteRank != nil); // Stored on server

		[item setLocalFavoriteRank:favoriteRank]; // Stored in local attributes

		FPLogCmd(@"Updating %@", item);

		[self.core updateItem:item properties:@[ OCItemPropertyNameLocalAttributes ] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
			FPLogCmd(@"Completed with item=%@, error=%@", item, error);
			completionHandler(item, [error translatedError]);
		}];
	}
	else
	{
		FPLogCmd(@"Completed with item=%@ not found, error=%@", item, error);
		completionHandler(nil, error);
	}
}

- (void)setTagData:(NSData *)tagData forItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable, NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	OCItem *item;

//	// Example of self-creating tagData
//	tagData = [NSKeyedArchiver archivedDataWithRootObject:@{
//		@"t" : @[
//			@[ @"Root", @(6) ],	// First value is the label, second a color number
//			@[ @"Beer", @(4) ],
//		],
//
//		@"v" : @(1)	// Version (?)
//	}];

	FPLogCmdBegin(@"TagData", @"Start of setTagData=%@, forItemIdentifier=%@", tagData, itemIdentifier);

	if ((item = [self ocItemForIdentifier:itemIdentifier vfsNode:NULL error:&error]) != nil)
	{
		[item setLocalTagData:tagData]; // Stored in local attributes

		FPLogCmd(@"Updating %@", item);

		[self.core updateItem:item properties:@[ OCItemPropertyNameLocalAttributes ] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
			FPLogCmd(@"Completed with item=%@, error=%@", item, error);
			completionHandler(item, [error translatedError]);
		}];
	}
	else
	{
		FPLogCmd(@"Completed with item=%@ not found, error=%@", item, error);
		completionHandler(nil, error);
	}
}

#pragma mark - Incomplete/Compatibility actions
- (void)trashItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable, NSError * _Nullable))completionHandler
{
	NSError *error = nil;
	OCItem *item;

	/*
		This File Provider does not actually support trashing items - and also indicates so via NSFileProviderItem.capabilities.

		Regardless, iOS will call -trashItemWithIdentifier: instead of -deleteItemWithIdentifier: when a user chooses to replace an
		existing file. And - if we return NSFeatureUnsupportedError - will make the replace action unusuable.

		This File Provider therefore implements this method to work around this problem. As soon as iOS uses NSFileProviderItem.capabilities
		and picks the correct action in that case, this implementation can and should be removed.
	*/

	FPLogCmdBegin(@"Trash", @"Start of trashItemWithIdentifier=%@", itemIdentifier);

	if ((item = [self ocItemForIdentifier:itemIdentifier vfsNode:NULL error:&error]) != nil)
	{
		FPLogCmd(@"Deleting %@", item);

		[self.core deleteItem:item requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
			FPLogCmd(@"Completed with error=%@", error);
			completionHandler(nil, [error translatedError]);
		}];
	}
	else
	{
		FPLogCmd(@"Completed with item=%@ not found, error=%@", item, error);
		completionHandler(nil, error);
	}
}

#pragma mark - Unimplemented actions
/*
	"You must override all of the extension's methods (except the deprecated methods), even if your implementation is only an empty method."
	- [Source: https://developer.apple.com/documentation/fileprovider/nsfileproviderextension?language=objc]
*/

- (void)untrashItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier toParentItemIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable, NSError * _Nullable))completionHandler
{
	FPLogCmdBegin(@"Untrash", @"Invocation of unimplemented untrashItemWithIdentifier=%@ toParentItemIdentifier=%@", itemIdentifier, parentItemIdentifier);

	completionHandler(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{}]);
}

- (void)setLastUsedDate:(NSDate *)lastUsedDate forItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable, NSError * _Nullable))completionHandler
{
	FPLogCmdBegin(@"SetLastUsedDate", @"Invocation of unimplemented setLastUsedDate=%@ forItemIdentifier=%@", lastUsedDate, itemIdentifier);

	completionHandler(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{}]);
}

#pragma mark - Enumeration
- (nullable id<NSFileProviderEnumerator>)enumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)containerItemIdentifier error:(NSError **)error
{
	OCLogDebug(@"##### Enumerator request for %@", containerItemIdentifier);

	if (!OCFileProviderSettings.browseable)
	{
		if (error != NULL)
		{
			*error = [NSError errorWithDomain:NSFileProviderErrorDomain code:NSFileProviderErrorNotAuthenticated userInfo:nil];
		}

		OCLogDebug(@"##### Enumerator request for %@: FileProvider disabled: %@", containerItemIdentifier, ((error != NULL) ? *error : nil));

		return (nil);
	}

	if (AppLockSettings.sharedAppLockSettings.lockEnabled)
	{
		NSData *lockedDateData = [[[OCAppIdentity sharedAppIdentity] keychain] readDataFromKeychainItemForAccount:@"app.passcode" path:@"lockedDate"];
		NSData *unlockData = [[[OCAppIdentity sharedAppIdentity] keychain] readDataFromKeychainItemForAccount:@"app.passcode" path:@"unlocked"];

		if ((lockedDateData != nil) && (unlockData != nil))
		{
			NSInteger lockDelay = AppLockSettings.sharedAppLockSettings.lockDelay;
			NSDate *lockDate = [NSKeyedUnarchiver unarchivedObjectOfClass:NSDate.class fromData:lockedDateData error:NULL];
			BOOL unlocked = [[NSKeyedUnarchiver unarchivedObjectOfClass:NSNumber.class fromData:unlockData error:NULL] boolValue];

			if ( !unlocked || (unlocked && [[lockDate dateByAddingTimeInterval:lockDelay] compare:[NSDate date]] == NSOrderedAscending))
			{
				if (error != NULL)
				{
					*error = [NSError errorWithDomain:NSFileProviderErrorDomain code:NSFileProviderErrorNotAuthenticated userInfo:nil];
				}

				OCLogDebug(@"##### Enumerator request for %@: unauthenticated return(1): %@", containerItemIdentifier, ((error != NULL) ? *error : nil));

				return (nil);
			}
		} else if ((unlockData != nil) && ![[NSKeyedUnarchiver unarchivedObjectOfClass:NSNumber.class fromData:unlockData error:NULL] boolValue]) {
			if (error != NULL)
			{
				*error = [NSError errorWithDomain:NSFileProviderErrorDomain code:NSFileProviderErrorNotAuthenticated userInfo:nil];
			}

			OCLogDebug(@"##### Enumerator request for %@: unauthenticated return(2): %@", containerItemIdentifier, ((error != NULL) ? *error : nil));

			return (nil);
		}
	}

	if (self.domain.identifier == nil)
	{
		if (error != NULL)
		{
			*error = [NSError errorWithDomain:NSFileProviderErrorDomain code:NSFileProviderErrorNotAuthenticated userInfo:nil];
		}

		OCLogDebug(@"##### Enumerator request for %@: missing domain ID: %@", containerItemIdentifier, ((error != NULL) ? *error : nil));

		return (nil);
	}

	id<NSFileProviderEnumerator> enumerator = nil;

	if (![containerItemIdentifier isEqualToString:NSFileProviderWorkingSetContainerItemIdentifier])
	{
		if ([containerItemIdentifier isEqual:NSFileProviderRootContainerItemIdentifier])
		{
			// Request core to enable continuous checks for new/changed spaces if app is not running in parallel
			// Also shorten time to core availability when users decide to descend into an actual drive
			OCCore *core = nil;
			NSError *coreError = nil;

			if ((core = [self coreWithError:&coreError]) == nil)
			{
				// Error requesting core
				if (error != NULL)
				{
					*error = coreError;
				}

				OCLogDebug(@"##### Enumerator request for %@: missing core: %@", containerItemIdentifier, ((error != NULL) ? *error : nil));

				return (nil);
			}

			// Change identifier to VFS RootItem ID
			containerItemIdentifier = OCVFSItemIDRoot;
		}

		enumerator = [[FileProviderContentEnumerator alloc] initWithVFSCore:self.vfsCore containerItemIdentifier:containerItemIdentifier];
	}

	OCLogDebug(@"##### Enumerator request for %@: returned %@/%@", containerItemIdentifier, enumerator, ((error != NULL) ? *error : nil));

	return (enumerator);

	// ### Apple template comments: ###

	/*
	FileProviderEnumerator *enumerator = nil;

	if ([containerItemIdentifier isEqualToString:NSFileProviderRootContainerItemIdentifier]) {
		// TODO: instantiate an enumerator for the container root
	} else if ([containerItemIdentifier isEqualToString:NSFileProviderWorkingSetContainerItemIdentifier]) {
		// TODO: instantiate an enumerator for the working set
	} else {
		// TODO: determine if the item is a directory or a file
		// - for a directory, instantiate an enumerator of its subitems
		// - for a file, instantiate an enumerator that observes changes to the file
	}

	return enumerator;
	*/
}

#pragma mark - Thumbnails
- (NSProgress *)fetchThumbnailsForItemIdentifiers:(NSArray<NSFileProviderItemIdentifier> *)itemIdentifiers requestedSize:(CGSize)size perThumbnailCompletionHandler:(void (^)(NSFileProviderItemIdentifier _Nonnull, NSData * _Nullable, NSError * _Nullable))perThumbnailCompletionHandler completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
	FileProviderExtensionThumbnailRequest *thumbnailRequest;

	OCTLogDebug(@[@"FPThumbs"], @"request thumbnails sized %@ for identifiers %@", NSStringFromCGSize(size), OCLogPrivate(itemIdentifiers));

	if ((thumbnailRequest = [FileProviderExtensionThumbnailRequest new]) != nil)
	{
		if (size.width > 256)
		{
			size.width = 256;
		}

		if (size.height > 256)
		{
			size.height = 256;
		}

		thumbnailRequest.extension = self;
		thumbnailRequest.itemIdentifiers = itemIdentifiers;
		thumbnailRequest.sizeInPixels = size;
		thumbnailRequest.perThumbnailCompletionHandler = perThumbnailCompletionHandler;
		thumbnailRequest.completionHandler = completionHandler;
		thumbnailRequest.progress = [NSProgress progressWithTotalUnitCount:itemIdentifiers.count];

		[thumbnailRequest requestNextThumbnail];

		return (thumbnailRequest.progress);
	}

	return (NSProgress.indeterminateProgress);
}

#pragma mark - Services
- (NSArray<id<NSFileProviderServiceSource>> *)supportedServiceSourcesForItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier error:(NSError * _Nullable __autoreleasing *)error
{
	BOOL isSpecialItem = [itemIdentifier isEqual:self.bookmark.fpServicesURLComponentName];

	OCTLogDebug(@[@"FPServices"], @"request for supported services sources for item identifier %@ (isSpecialItem: %d, core: %@)", OCLogPrivate(itemIdentifier), isSpecialItem, self.core);

	if (isSpecialItem)
	{
		return (@[
			[[FileProviderServiceSource alloc] initWithServiceName:OCFileProviderServiceName extension:self]
		]);
	}

	return (nil);
}

#pragma mark - Core
- (OCBookmark *)bookmark
{
	OCBookmark *bookmark = nil;

	@synchronized(self)
	{
		bookmark = _bookmark;
	}

	if (bookmark == nil)
	{
		NSFileProviderDomainIdentifier domainIdentifier;

		if ((domainIdentifier = self.domain.identifier) != nil)
		{
			NSUUID *bookmarkUUID = [[NSUUID alloc] initWithUUIDString:domainIdentifier];

			bookmark = [[OCBookmarkManager sharedBookmarkManager] bookmarkForUUID:bookmarkUUID];

			if (bookmark == nil)
			{
				OCLogDebug(@"Error retrieving bookmark for domain %@ (UUID %@) - reloading", OCLogPrivate(self.domain.displayName), OCLogPrivate(self.domain.identifier));

				[[OCBookmarkManager sharedBookmarkManager] loadBookmarks];

				bookmark = [[OCBookmarkManager sharedBookmarkManager] bookmarkForUUID:bookmarkUUID];

				if (bookmark == nil)
				{
					OCLogError(@"Error retrieving bookmark for domain %@ (UUID %@) - final", OCLogPrivate(self.domain.displayName), OCLogPrivate(self.domain.identifier));
				}
			}

			@synchronized(self)
			{
				if ((_bookmark == nil) && (bookmark != nil))
				{
					_bookmark = bookmark;
				}
			}
		}
	}

	return (bookmark);
}

- (OCCore *)core
{
	return ([self coreWithError:nil]);
}

- (OCCore *)coreWithError:(NSError **)outError
{
	OCLogVerbose(@"FileProviderExtension[%p].core[enter]: _core=%p, bookmark=%@", self, _core, self.bookmark);

	OCBookmark *bookmark = self.bookmark;
	__block OCCore *retCore = nil;
	__block NSError *retError = nil;

	@synchronized(self)
	{
		retCore = _core;
	}

	if (retCore == nil)
	{
		if (bookmark != nil)
		{
			OCLogDebug(@"Requesting OCCore for FileProvider %@", self);

			OCSyncExec(waitForCore, {
			 	__block BOOL hasCore = NO;

				[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark setup:^(OCCore *core, NSError *error) {
					@synchronized(self)
					{
						hasCore = (self->_core != nil);

						if (!hasCore)
						{
							self->_core = core;
							core.delegate = self;
							retCore = core;
						}
						else
						{
							retCore = self->_core;
						}
					}

					if (error != nil)
					{
						retError = error;
					}
				} completionHandler:^(OCCore *core, NSError *error) {
					if (!hasCore)
					{
						self->_core = core;

						if ((self->_messagePresenter = [[NotificationMessagePresenter alloc] initForBookmarkUUID:core.bookmark.uuid]) != nil)
						{
							[core.messageQueue addPresenter:self->_messagePresenter];
						}
					}
					else
					{
						retCore = self->_core;
					}

					if (error != nil)
					{
						retError = error;
						retCore = nil;
					}

					OCSyncExecDone(waitForCore);

					if (hasCore)
					{
						// Balance out unrequired request for core
						[OCCoreManager.sharedCoreManager returnCoreForBookmark:bookmark completionHandler:nil];
					}
				}];
			});
		}
	}

	if (retCore == nil)
	{
		OCLogError(@"Error getting core for domain %@ (UUID %@): %@", OCLogPrivate(self.domain.displayName), OCLogPrivate(self.domain.identifier), OCLogPrivate(retError));
	}

	if (outError != NULL)
	{
		*outError = retError;
	}

	OCLogVerbose(@"FileProviderExtension[%p].core[leave]: _core=%p, bookmark=%@", self, retCore, bookmark);

	return (retCore);

}

- (void)core:(OCCore *)core handleError:(NSError *)error issue:(OCIssue *)issue
{
	OCLogDebug(@"CORE ERROR: error=%@, issue=%@", error, issue);

	if ((issue != nil) && (error == nil))
	{
		// Turn issues that are just converted authorization errors back into errors and discard the issue
		if ([issue.error isOCErrorWithCode:OCErrorAuthorizationFailed] ||
		    [issue.error isOCErrorWithCode:OCErrorAuthorizationNoMethodData] ||
		    [issue.error isOCErrorWithCode:OCErrorAuthorizationMethodNotAllowed] ||
		    [issue.error isOCErrorWithCode:OCErrorAuthorizationMethodUnknown] ||
		    [issue.error isOCErrorWithCode:OCErrorAuthorizationMissingData])
		{
			error = issue.error;
			issue = nil;
		}
	}

	if ([error isOCErrorWithCode:OCErrorAuthorizationFailed])
	{
		// Make sure only the first auth failure will actually lead to an alert
		// (otherwise alerts could keep getting enqueued while the first alert is being shown,
		// and then be presented even though they're no longer relevant). It's ok to only show
		// an alert for the first auth failure, because the options are "Continue offline" (=> no longer show them)
		// and "Edit" (=> log out, go to bookmark editing)
		BOOL doSkip = NO;

		@synchronized(self)
		{
			doSkip = _skipAuthorizationFailure;  // Keep in mind OCSynchronized() contents is running as a block, so "return" in here wouldn't have the desired effect
			_skipAuthorizationFailure = YES;
		}

		if (doSkip)
		{
			OCLogDebug(@"Skip authorization failure: %@", error);
			return;
		}

		[NotificationManager.sharedNotificationManager requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError * _Nullable reqError) {
			if (granted)
			{
				UNMutableNotificationContent *content = [UNMutableNotificationContent new];

				OCBookmark *bookmark;

				content.title = OCLocalizedString(@"Authorization failed", nil);

				if ((OCBookmarkManager.sharedBookmarkManager.bookmarks.count > 1) &&
				    (((bookmark = core.bookmark) != nil) &&
				     (bookmark.shortName != nil))
				   )
				{
					content.body = [NSString stringWithFormat:OCLocalizedString(@"Log into your account %@ in the app for more details.", nil), bookmark.shortName];
				}
				else
				{
					content.body = OCLocalizedString(@"Log into your account in the app for more details.", nil);
				}

				UNNotificationRequest *request;

				request = [UNNotificationRequest requestWithIdentifier:ComposeNotificationIdentifier(NotificationAuthErrorForwarder, bookmark.uuid.UUIDString) content:content trigger:nil];

				[NotificationManager.sharedNotificationManager addNotificationRequest:request withCompletionHandler:^(NSError * _Nonnull error) {
					OCLogDebug(@"Add Notification error: %@", error);
				}];
			}
		}];
	}

	if (issue.type == OCIssueTypeMultipleChoice)
	{
		[issue cancel];
	}
}

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierFileProvider);
}

+ (NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
			OCClassSettingsKeyFileProviderSkipLocalErrorChecks : @(NO)
		});
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	return (@{
		OCClassSettingsKeyFileProviderSkipLocalErrorChecks : @{
			OCClassSettingsMetadataKeyType 		: OCClassSettingsMetadataTypeBoolean,
			OCClassSettingsMetadataKeyDescription 	: @"Skip some local error checks in the FileProvider to easily provoke errors.",
			OCClassSettingsMetadataKeyCategory	: @"File Provider",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusDebugOnly
		}
	});
}

- (BOOL)skipLocalErrorChecks
{
	return (((NSNumber *)[self classSettingForOCClassSettingsKey:OCClassSettingsKeyFileProviderSkipLocalErrorChecks]).boolValue);
}

#pragma mark - Log tagging
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"FP"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"FP"]);
}

@end

OCClaimExplicitIdentifier OCClaimExplicitIdentifierFileProvider = @"fileProvider";
OCClassSettingsKey OCClassSettingsKeyFileProviderSkipLocalErrorChecks = @"skip-local-error-checks";

/*
	Additional information:
	- NSExtensionFileProviderSupportsPickingFolders: https://twitter.com/palmin/status/1177860144258076673
*/
