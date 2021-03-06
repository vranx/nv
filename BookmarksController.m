//
//  BookmarksController.m
//  Notation
//
//  Created by Zachary Schneirov on 1/21/07.
//  Copyright 2007 Zachary Schneirov. All rights reserved.
//

#import "BookmarksController.h"
#import "NoteObject.h"
#import "GlobalPrefs.h"
#import "AppController.h"
#import "NSString_NV.h"
#import "NSCollection_utils.h"

static NSString *BMSearchStringKey = @"SearchString";
static NSString *BMNoteUUIDStringKey = @"NoteUUIDString";

@implementation NoteBookmark

- (id)initWithDictionary:(NSDictionary*)aDict {
	if (aDict) {
		NSString *uuidString = [aDict objectForKey:BMNoteUUIDStringKey];
		if (uuidString) {
			[self initWithNoteUUIDBytes:[uuidString uuidBytes] searchString:[aDict objectForKey:BMSearchStringKey]];
		} else {
			NSLog(@"NoteBookmark init: supplied nil uuidString");
		}
	} else {
		NSLog(@"NoteBookmark init: supplied nil dictionary; couldn't init");
		return nil;
	}
	return self;
}

- (id)initWithNoteUUIDBytes:(CFUUIDBytes)bytes searchString:(NSString*)aString {
	if ([super init]) {
		uuidBytes = bytes;
		searchString = [aString copy];
	}
	
	return self;
}

- (id)initWithNoteObject:(NoteObject*)aNote searchString:(NSString*)aString {
	
	if ([super init] && aNote) {
		noteObject = [aNote retain];
		searchString = [aString copy];
		
		CFUUIDBytes *bytes = [aNote uniqueNoteIDBytes];
		if (!bytes) {
			NSLog(@"NoteBookmark init: no cfuuidbytes pointer from note %@", titleOfNote(aNote));
			return nil;
		}
		uuidBytes = *bytes;
	} else {
		NSLog(@"NoteBookmark init: supplied nil note");
		return nil;
	}
	return self;
}

- (void)dealloc {
	[searchString release];
	[noteObject release];
	
	[super dealloc];
}

- (NSString*)searchString {
	return searchString;
}

- (void)validateNoteObject {
	NoteObject *newNote = nil;
	
	//if we already had a valid note and our uuidBytes don't resolve to the same note
	//then use that new note from the delegate. in 100% of the cases newNote should be nil
	if (noteObject && (newNote = [delegate noteWithUUIDBytes:uuidBytes]) != noteObject) {
		[noteObject release];
		noteObject = [newNote retain];
	}
}

- (NoteObject*)noteObject {
	if (!noteObject) noteObject = [[delegate noteWithUUIDBytes:uuidBytes] retain];
	return noteObject;
}
- (NSDictionary*)dictionaryRep {
	return [NSDictionary dictionaryWithObjectsAndKeys:searchString, BMSearchStringKey, 
		[NSString uuidStringWithBytes:uuidBytes], BMNoteUUIDStringKey, nil];
}

- (NSString *)description {
	NoteObject *note = [self noteObject];
	if (note) {
		return [searchString length] ? [NSString stringWithFormat:@"%@ [%@]", titleOfNote(note), searchString] : titleOfNote(note);
	}
	return nil;
}

- (void)setDelegate:(id)aDelegate {
	delegate = aDelegate;
}

- (id)delegate {
	return delegate;
}

- (BOOL)isEqual:(id)anObject {
    return noteObject == [anObject noteObject];
}
- (NSUInteger)hash {
    return (NSUInteger)noteObject;
}

@end


#define MovedBookmarksType @"NVMovedBookmarksType"

@implementation BookmarksController

- (id)init {
	if ([super init]) {
		bookmarks = [[NSMutableArray alloc] init];
		isSelectingProgrammatically = isRestoringSearch = NO;
		
		prefsController = [GlobalPrefs defaultPrefs];
	}
	return self;
}

- (void)awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableViewSelectionDidChange:) 
												   name:NSTableViewSelectionDidChangeNotification object:bookmarksTableView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableViewSelectionDidChange:) 
												 name:NSTableViewSelectionIsChangingNotification object:bookmarksTableView];
//	[window setFloatingPanel:YES];
	[window setDelegate:self];
	[bookmarksTableView setDelegate:self];
	
	[bookmarksTableView registerForDraggedTypes:[NSArray arrayWithObjects:MovedBookmarksType, nil]];
}

