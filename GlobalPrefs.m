//
//  GlobalPrefs.m
//  Notation
//
//  Created by Zachary Schneirov on 1/31/06.
//  Copyright 2006 Zachary Schneirov. All rights reserved.
//

#import "GlobalPrefs.h"
#import "NSData_transformations.h"
#import "NotationPrefs.h"
#import "BookmarksController.h"
#import "AttributedPlainText.h"
#import "PTHotKey.h"
#import "PTKeyCombo.h"
#import "PTHotKeyCenter.h"
#import "NSString_NV.h"

#define SEND_CALLBACKS() sendCallbacksForGlobalPrefs(self, _cmd, sender)

static NSString *TriedToImportBlorKey = @"TriedToImportBlor";
static NSString *DirectoryAliasKey = @"DirectoryAlias";
static NSString *AutoCompleteSearchesKey = @"AutoCompleteSearches";
static NSString *TableColumnsVisibleKey = @"TableColumnsVisible";
static NSString *TableFontSizeKey = @"TableFontPointSize";
static NSString *TableSortColumnKey = @"TableSortColumn";
static NSString *TableIsReverseSortedKey = @"TableIsReverseSorted";
static NSString *NoteBodyFontKey = @"NoteBodyFont";
static NSString *ConfirmNoteDeletionKey = @"ConfirmNoteDeletion";
static NSString *CheckSpellingInNoteBodyKey = @"CheckSpellingInNoteBody";
static NSString *QuitWhenClosingMainWindowKey = @"QuitWhenClosingMainWindow";
static NSString *TabKeyIndentsKey = @"TabKeyIndents";
static NSString *PastePreservesStyleKey = @"PastePreservesStyle";
static NSString *AutoSuggestLinksKey = @"AutoSuggestLinks";
static NSString *SearchTermHighlightColorKey = @"SearchTermHighlightColor";
static NSString *UseSoftTabsKey = @"UseSoftTabs";
static NSString *NumberOfSpacesInTabKey = @"NumberOfSpacesInTab";
static NSString *DrawFocusRingKey = @"DrawFocusRing";
static NSString *MakeURLsClickableKey = @"MakeURLsClickable";
static NSString *AppActivationKeyCodeKey = @"AppActivationKeyCode";
static NSString *AppActivationModifiersKey = @"AppActivationModifiers";
static NSString *BookmarksKey = @"Bookmarks";
static NSString *LastSearchStringKey = @"LastSearchString";
static NSString *LastSelectedNoteUUIDBytesKey = @"LastSelectedNoteUUIDBytes";
static NSString *LastSelectedPreferencesPaneKey = @"LastSelectedPreferencesPane";
//static NSString *PasteClipboardOnNewNoteKey = @"PasteClipboardOnNewNote";

//these 4 strings manually localized
NSString *NoteTitleColumnString = @"Title";
NSString *NoteLabelsColumnString = @"Tags";
NSString *NoteDateModifiedColumnString = @"Date Modified";
NSString *NoteDateCreatedColumnString = @"Date Added";

NSString *NVPTFPboardType = @"Notational Velocity Poor Text Format";

NSString *HotKeyAppToFrontName = @"bring Notational Velocity to the foreground";

@implementation GlobalPrefs

static void sendCallbacksForGlobalPrefs(GlobalPrefs* self, SEL selector, id originalSender) {
	
	if (originalSender != self)
		self->runCallbacksIMP(self, @selector(notifyCallbacksForSelector:excludingSender:), 
							 selector, originalSender);
}

