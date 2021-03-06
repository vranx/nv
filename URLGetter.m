#import "URLGetter.h"

@implementation URLGetter

- (id)initWithURL:(NSURL*)aUrl delegate:(id)aDelegate userData:(id)someObj {
	if (!aUrl || [aUrl isFileURL]) {
		return nil;
	}
	if ([super init]) {
		maxExpectedByteCount = 0;
		isIndicating = NO;
		delegate = aDelegate;
		url = [aUrl retain];
		userData = [someObj retain];
		
		downloader = [[NSURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
		
		[self startProgressIndication:self];
	}
	
	return self;
}

- (void)dealloc {
	[downloader release];
	[downloadPath release];
	[url release];
	[userData release];
	
	[super dealloc];
}

- (NSURL*)url {
	return url;
}

- (id)userData {
	return userData;
}

- (IBAction)cancelDownload:(id)sender {
	[downloader cancel];

	[self endDownloadWithPath:nil];
}

- (void)stopProgressIndication {
	[window close];
	[progress stopAnimation:nil];
	
	isIndicating = NO;
}

- (void)startProgressIndication:(id)sender {
	if (!window) {
		if (![NSBundle loadNibNamed:@"URLGetter" owner:self])  {
			NSLog(@"Failed to load URLGetter.nib");
			NSBeep();
			return;
		}
	}
	
	[progress setIndeterminate:YES];
	[progress startAnimation:nil];
	
	[cancelButton setEnabled:YES];
	[progressStatus setStringValue:NSLocalizedString(@"Download: waiting to begin.", @"download dialog status message")];
	[objectURLStatus setStringValue:[url absoluteString]];
	
	[window center];
	[window makeKeyAndOrderFront:sender];
	
	isIndicating = YES;
}

- (void)updateProgress {
	if (isIndicating) {
		[progress setIndeterminate:!maxExpectedByteCount];
		[progress setMaxValue:(double)maxExpectedByteCount];
		
		[progress setDoubleValue:(double)totalReceivedByteCount];
		if (maxExpectedByteCount > 0) {
			[progressStatus setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%.0lf KB of %.0lf KB", nil), 
				(double)totalReceivedByteCount / 1024.0, (double)maxExpectedByteCount / 1024.0]];
		} else {
			[progressStatus setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%.0lf KB received",nil), (double)totalReceivedByteCount / 1024.0]];
		}
	}
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response {
	maxExpectedByteCount = [response expectedContentLength];
	//NSLog(@"max KB: %lld", maxExpectedByteCount/1024);
	
	[self updateProgress];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length {
	totalReceivedByteCount += length;
	
	[self updateProgress];
}

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)name {
	
	[tempDirectory autorelease];
	tempDirectory = [[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] retain];
	if (![[NSFileManager defaultManager] createDirectoryAtPath:tempDirectory attributes:nil]) {
		NSLog(@"URLGetter: Couldn't create temporary directory!");
		[download cancel];
		NSBeep();
	}
	
	[downloadPath autorelease];
	downloadPath = [[tempDirectory stringByAppendingPathComponent:name] retain];
	[download setDestination:downloadPath allowOverwrite:YES];
	
	//need to delete this stuff eventually
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
	
	NSString *reason = [error localizedDescription];
	if (!reason) reason = NSLocalizedString(@"unknown error.", @"error description of last resort for why a URL couldn't be accessed");
	NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"The URL quotemark%@quotemark could not be accessed: %@.", nil), 
		[url absoluteString], reason], @"", NSLocalizedString(@"OK",nil), nil, nil);
	
	
	[self endDownloadWithPath:nil];
}

- (void)downloadDidFinish:(NSURLDownload *)download {
	
	[self endDownloadWithPath:downloadPath];
}

- (void)endDownloadWithPath:(NSString*)path {
	[self stopProgressIndication];
	
	[self retain];
	[delegate URLGetter:self returnedDownloadedFile:path];
	
	//clean up after ourselves
	NSFileManager *fileMan = [NSFileManager defaultManager];
	if (downloadPath) {
		[fileMan removeFileAtPath:downloadPath handler:NULL];
		[downloadPath release];
		downloadPath = nil;
	}
	
	if (tempDirectory) {
		//only remove temporary directory if there's nothing in it
		if (![[fileMan directoryContentsAtPath:tempDirectory] count])
			[fileMan removeFileAtPath:tempDirectory handler:NULL];
		else
			NSLog(@"note removing %@ because it still contains files!", tempDirectory);
		[tempDirectory release];
		tempDirectory = nil;
	}
	
	[self release];
}

- (NSString*)downloadPath {
	return downloadPath;
}

- (id)delegate {
	return delegate;
}
- (void)setDelegate:(id)aDelegate {
	delegate = aDelegate;
}

@end