- (void)dealloc {
	[bookmarks release];
	[super dealloc];
}

- (id)initWithBookmarks:(NSArray*)array {
	if ([self init]) {
		unsigned int i;
		for (i=0; i<[array count]; i++) {
			NSDictionary *dict = [array objectAtIndex:i];
			NoteBookmark *bookmark = [[NoteBookmark alloc] initWithDictionary:dict];
			[bookmark setDelegate:self];
			[bookmarks addObject:bookmark];
			[bookmark release];
		}
	}

	return self;
}

- (NSArray*)dictionaryReps {
	
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[bookmarks count]];
	unsigned int i;
	for (i=0; i<[bookmarks count]; i++) {
		NSDictionary *dict = [[bookmarks objectAtIndex:i] dictionaryRep];
		if (dict) [array addObject:dict];
	}
	
	return array;
}

- (void)setNotes:(NSArray*)someNotes {
	[notes release];
	notes = [someNotes retain];
	
	[bookmarks makeObjectsPerformSelector:@selector(validateNoteObject)];
}

- (NoteObject*)noteWithUUIDBytes:(CFUUIDBytes)bytes {
	NSUInteger noteIndex = [notes indexOfNoteWithUUIDBytes:&bytes];
	if (noteIndex != NSNotFound) return [notes objectAtIndex:noteIndex];
	return nil;
}

- (void)removeBookmarkForNote:(NoteObject*)aNote {
	unsigned int i;

	for (i=0; i<[bookmarks count]; i++) {
		if ([[bookmarks objectAtIndex:i] noteObject] == aNote) {
			[bookmarks removeObjectAtIndex:i];
			
			[self updateBookmarksUI];
			break;
		}
	}
}


- (void)setBookmarksMenu {
	
	NSMenu *menu = [NSApp mainMenu];
	NSMenu *bookmarksMenu = [[menu itemWithTag:103] submenu];
	while ([bookmarksMenu numberOfItems]) {
		[bookmarksMenu removeItemAtIndex:0];
	}
		
	NSMenuItem *theMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Bookmarks",@"menu item title for showing bookmarks") 
														  action:@selector(showBookmarks:) keyEquivalent:@"0"] autorelease];
	[theMenuItem setTarget:self];
	[bookmarksMenu addItem:theMenuItem];
	
	[bookmarksMenu addItem:[NSMenuItem separatorItem]];
		
	theMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add to Bookmarks",@"menu item title for bookmarking a note") 
											  action:@selector(addBookmark:) keyEquivalent:@"D"] autorelease];
	[theMenuItem setTarget:self];
	[bookmarksMenu addItem:theMenuItem];
	
	if ([bookmarks count] > 0) [bookmarksMenu addItem:[NSMenuItem separatorItem]];
	
	unsigned int i;
	for (i=0; i<[bookmarks count]; i++) {

		NoteBookmark *bookmark = [bookmarks objectAtIndex:i];
		NSString *description = [bookmark description];
		if (description) {
			theMenuItem = [[[NSMenuItem alloc] initWithTitle:description action:@selector(restoreBookmark:) 
											   keyEquivalent:[NSString stringWithFormat:@"%d", (i % 9) + 1]] autorelease];
			if (i > 8) [theMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];
			if (i > 17) [theMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask | NSControlKeyMask];
			[theMenuItem setRepresentedObject:bookmark];
			[theMenuItem setTarget:self];
			[bookmarksMenu addItem:theMenuItem];
		}
	}
}

- (void)updateBookmarksUI {
	
	[prefsController setBookmarksFromSender:self];
	
	[self setBookmarksMenu];
	
	[bookmarksTableView reloadData];
}