- (id)init {
	if ([super init]) {
	
		runCallbacksIMP = [self methodForSelector:@selector(notifyCallbacksForSelector:excludingSender:)];
		selectorObservers = [[NSMutableDictionary alloc] init];
		
		defaults = [NSUserDefaults standardUserDefaults];
		
		tableColumns = nil;
		
		[defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO], AutoSuggestLinksKey,
			[NSNumber numberWithBool:NO], UseSoftTabsKey,
			[NSNumber numberWithInt:4], NumberOfSpacesInTabKey,
			[NSNumber numberWithBool:NO], PastePreservesStyleKey,
			[NSNumber numberWithBool:NO], TabKeyIndentsKey,
			[NSNumber numberWithBool:YES], ConfirmNoteDeletionKey,
			[NSNumber numberWithBool:YES], CheckSpellingInNoteBodyKey, 
		    [NSNumber numberWithBool:YES], AutoCompleteSearchesKey, 
			[NSNumber numberWithBool:YES], QuitWhenClosingMainWindowKey, 
			[NSNumber numberWithBool:NO], TriedToImportBlorKey,
			[NSNumber numberWithBool:NO], DrawFocusRingKey,
			[NSNumber numberWithBool:YES], MakeURLsClickableKey,
			
			@"General", LastSelectedPreferencesPaneKey, 
			
			[NSArchiver archivedDataWithRootObject:
				[NSFont fontWithName:@"Helvetica" size:12.0f]], NoteBodyFontKey,
			
			//[NSArchiver archivedDataWithRootObject:
			//	[NSColor colorWithCalibratedRed:0.9340 green:0.91415775 blue:0.81043575 alpha:1.0f]], SearchTermHighlightColorKey,
			[NSArchiver archivedDataWithRootObject:
				[NSColor colorWithCalibratedRed:0.945 green:0.702 blue:0.702 alpha:1.0f]], SearchTermHighlightColorKey,
			
		    [NSNumber numberWithFloat:[NSFont smallSystemFontSize]], TableFontSizeKey, 
		    [NSArray arrayWithObjects:NoteTitleColumnString, NoteDateCreatedColumnString, nil], TableColumnsVisibleKey,
		    NoteDateCreatedColumnString, TableSortColumnKey,
		    [NSNumber numberWithBool:YES], TableIsReverseSortedKey, nil]];
		
		autoCompleteSearches = [defaults boolForKey:AutoCompleteSearchesKey];
	}
	return self;
}

+ (GlobalPrefs *)defaultPrefs {
	static GlobalPrefs *prefs = nil;
	if (!prefs)
		prefs = [[GlobalPrefs alloc] init];
	return prefs;
}

- (void)dealloc {
	
	[tableColumns release];
	[super dealloc];
}

- (void)registerForSettingChange:(SEL)selector withTarget:(id)sender {
	if ([sender respondsToSelector:(@selector(settingChangedForSelectorString:))]) {
		
		NSString *selectorKey = NSStringFromSelector(selector);
		
		NSMutableArray *senders = [selectorObservers objectForKey:selectorKey];
		if (!senders) {
			senders = [[NSMutableArray alloc] initWithCapacity:1];
			[selectorObservers setObject:senders forKey:selectorKey];
		}
		
		[senders addObject:sender];
		
	} else {
		NSLog(@"target %@ does not respond to callback selector!", [sender description]);
	}
}

- (void)unregisterForNotificationsFromSelector:(SEL)selector sender:(id)sender {
	NSString *selectorKey = NSStringFromSelector(selector);
	
	NSMutableArray *senders = [selectorObservers objectForKey:selectorKey];
	if (senders) {
		[senders removeObjectIdenticalTo:sender];
		
		if (![senders count])
			[selectorObservers removeObjectForKey:selectorKey];
	} else {
		NSLog(@"Selector %@ has no observers?", NSStringFromSelector(selector));
	}
}

- (void)notifyCallbacksForSelector:(SEL)selector excludingSender:(id)sender {
	NSArray *observers = nil;
	id observer = nil;
	
	NSString *selectorKey = NSStringFromSelector(selector);
	
	if ((observers = [selectorObservers objectForKey:selectorKey])) {
		unsigned int i;
		
		for (i=0; i<[observers count]; i++) {
			
			if ((observer = [observers objectAtIndex:i]) != sender && observer)
				[observer performSelector:@selector(settingChangedForSelectorString:) withObject:selectorKey];
		}
	}
}

- (void)setNotationPrefs:(NotationPrefs*)newNotationPrefs sender:(id)sender {
	[notationPrefs autorelease];
	notationPrefs = [newNotationPrefs retain];
	
	[self resolveNoteBodyFontFromNotationPrefsFromSender:sender];
	
	SEND_CALLBACKS();
}

- (NotationPrefs*)notationPrefs {
	return notationPrefs;
}

- (BOOL)autoCompleteSearches {
	return autoCompleteSearches;
}

- (void)setAutoCompleteSearches:(BOOL)value sender:(id)sender {
	autoCompleteSearches = value;
	[defaults setBool:value forKey:AutoCompleteSearchesKey];
	
	SEND_CALLBACKS();
}

