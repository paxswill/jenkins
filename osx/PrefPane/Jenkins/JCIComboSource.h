//
//  JCIComboSource.h
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/15/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum{
	JCIEnvironmentVariable = 0,
	JCIJavaArgument,
	JCIJenkinsArgument
} JCIOptionType;

@interface JCIComboSource : NSObject{
	JCIOptionType type;
}
@property (nonatomic, assign, readonly) JCIOptionType type;

-(id)initWithType:(JCIOptionType)optionType;
-(NSString *)localizedDescriptionForIndex:(NSInteger)index;

- (NSUInteger)comboBoxCell:(NSComboBoxCell *)aComboBoxCell indexOfItemWithStringValue:(NSString *)aString;
- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(NSInteger)index;
- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell;
@end
