//
//  JCIJenkinsRunningTransformer.m
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/26/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

#import "JCIJenkinsRunningTransformer.h"

@implementation JCIJenkinsRunningTransformer

+(Class)transformedValueClass{
	return [NSString class];
}

+(BOOL)allowsReverseTransformation{
	return NO;
}

-(id)transformedValue:(id)value{
	// Takes an NSNumber containing a BOOL
	if([value boolValue]){
		return [[NSBundle bundleWithIdentifier:@"org.jenkins-ci.JenkinsPrefPane"] localizedStringForKey:@"Start Jenkins" value:@"!Start!" table:nil];
	}else{
		return [[NSBundle bundleWithIdentifier:@"org.jenkins-ci.JenkinsPrefPane"] localizedStringForKey:@"Stop Jenkins" value:@"!Stop!" table:nil];
	}
}

@end