- (void)selectBookmarkInTableView:(NoteBookmark*)bookmark {
	if (bookmarksTableView && bookmark) {
		//find bookmark index and select
		NSUInteger bmIndex = [bookmarks indexOfObjectIdenticalTo:bookmark];
		if (bmIndex != NSNotFound) {
			isSelectingProgrammatically = YES;
			[bookmarksTableView selectRow:bmIndex byExtendingSelection:NO];
			isSelectingProgrammatically = NO;
			[removeBookmarkButton setEnabled:YES];
		}
	}
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem {
	//need to fix this for better style detection
	
	SEL action = [menuItem action];
	if (action == @selector(addBookmark:)) {
		
		return ([bookmarks count] < 27 && [delegate selectedNoteObject]);
	}
	
	return YES;
}

- (BOOL)restoreNoteBookmark:(NoteBookmark*)bookmark {
	if (bookmark) {

		//communicate with revealer here--tell it to search for this string and highlight note
		if ([revealTarget respondsToSelector:revealAction]) {
			isRestoringSearch = YES;
			
			[revealTarget performSelector:revealAction withObject:bookmark];
			[self selectBookmarkInTableView:bookmark];
			
			isRestoringSearch = NO;
		} else {
			NSLog(@"reveal target %@ doesn't respond to %s!", revealTarget, revealAction);
			return NO;
		}
		return YES;
	}
	return NO;
}

- (void)restoreBookmark:(id)sender {
	[self restoreNoteBookmark:[sender representedObject]];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	if ([[aTableColumn identifier] isEqualToString:@"description"]) {
		NSString *description = [[bookmarks objectAtIndex:rowIndex] description];
		if (description) 
			return description;
		return [NSString stringWithFormat:NSLocalizedString(@"(Unknown Note) [%@]",nil), [[bookmarks objectAtIndex:rowIndex] searchString]];
	}
	
	static NSString *shiftCharStr = nil, *cmdCharStr = nil, *ctrlCharStr = nil;
	if (!cmdCharStr) {
		unichar ch = 0x2318;
		cmdCharStr = [[NSString stringWithCharacters:&ch length:1] retain];
		ch = 0x21E7;
		shiftCharStr = [[NSString stringWithCharacters:&ch length:1] retain];
		ch = 0x2303;
		ctrlCharStr = [[NSString stringWithCharacters:&ch length:1] retain];
	}
	
	return [NSString stringWithFormat:@"%@%@%@ %d", rowIndex > 17 ? ctrlCharStr : @"", rowIndex > 8 ? shiftCharStr : @"", cmdCharStr, (rowIndex % 9) + 1];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [bookmarks count];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	if (!isRestoringSearch && !isSelectingProgrammatically) {
		int row = [bookmarksTableView selectedRow];
		if (row > -1) [self restoreNoteBookmark:[bookmarks objectAtIndex:row]];
		
		[removeBookmarkButton setEnabled: row > -1];
	}
}

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard {
    NSArray *typesArray = [NSArray arrayWithObject:MovedBookmarksType];
	
	[pboard declareTypes:typesArray owner:self];
    [pboard setPropertyList:rows forType:MovedBookmarksType];
	
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)op {
    
    NSDragOperation dragOp = ([info draggingSource] == bookmarksTableView) ? NSDragOperationMove : NSDragOperationCopy;
	
    [tv setDropRow:row dropOperation:NSTableViewDropAbove];
	
    return dragOp;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op {
    if (row < 0)
		row = 0;
    
    if ([info draggingSource] == bookmarksTableView) {
		NSArray *rows = [[info draggingPasteboard] propertyListForType:MovedBookmarksType];
		NSInteger theRow = [[rows objectAtIndex:0] intValue];
		
		id object = [[bookmarks objectAtIndex:theRow] retain];
		
		if (row != theRow + 1 && row != theRow) {
			NoteBookmark* selectedBookmark = nil;
			int selRow = [bookmarksTableView selectedRow];
			if (selRow > -1) selectedBookmark = [bookmarks objectAtIndex:selRow];
			
			if (row < theRow)
				[bookmarks removeObjectAtIndex:theRow];
			
			if (row <= (int)[bookmarks count])
				[bookmarks insertObject:object atIndex:row];
			else
				[bookmarks addObject:object];
			
			if (row > theRow)
				[bookmarks removeObjectAtIndex:theRow];
			
			[object release];
			
			[self updateBookmarksUI];
			[self selectBookmarkInTableView:selectedBookmark];
			
			return YES;
		}
		return NO;
    }
	
	return NO;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame {
	
	float oldHeight = 0.0;
	float newHeight = 0.0;
	NSRect newFrame = [sender frame];
	NSSize intercellSpacing = [bookmarksTableView intercellSpacing];
	
	newHeight = [bookmarksTableView numberOfRows] * ([bookmarksTableView rowHeight] + intercellSpacing.height);	
	oldHeight = [[[bookmarksTableView enclosingScrollView] contentView] frame].size.height;
	newHeight = [sender frame].size.height - oldHeight + newHeight;
	
	//adjust origin so the window sticks to the upper left
	newFrame.origin.y = newFrame.origin.y + newFrame.size.height - newHeight;
	
	newFrame.size.height = newHeight;
	return newFrame;
}

- (void)windowWillClose:(NSNotification *)notification {
	[showHideBookmarksItem setAction:@selector(showBookmarks:)];
	[showHideBookmarksItem setTitle:NSLocalizedString(@"Show Bookmarks",@"menu item title")];
}

- (void)hideBookmarks:(id)sender {
	
	[window close];	
}

- (void)showBookmarks:(id)sender {
	if (!window) {
		if (![NSBundle loadNibNamed:@"SavedSearches" owner:self])  {
			NSLog(@"Failed to load SavedSearches.nib");
			NSBeep();
			return;
		}
		[bookmarksTableView setDataSource:self];
	}
	
	[bookmarksTableView reloadData];
	[window makeKeyAndOrderFront:self];
	
	[showHideBookmarksItem release];
	showHideBookmarksItem = [sender retain];
	[sender setAction:@selector(hideBookmarks:)];
	[sender setTitle:NSLocalizedString(@"Hide Bookmarks",@"menu item title")];

	//highlight searches as appropriate while the window is open
	//selecting a search restores it
}

- (void)clearAllBookmarks:(id)sender {
	if (NSRunAlertPanel(NSLocalizedString(@"Remove all bookmarks?",@"alert title when clearing bookmarks"), 
						NSLocalizedString(@"You cannot undo this action.",nil), 
						NSLocalizedString(@"Remove All Bookmarks",nil), NSLocalizedString(@"Cancel",nil), NULL) == NSAlertDefaultReturn) {

		[bookmarks removeAllObjects];
	
		[self updateBookmarksUI];
	}
}

- (void)addBookmark:(id)sender {
	
	if (![delegate selectedNoteObject]) {
		
		NSRunAlertPanel(NSLocalizedString(@"No note selected.",@"alert title when bookmarking no note"), NSLocalizedString(@"You must select a note before it can be added as a bookmark.",nil), NSLocalizedString(@"OK",nil), nil, NULL);
		
	} else if ([bookmarks count] < 27) {
		NSString *newString = [[delegate fieldSearchString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];		
		
		NoteBookmark *bookmark = [[NoteBookmark alloc] initWithNoteObject:[delegate selectedNoteObject] searchString:newString];
		if (bookmark) {
			
			NSUInteger existingIndex = [bookmarks indexOfObject:bookmark];
			if (existingIndex != NSNotFound) {
				//show them what they've already got
				NoteBookmark *existingBookmark = [bookmarks objectAtIndex:existingIndex];
				if ([window isVisible]) [self selectBookmarkInTableView:existingBookmark];
			} else {
				[bookmark setDelegate:self];
				[bookmarks addObject:bookmark];
				[self updateBookmarksUI];
				if ([window isVisible]) [self selectBookmarkInTableView:bookmark];
			}
		}
		[bookmark release];
	} else {
		//there are only so many numbers and modifiers
		NSRunAlertPanel(NSLocalizedString(@"Too many bookmarks.",nil), NSLocalizedString(@"You cannot create more than 26 bookmarks. Try removing some first.",nil), NSLocalizedString(@"OK",nil), nil, NULL);
	}
}

- (void)removeBookmark:(id)sender {
	
	NoteBookmark *bookmark = nil;
	int row = [bookmarksTableView selectedRow];
	if (row > -1) {
		bookmark = [bookmarks objectAtIndex:row];
		[bookmarks removeObjectIdenticalTo:bookmark];
		[self updateBookmarksUI];
	}
}

- (void)setRevealTarget:(id)target selector:(SEL)selector {
	revealTarget = target;
	revealAction = selector;
}

- (id)delegate {
	return delegate;
}

- (void)setDelegate:(id)aDelegate {
	if ([aDelegate respondsToSelector:@selector(fieldSearchString)] && 
		[aDelegate respondsToSelector:@selector(selectedNoteObject)]) {
		delegate = aDelegate;
	} else {
		NSLog(@"Delegate %@ doesn't respond to our selectors!", aDelegate);
	}
}

@end
