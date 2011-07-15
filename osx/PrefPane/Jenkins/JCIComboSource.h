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

-(id)initWithType:(JCIOptionType)optionType;

@end
