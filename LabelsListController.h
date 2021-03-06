//
//  LabelsListController.h
//  Notation
//
//  Created by Zachary Schneirov on 1/10/06.
//  Copyright 2006 Zachary Schneirov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FastListDataSource.h"

@class NoteObject;
@class LabelObject;

@interface LabelsListController : FastListDataSource {
	NSCountedSet *allLabels, *filteredLabels;
	unsigned *removeIndicies;
}

- (void)unfilterLabels;
- (void)filterLabelSet:(NSSet*)labelSet;
- (void)recomputeListFromFilteredSet;

- (NSSet*)notesAtFilteredIndex:(int)labelIndex;
- (NSSet*)notesAtFilteredIndexes:(NSIndexSet*)anIndexSet;

//mostly useful for updating labels of notes individually
- (void)addLabelSet:(NSSet*)labelSet toNote:(NoteObject*)note;
- (void)removeLabelSet:(NSSet*)labelSet fromNote:(NoteObject*)note;

//for changing note labels en masse
- (void)addLabelSet:(NSSet*)labelSet toNoteSet:(NSSet*)notes;
- (void)removeLabelSet:(NSSet*)labelSet fromNoteSet:(NSSet*)notes;

@end