- (void)setTabIndenting:(BOOL)value sender:(id)sender {
    [defaults setBool:value forKey:TabKeyIndentsKey];
    
    SEND_CALLBACKS();
}
- (BOOL)tabKeyIndents {
    return [defaults boolForKey:TabKeyIndentsKey];
}

- (void)setCheckSpellingAsYouType:(BOOL)value sender:(id)sender {
    [defaults setBool:value forKey:CheckSpellingInNoteBodyKey];
    
    SEND_CALLBACKS();
}

- (BOOL)checkSpellingAsYouType {
    return [defaults boolForKey:CheckSpellingInNoteBodyKey];
}

- (void)setConfirmNoteDeletion:(BOOL)value sender:(id)sender {
    [defaults setBool:value forKey:ConfirmNoteDeletionKey];
    
    SEND_CALLBACKS();
}
- (BOOL)confirmNoteDeletion {
    return [defaults boolForKey:ConfirmNoteDeletionKey];
}

- (void)setQuitWhenClosingWindow:(BOOL)value sender:(id)sender {
    [defaults setBool:value forKey:QuitWhenClosingMainWindowKey];
    
    SEND_CALLBACKS();
}
- (BOOL)quitWhenClosingWindow {
    return [defaults boolForKey:QuitWhenClosingMainWindowKey];
}

- (void)setAppActivationKeyCombo:(PTKeyCombo*)aCombo sender:(id)sender {
	if (aCombo) {
		[appActivationKeyCombo release];
		appActivationKeyCombo = [aCombo retain];
		
		[[self appActivationHotKey] setKeyCombo:appActivationKeyCombo];
	
		[defaults setInteger:[aCombo keyCode] forKey:AppActivationKeyCodeKey];
		[defaults setInteger:[aCombo modifiers] forKey:AppActivationModifiersKey];
		
		SEND_CALLBACKS();
	}
}

- (PTHotKey*)appActivationHotKey {
	if (!appActivationHotKey) {
		appActivationHotKey = [[PTHotKey alloc] init];
		[appActivationHotKey setName:HotKeyAppToFrontName];
		[appActivationHotKey setKeyCombo:[self appActivationKeyCombo]];
	}
	
	return appActivationHotKey;
}

- (PTKeyCombo*)appActivationKeyCombo {
	if (!appActivationKeyCombo) {
		appActivationKeyCombo = [[PTKeyCombo alloc] initWithKeyCode:[[defaults objectForKey:AppActivationKeyCodeKey] intValue]
														  modifiers:[[defaults objectForKey:AppActivationModifiersKey] intValue]];
	}
	return appActivationKeyCombo;
}

- (BOOL)registerAppActivationKeystrokeWithTarget:(id)target selector:(SEL)selector {
	PTHotKey *hotKey = [self appActivationHotKey];
	
	[hotKey setTarget:target];
	[hotKey setAction:selector];
	
	[[PTHotKeyCenter sharedCenter] unregisterHotKeyForName:HotKeyAppToFrontName];
	
	return [[PTHotKeyCenter sharedCenter] registerHotKey:hotKey];
}

- (void)setPastePreservesStyle:(BOOL)value sender:(id)sender {
    [defaults setBool:value forKey:PastePreservesStyleKey];
    
	SEND_CALLBACKS();
}

- (BOOL)pastePreservesStyle {
    
    return [defaults boolForKey:PastePreservesStyleKey];
}

- (void)setLinksAutoSuggested:(BOOL)value sender:(id)sender {
    [defaults setBool:value forKey:AutoSuggestLinksKey];
	
	SEND_CALLBACKS();
}
- (BOOL)linksAutoSuggested {
    return [defaults boolForKey:AutoSuggestLinksKey];
}

- (void)setMakeURLsClickable:(BOOL)value sender:(id)sender {
	[defaults setBool:value forKey:MakeURLsClickableKey];
	
	SEND_CALLBACKS();
}
- (BOOL)URLsAreClickable {
	return [defaults boolForKey:MakeURLsClickableKey];
}

- (void)setSearchTermHighlightColor:(NSColor*)color sender:(id)sender {
	if (color) {
		[searchTermHighlightColor autorelease];
		searchTermHighlightColor = [color retain];
		
		[searchTermHighlightAttributes release];
		searchTermHighlightAttributes = nil;
		
		[defaults setObject:[NSArchiver archivedDataWithRootObject:color] 
					 forKey:SearchTermHighlightColorKey];
		
		SEND_CALLBACKS();
	}
}

