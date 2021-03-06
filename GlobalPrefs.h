//
//  GlobalPrefs.h
//  Notation
//
//  Created by Zachary Schneirov on 1/31/06.
//  Copyright 2006 Zachary Schneirov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SynchronizedNoteProtocol.h"

extern NSString *NoteTitleColumnString;
extern NSString *NoteLabelsColumnString;
extern NSString *NoteDateModifiedColumnString;
extern NSString *NoteDateCreatedColumnString;

extern NSString *NVPTFPboardType;

@class BookmarksController;
@class NotationPrefs;
@class PTKeyCombo;
@class PTHotKey;

@interface GlobalPrefs : NSObject {
	NSUserDefaults *defaults;
	
	IMP runCallbacksIMP;
	NSMutableDictionary *selectorObservers;
	
	PTKeyCombo *appActivationKeyCombo;
	PTHotKey *appActivationHotKey;
	
	BookmarksController *bookmarksController;
	NotationPrefs *notationPrefs;
	NSDictionary *noteBodyAttributes, *searchTermHighlightAttributes;
	NSMutableParagraphStyle *noteBodyParagraphStyle;
	NSFont *noteBodyFont;
	NSColor *searchTermHighlightColor;
	BOOL autoCompleteSearches;
	
	NSMutableArray *tableColumns;
}

+ (GlobalPrefs *)defaultPrefs;

- (void)registerForSettingChange:(SEL)selector withTarget:(id)sender;
- (void)unregisterForNotificationsFromSelector:(SEL)selector sender:(id)sender;
- (void)notifyCallbacksForSelector:(SEL)selector excludingSender:(id)sender;

- (void)setNotationPrefs:(NotationPrefs*)newNotationPrefs sender:(id)sender;
- (NotationPrefs*)notationPrefs;

- (void)removeTableColumn:(NSString*)columnKey sender:(id)sender;
- (void)addTableColumn:(NSString*)columnKey sender:(id)sender;
- (NSArray*)visibleTableColumns;

- (void)setSortedTableColumnKey:(NSString*)sortedKey reversed:(BOOL)reversed sender:(id)sender;
- (NSString*)sortedTableColumnKey;
- (BOOL)tableIsReverseSorted;

- (void)resolveNoteBodyFontFromNotationPrefsFromSender:(id)sender;
- (void)_setNoteBodyFont:(NSFont*)aFont;
- (void)setNoteBodyFont:(NSFont*)aFont sender:(id)sender;
- (NSFont*)noteBodyFont;
- (NSDictionary*)noteBodyAttributes;
- (NSParagraphStyle*)noteBodyParagraphStyle;
- (BOOL)_bodyFontIsMonospace;

- (void)setTabIndenting:(BOOL)value sender:(id)sender;
- (BOOL)tabKeyIndents;

- (void)setCheckSpellingAsYouType:(BOOL)value sender:(id)sender;
- (BOOL)checkSpellingAsYouType;

- (void)setConfirmNoteDeletion:(BOOL)value sender:(id)sender;
- (BOOL)confirmNoteDeletion;

- (void)setQuitWhenClosingWindow:(BOOL)value sender:(id)sender;
- (BOOL)quitWhenClosingWindow;

- (void)setAppActivationKeyCombo:(PTKeyCombo*)aCombo sender:(id)sender;
- (PTKeyCombo*)appActivationKeyCombo;
- (PTHotKey*)appActivationHotKey;
- (BOOL)registerAppActivationKeystrokeWithTarget:(id)target selector:(SEL)selector;

- (void)setPastePreservesStyle:(BOOL)value sender:(id)sender;
- (BOOL)pastePreservesStyle;

- (void)setLinksAutoSuggested:(BOOL)value sender:(id)sender;
- (BOOL)linksAutoSuggested;

- (void)setMakeURLsClickable:(BOOL)value sender:(id)sender;
- (BOOL)URLsAreClickable;

- (void)setSearchTermHighlightColor:(NSColor*)color sender:(id)sender;
- (NSDictionary*)searchTermHighlightAttributes;
- (NSColor*)searchTermHighlightColor;

- (void)setSoftTabs:(BOOL)value sender:(id)sender;
- (BOOL)softTabs;

- (int)numberOfSpacesInTab;

- (BOOL)drawFocusRing;

- (float)tableFontSize;
- (void)setTableFontSize:(float)fontSize sender:(id)sender;

- (BOOL)autoCompleteSearches;
- (void)setAutoCompleteSearches:(BOOL)value sender:(id)sender;

- (NSString*)lastSelectedPreferencesPane;
- (void)setLastSelectedPreferencesPane:(NSString*)pane sender:(id)sender;

- (CFUUIDBytes)UUIDBytesOfLastSelectedNote;
- (NSString*)lastSearchString;
- (void)setLastSearchString:(NSString*)string selectedNote:(id<SynchronizedNote>)aNote sender:(id)sender;

- (void)setBookmarksFromSender:(id)sender;
- (BookmarksController*)bookmarksController;

- (void)setAliasDataForDefaultDirectory:(NSData*)alias sender:(id)sender;
- (NSData*)aliasDataForDefaultDirectory;

- (NSImage*)iconForDefaultDirectoryWithFSRef:(FSRef*)fsRef;
- (NSString*)displayNameForDefaultDirectoryWithFSRef:(FSRef*)fsRef;
- (NSString*)humanViewablePathForDefaultDirectory;

- (void)setBlorImportAttempted:(BOOL)value;
- (BOOL)triedToImportBlor;

- (void)synchronize;

@end

@interface NSObject (GlobalPrefsDelegate)
	- (void)settingChangedForSelectorString:(NSString*)selectorString;
@end


