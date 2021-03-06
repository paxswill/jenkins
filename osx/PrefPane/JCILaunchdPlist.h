//
//  JCILaunchdPlist.h
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/14/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SecurityFoundation/SFAuthorization.h>
#include <Availability.h>

@interface JCILaunchdPlist : NSObject{
@private
	NSMutableDictionary *plist;
	NSString *path;
	SFAuthorization *authorization;
	NSString *saveHelperPath;
	NSString *sudoHelperPath;
    BOOL saveOnChange;
    NSLock *saveLock;
}
// launchd.plist values
@property (nonatomic, retain, readwrite) NSString *label;
@property (nonatomic, retain, readwrite) NSNumber *disabled;
@property (nonatomic, retain, readwrite) NSString *userName;
@property (nonatomic, retain, readwrite) NSString *groupName;
@property (nonatomic, retain, readwrite) NSMutableDictionary *inetdCompatibility;
@property (nonatomic, retain, readwrite) NSMutableArray *limitLoadToHosts;
@property (nonatomic, retain, readwrite) NSMutableArray *limitLoadFromHosts;
@property (nonatomic, retain, readwrite) NSString *limitLoadToSessionType;
@property (nonatomic, retain, readwrite) NSString *program;
@property (nonatomic, retain, readwrite) NSMutableArray *programArguments;
@property (nonatomic, retain, readwrite) NSNumber *enableGlobbing;
@property (nonatomic, retain, readwrite) NSNumber *enableTransactions;
@property (nonatomic, retain, readwrite) NSNumber *onDemand;
@property (nonatomic, retain, readwrite) id<NSObject> keepAlive;
@property (nonatomic, retain, readwrite) NSNumber *runAtLoad;
@property (nonatomic, retain, readwrite) NSString *rootDirectory;
@property (nonatomic, retain, readwrite) NSString *workingDirectory;
@property (nonatomic, retain, readwrite) NSMutableDictionary *environmentVariables;
@property (nonatomic, retain, readwrite) NSNumber *umask;
@property (nonatomic, retain, readwrite) NSNumber *timeOut;
@property (nonatomic, retain, readwrite) NSNumber *exitTimeOut;
@property (nonatomic, retain, readwrite) NSNumber *throttleInterval;
@property (nonatomic, retain, readwrite) NSNumber *initGroups;
@property (nonatomic, retain, readwrite) NSMutableArray *watchPaths;
@property (nonatomic, retain, readwrite) NSMutableArray *queueDirectories;
@property (nonatomic, retain, readwrite) NSNumber *startOnMount;
@property (nonatomic, retain, readwrite) NSNumber *startIOnterval;
@property (nonatomic, retain, readwrite) id<NSObject> startCalendarInterval;
@property (nonatomic, retain, readwrite) NSString *standardInPath;
@property (nonatomic, retain, readwrite) NSString *standardOutPath;
@property (nonatomic, retain, readwrite) NSString *standardErrorPath;
@property (nonatomic, retain, readwrite) NSNumber *debug;
@property (nonatomic, retain, readwrite) NSNumber *waitForDebugger;
@property (nonatomic, retain, readwrite) NSMutableDictionary *softResourceLimits;
@property (nonatomic, retain, readwrite) NSMutableDictionary *hardResourceLimits;
@property (nonatomic, retain, readwrite) NSNumber *nice;
@property (nonatomic, retain, readwrite) NSNumber *abandonProcessGroup;
@property (nonatomic, retain, readwrite) NSNumber *hopefullyExitsFirst;
@property (nonatomic, retain, readwrite) NSNumber *hopefullyExitsLast;
@property (nonatomic, retain, readwrite) NSNumber *lowPriorityIO;
@property (nonatomic, retain, readwrite) NSNumber *launchOnlyOnce;
@property (nonatomic, retain, readwrite) NSMutableDictionary *machServices;
@property (nonatomic, retain, readwrite) id<NSObject> sockets;

// Other stuff
@property (nonatomic, retain, readonly) NSMutableDictionary *plist;
@property (nonatomic, retain, readwrite) NSString *path;
@property (nonatomic, assign, readwrite, getter=isRunning) BOOL running;
@property (nonatomic, retain, readwrite) SFAuthorization *authorization;
@property (nonatomic, retain, readwrite) NSString *saveHelperPath;
@property (nonatomic, retain, readwrite) NSString *sudoHelperPath;
@property (nonatomic, assign, readwrite) BOOL saveOnChange;

-(id)initWithPath:(NSString *)plistPath;
-(void)load;
-(void)unload;
-(void)start DEPRECATED_ATTRIBUTE;
-(void)stop DEPRECATED_ATTRIBUTE;
-(void)read;
-(void)save;

+(NSString *)makeFirstCapital:(NSString *)string;
+(NSString *)makeFirstLowercase:(NSString *)string;
@end