- (NSColor*)searchTermHighlightColor {
	
	if (!searchTermHighlightColor) {
		NSData *theData = [defaults dataForKey:SearchTermHighlightColorKey];
		if (theData)
			searchTermHighlightColor = (NSColor *)[[NSUnarchiver unarchiveObjectWithData:theData] retain];
	}
	
	return searchTermHighlightColor;
}

- (NSDictionary*)searchTermHighlightAttributes {
	NSColor *highlightColor = [self searchTermHighlightColor];
	
	if (!searchTermHighlightAttributes && highlightColor) {
		searchTermHighlightAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:highlightColor, NSBackgroundColorAttributeName, nil] retain];
	}
	return searchTermHighlightAttributes;
	
}

- (void)setSoftTabs:(BOOL)value sender:(id)sender {
	[defaults setBool:value forKey:UseSoftTabsKey];
	
	SEND_CALLBACKS();
}

- (BOOL)softTabs {
	return [defaults boolForKey:UseSoftTabsKey];
}

- (int)numberOfSpacesInTab {
	return [defaults integerForKey:NumberOfSpacesInTabKey];
}

- (BOOL)drawFocusRing {
	return [defaults boolForKey:DrawFocusRingKey];
}

- (void)resolveNoteBodyFontFromNotationPrefsFromSender:(id)sender {
	
	NSFont *prefsFont = [notationPrefs baseBodyFont];
	if (prefsFont) {
		NSFont *noteFont = [self noteBodyFont];
		
		if (![[prefsFont fontName] isEqualToString:[noteFont fontName]] || 
			[prefsFont pointSize] != [noteFont pointSize]) {
			
			NSLog(@"archived notationPrefs base font does not match current global default font!");
			[self _setNoteBodyFont:prefsFont];
			
			SEND_CALLBACKS();
		}
	}
}

- (void)_setNoteBodyFont:(NSFont*)aFont {
	NSFont *oldFont = noteBodyFont;
	noteBodyFont = [aFont retain];
	
	[noteBodyParagraphStyle release];
	noteBodyParagraphStyle = nil;
	
	[noteBodyAttributes release];
	noteBodyAttributes = nil; //cause method to re-update
	
	[defaults setObject:[NSArchiver archivedDataWithRootObject:noteBodyFont] forKey:NoteBodyFontKey]; 
	
	//restyle any PTF data on the clipboard to the new font
	NSData *ptfData = [[NSPasteboard generalPasteboard] dataForType:NVPTFPboardType];
	NSMutableAttributedString *newString = [[[NSMutableAttributedString alloc] initWithRTF:ptfData documentAttributes:nil] autorelease];
	
	[newString restyleTextToFont:noteBodyFont usingBaseFont:oldFont];
	
	ptfData = [newString RTFFromRange:NSMakeRange(0, [newString length]) documentAttributes:nil];
	[[NSPasteboard generalPasteboard] setData:ptfData forType:NVPTFPboardType];
	[oldFont release];
}

- (void)setNoteBodyFont:(NSFont*)aFont sender:(id)sender {
	
	if (aFont) {
		[self _setNoteBodyFont:aFont];
		
		SEND_CALLBACKS();
	}
}

- (NSFont*)noteBodyFont {
	BOOL triedOnce = NO;
	
	if (!noteBodyFont) {
		retry:
		@try {
			noteBodyFont = [[NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:NoteBodyFontKey]] retain];
		} @catch (NSException *e) {
			NSLog(@"Error trying to unarchive default note body font (%@, %@)", [e name], [e reason]);
		}
		
		if ((!noteBodyFont || ![noteBodyFont isKindOfClass:[NSFont class]]) && !triedOnce) {
			triedOnce = YES;
			[defaults removeObjectForKey:NoteBodyFontKey];
			goto retry;
		}
	}
	
    return noteBodyFont;
}

- (NSDictionary*)noteBodyAttributes {
	NSFont *bodyFont = [self noteBodyFont];
	
	if (!noteBodyAttributes && bodyFont) {
		BOOL monospace = [self _bodyFontIsMonospace];
		
		noteBodyAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:bodyFont, NSFontAttributeName, 
			[NSNumber numberWithInt:0], NSLigatureAttributeName,
		monospace ? [self noteBodyParagraphStyle] : nil, NSParagraphStyleAttributeName,
			/*[NSColor blackColor], NSForegroundColorAttributeName,
			[NSColor whiteColor], NSBackgroundColorAttributeName,*/ nil] retain];
	}
	return noteBodyAttributes;
}

- (BOOL)_bodyFontIsMonospace {
	NSString *name = [noteBodyFont fontName];
	return (([noteBodyFont isFixedPitch] || [name caseInsensitiveCompare:@"Osaka-Mono"] == NSOrderedSame) && 
			[name caseInsensitiveCompare:@"MS-PGothic"] != NSOrderedSame);
}

- (NSParagraphStyle*)noteBodyParagraphStyle {
	NSFont *bodyFont = [self noteBodyFont];

	if (!noteBodyParagraphStyle && bodyFont) {
		NSMutableString *sizeString = [[NSMutableString alloc] init];
		int numberOfSpaces = [self numberOfSpacesInTab];
		while (numberOfSpaces--) {
			[sizeString appendString:@" "];
		}
		NSDictionary *sizeAttribute = [[NSDictionary alloc] initWithObjectsAndKeys:bodyFont, NSFontAttributeName, nil];
		float sizeOfTab = [sizeString sizeWithAttributes:sizeAttribute].width;
		[sizeAttribute release];
		[sizeString release];
		
		noteBodyParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		
		NSTextTab *textTabToBeRemoved;
		NSEnumerator *enumerator = [[noteBodyParagraphStyle tabStops] objectEnumerator];
		while ((textTabToBeRemoved = [enumerator nextObject])) {
			[noteBodyParagraphStyle removeTabStop:textTabToBeRemoved];
		}
		[noteBodyParagraphStyle setDefaultTabInterval:sizeOfTab];
	}
	
	return noteBodyParagraphStyle;
}

- (float)tableFontSize {
	return [defaults floatForKey:TableFontSizeKey];
}

- (void)setTableFontSize:(float)fontSize sender:(id)sender {
	[defaults setFloat:fontSize forKey:TableFontSizeKey];
	
	SEND_CALLBACKS();
}

- (void)removeTableColumn:(NSString*)columnKey sender:(id)sender {
	[tableColumns removeObject:columnKey];
	[defaults setObject:tableColumns forKey:TableColumnsVisibleKey];
	
	SEND_CALLBACKS();
}
- (void)addTableColumn:(NSString*)columnKey sender:(id)sender {
	if (![tableColumns containsObject:columnKey]) {
		[tableColumns addObject:columnKey];
		[defaults setObject:tableColumns forKey:TableColumnsVisibleKey];
		
		SEND_CALLBACKS();
	}
}

- (NSArray*)visibleTableColumns {
	if (!tableColumns)
		tableColumns = [[NSMutableArray arrayWithArray:[defaults arrayForKey:TableColumnsVisibleKey]] retain];
	
	if (![tableColumns count])
		[self addTableColumn:NoteTitleColumnString sender:self];
		
	return tableColumns;
}

- (void)setSortedTableColumnKey:(NSString*)sortedKey reversed:(BOOL)reversed sender:(id)sender {
	[defaults setBool:reversed forKey:TableIsReverseSortedKey];
    [defaults setObject:sortedKey forKey:TableSortColumnKey];
    
    SEND_CALLBACKS();
}

- (NSString*)sortedTableColumnKey {
    return [defaults objectForKey:TableSortColumnKey];
}

- (BOOL)tableIsReverseSorted {
    return [defaults boolForKey:TableIsReverseSortedKey];
}

- (NSString*)lastSelectedPreferencesPane {
	return [defaults stringForKey:LastSelectedPreferencesPaneKey];
}
- (void)setLastSelectedPreferencesPane:(NSString*)pane sender:(id)sender {
	[defaults setObject:pane forKey:LastSelectedPreferencesPaneKey];
	
	SEND_CALLBACKS();
}

- (void)setLastSearchString:(NSString*)string selectedNote:(id<SynchronizedNote>)aNote sender:(id)sender {
	[defaults setObject:string forKey:LastSearchStringKey];
	
	CFUUIDBytes *bytes = [aNote uniqueNoteIDBytes];
	NSString *uuidString = nil;
	if (bytes) uuidString = [NSString uuidStringWithBytes:*bytes];

	[defaults setObject:uuidString forKey:LastSelectedNoteUUIDBytesKey];
	
	SEND_CALLBACKS();
}

- (NSString*)lastSearchString {
	return [defaults objectForKey:LastSearchStringKey];
}

- (CFUUIDBytes)UUIDBytesOfLastSelectedNote {
	CFUUIDBytes bytes = {0};
	
	NSString *uuidString = [defaults objectForKey:LastSelectedNoteUUIDBytesKey];
	if (uuidString) bytes = [uuidString uuidBytes];

	return bytes;
}

- (void)setBookmarksFromSender:(id)sender {
	//run this during quit and when saved searches change?
	NSArray *bookmarks = [bookmarksController dictionaryReps];
	if (bookmarks) [defaults setObject:bookmarks forKey:BookmarksKey];
		
	SEND_CALLBACKS();
}

- (BookmarksController*)bookmarksController {
	if (!bookmarksController) {
		bookmarksController = [[BookmarksController alloc] initWithBookmarks:[defaults arrayForKey:BookmarksKey]];
	}
	return bookmarksController;
}

- (void)setAliasDataForDefaultDirectory:(NSData*)alias sender:(id)sender {
    [defaults setObject:alias forKey:DirectoryAliasKey];
	
    SEND_CALLBACKS();
}

- (NSData*)aliasDataForDefaultDirectory {
    return [defaults dataForKey:DirectoryAliasKey];
}

- (NSImage*)iconForDefaultDirectoryWithFSRef:(FSRef*)fsRef {
    OSStatus err = noErr;
    
    if (!fsRef)
	return nil;
    
    if (IsZeros(fsRef, sizeof(FSRef))) {
	if (![[self aliasDataForDefaultDirectory] fsRefAsAlias:fsRef])
	    return nil;
    }
    IconRef iconRef;
    if ((err = GetIconRefFromFileInfo(fsRef, 0, NULL, 0, NULL, kIconServicesNormalUsageFlag, &iconRef, NULL)) == noErr) {
	
	NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(16.0f, 16.0f)] autorelease];
	NSRect frame = NSMakeRect(0.0f,0.0f,16.0f,16.0f);
	
	[image lockFocus];
	err = PlotIconRefInContext([[NSGraphicsContext currentContext] graphicsPort], (CGRect *)&frame, 0, 0, nil, 0, iconRef);
	[image unlockFocus];
	
	if (err == noErr)
	    return image;
    }
    
    NSLog(@"iconForDefaultDirectory error: %d", err);
    
    return nil;
}

- (NSString*)displayNameForDefaultDirectoryWithFSRef:(FSRef*)fsRef {

    if (!fsRef)
	return nil;
    
    if (IsZeros(fsRef, sizeof(FSRef))) {
	if (![[self aliasDataForDefaultDirectory] fsRefAsAlias:fsRef])
	    return nil;
    }
    CFStringRef displayName = NULL;
    if (LSCopyDisplayNameForRef(fsRef, &displayName) == noErr) {
	return [(NSString*)displayName autorelease];
    }
    return nil;
}

- (NSString*)humanViewablePathForDefaultDirectory {
    //resolve alias to fsref
    FSRef targetRef;
    if ([[self aliasDataForDefaultDirectory] fsRefAsAlias:&targetRef]) {	    
	//follow the parent fsrefs up the tree, calling LSCopyDisplayNameForRef, hoping that the root is a drive name
	
	NSMutableArray *directoryNames = [NSMutableArray arrayWithCapacity:4];
	FSRef parentRef, *currentRef = &targetRef;
	
	OSStatus err = noErr;
	
	do {
	    
	    if ((err = FSGetCatalogInfo(currentRef, kFSCatInfoNone, NULL, NULL, NULL, &parentRef)) == noErr) {
		
		CFStringRef displayName = NULL;
		if ((err = LSCopyDisplayNameForRef(currentRef, &displayName)) == noErr) {
		    
		    if (displayName) {
			[directoryNames insertObject:(id)displayName atIndex:0];
			CFRelease(displayName);
		    }
		}
		
		currentRef = &parentRef;
	    }
	} while (err == noErr);
	
	//build new string delimited by triangles like pages in its recent items menu
	return [directoryNames componentsJoinedByString:@" : "];
	
    }
    
    return nil;
}

- (void)setBlorImportAttempted:(BOOL)value {
	[defaults setBool:value forKey:TriedToImportBlorKey];
}

- (BOOL)triedToImportBlor {
	return [defaults boolForKey:TriedToImportBlorKey];
}
- (void)synchronize {
    [defaults synchronize];
}

@end
