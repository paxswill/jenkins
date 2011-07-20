//
//  JCILaunchdPlist.m
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/14/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

#import "JCILaunchdPlist.h"
#import <ctype.h>
#import <objc/runtime.h>

id plistGetProxy(id self, SEL selector);
void plistSetProxy(id self, SEL selector, id value);
static NSSet *propertySet = nil;

@interface JCILaunchdPlist()
@property (nonatomic, retain, readwrite) NSMutableDictionary *plist;

@end

@implementation JCILaunchdPlist

@dynamic label;
@dynamic disabled;
@dynamic userName;
@dynamic groupName;
@dynamic inetdCompatibility;
@dynamic limitLoadToHosts;
@dynamic limitLoadFromHosts;
@dynamic limitLoadToSessionType;
@dynamic program;
@dynamic programArguments;
@dynamic enableGlobbing;
@dynamic enableTransactions;
@dynamic onDemand;
@dynamic keepAlive;
@dynamic runAtLoad;
@dynamic rootDirectory;
@dynamic workingDirectory;
@dynamic environmentVariables;
@dynamic umask;
@dynamic timeOut;
@dynamic exitTimeOut;
@dynamic throttleInterval;
@dynamic initGroups;
@dynamic watchPaths;
@dynamic queueDirectories;
@dynamic startOnMount;
@dynamic startIOnterval;
@dynamic startCalendarInterval;
@dynamic standardInPath;
@dynamic standardOutPath;
@dynamic standardErrorPath;
@dynamic debug;
@dynamic waitForDebugger;
@dynamic softResourceLimits;
@dynamic hardResourceLimits;
@dynamic nice;
@dynamic abandonProcessGroup;
@dynamic hopefullyExitsFirst;
@dynamic hopefullyExitsLast;
@dynamic lowPriorityIO;
@dynamic launchOnlyOnce;
@dynamic machServices;
@dynamic sockets;

@synthesize plist;
@synthesize path;
@synthesize authorization;
@synthesize helperPath;
@synthesize saveOnChange;

-(id)initWithPath:(NSString *)plistPath{
	if((self = [super init])){
		self.path = plistPath;
		NSFileManager *fm = [[NSFileManager alloc] init];
		if([fm fileExistsAtPath:self.path]){
			[self read];
		}else{
			self.plist = [NSMutableDictionary dictionary];
		}
		[fm release];
        self.saveOnChange = NO;
        saveLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc {
	if(self.authorization){
		[self save];
		[self unload];
		[self load];
	}
	self.path = nil;
	self.plist = nil;
	self.helperPath = nil;
	self.authorization = nil;
    [saveLock release];
    [super dealloc];
}

-(void)load{
	// Reload and start the daemon
	const char *argv[] = { "load", [self.path UTF8String], NULL };
	AuthorizationExecuteWithPrivileges([self.authorization authorizationRef], "/bin/launchctl", kAuthorizationFlagDefaults, (char * const *)argv, NULL);
}

-(void)unload{
	const char *argv[] = { "unload", [self.path UTF8String], NULL };
	AuthorizationExecuteWithPrivileges([self.authorization authorizationRef], "/bin/launchctl", kAuthorizationFlagDefaults, (char * const *)argv, NULL);
}

-(void)start{
	const char *argv[] = { "start", [self.label UTF8String], NULL };
	AuthorizationExecuteWithPrivileges([self.authorization authorizationRef], "/bin/launchctl", kAuthorizationFlagDefaults, (char * const *)argv, NULL);
}

-(void)stop{
	const char *argv[] = { "stop", [self.label UTF8String], NULL };
	AuthorizationExecuteWithPrivileges([self.authorization authorizationRef], "/bin/launchctl", kAuthorizationFlagDefaults, (char * const *)argv, NULL);
}

-(void)read{
	NSData *plistData = [NSData dataWithContentsOfFile:self.path];
	self.plist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListMutableContainersAndLeaves format:NULL errorDescription:NULL];
}

-(void)save{
    [saveLock lock];
	// Set up for elevated execution
	FILE *pipe;
	const char *argv[] = {[self.path UTF8String], NULL};
	// Spawn the privileged process
    // TODO: error checking
	OSErr error = AuthorizationExecuteWithPrivileges([self.authorization authorizationRef], [self.helperPath UTF8String], kAuthorizationFlagDefaults, (char * const *)argv, &pipe);
	// Write the data out
	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:self.plist format:NSPropertyListXMLFormat_v1_0 errorDescription:NULL];
	NSFileHandle *writeHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileno(pipe) closeOnDealloc:YES];
	[writeHandle writeData:plistData];
	[writeHandle closeFile];
	[writeHandle release];
    [saveLock unlock];
}

+(NSString *)makeFirstCapital:(NSString *)string{
	NSMutableString *capString = [string mutableCopy];
	const unichar first = [[string capitalizedString] characterAtIndex:0];
	[capString replaceCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithCharacters:&first length:1]];
	return [capString autorelease];
}

+(NSString *)makeFirstLowercase:(NSString *)string{
    NSMutableString *littleString = [string mutableCopy];
	const unichar first = [[string lowercaseString] characterAtIndex:0];
	[littleString replaceCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithCharacters:&first length:1]];
	return [littleString autorelease];
}

-(BOOL)isRunning{
	// Get launchd listing (/bin/launchctl list)
	FILE *pipe;
	const char *argv[] = { "list", NULL };
	OSErr err = AuthorizationExecuteWithPrivileges([self.authorization authorizationRef], "/bin/launchctl", kAuthorizationFlagDefaults, (char * const *)argv, &pipe);
	if(err != errAuthorizationSuccess){
		NSLog(@"Error elevating process (%d)", err);
		return NO;
	}
	NSFileHandle *fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileno(pipe) closeOnDealloc:YES];
	NSData *existsData = [[fileHandle readDataToEndOfFile] retain];
	[fileHandle release];
	NSString *allLines = [[NSString alloc] initWithData:existsData encoding:NSUTF8StringEncoding];
	[existsData release];
	NSArray *rawLines = [[allLines componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] retain];
	[allLines release];
	/*
	 Search for the job. The format for each line is
	 PID	ExitState	launchdLabel
	 The space between each column is '\t'. If no value is given, the character '-' is substituted
	 */
	BOOL found = NO;
	for(NSString *line in rawLines){
		if([line isEqualToString:@""]){
			continue;
		}
		NSArray *lineData = [line componentsSeparatedByString:@"\t"];
		if([[lineData objectAtIndex:2] isEqualToString:@"org.jenkins-ci"]){
			if([[lineData objectAtIndex:0] isEqualToString:@"-"]){
				// Loaded, not running
				found = NO;
				break;
			}else{
				// Loaded and running
				found = YES;
				break;
			}
		}
	}
	[rawLines release];
	// Not loaded
	return found;
}

-(void)setRunning:(BOOL)runJenkins{
	if(self.running != runJenkins){
		[self willChangeValueForKey:@"running"];
		[self unload];
		if(runJenkins){
			[self load];
		}
		[self didChangeValueForKey:@"running"];
	}
}

+(BOOL)resolveInstanceMethod:(SEL)sel{
	NSString *selector = NSStringFromSelector(sel);
	NSRange setRange = [selector rangeOfString:@"set"];
	BOOL isSetter = setRange.location == 0;
	NSString *trimmedSelector = isSetter ? [selector substringWithRange:NSMakeRange(3, ([selector length] - 4))] : selector;
    trimmedSelector = [JCILaunchdPlist makeFirstLowercase:trimmedSelector];
	if([propertySet containsObject:trimmedSelector]){
		if(isSetter){
			// setter
			return class_addMethod([self class], sel, (IMP)&plistSetProxy, "@:@");
		}else{
			// getter
			return class_addMethod([self class], sel, (IMP)&plistGetProxy, "@:");
		}
	}else{
		return NO;
	}
}

+(void)initialize{
	propertySet = [[NSSet alloc] initWithObjects:@"label",
												 @"disabled",
												 @"userName",
												 @"groupName",
												 @"inetdCompatibility",
												 @"limitLoadToHosts",
												 @"limitLoadFromHosts",
												 @"limitLoadToSessionType",
												 @"program",
												 @"programArguments",
												 @"enableGlobbing",
												 @"enableTransactions",
												 @"onDemand",
												 @"keepAlive",
												 @"runAtLoad",
												 @"rootDirectory",
												 @"workingDirectory",
												 @"environmentVariables",
												 @"umask",
												 @"timeOut",
												 @"exitTimeOut",
												 @"throttleInterval",
												 @"initGroups",
												 @"watchPaths",
												 @"queueDirectories",
												 @"startOnMount",
												 @"startIOnterval",
												 @"startCalendarInterval",
												 @"standardInPath",
												 @"standardOutPath",
												 @"standardErrorPath",
												 @"debug",
												 @"waitForDebugger",
												 @"softResourceLimits",
												 @"hardResourceLimits",
												 @"nice",
												 @"abandonProcessGroup",
												 @"hopefullyExitsFirst",
												 @"hopefullyExitsLast",
												 @"lowPriorityIO",
												 @"launchOnlyOnce",
												 @"machServices",
												 @"sockets", nil];
}

@end

id plistGetProxy(id self, SEL selector){
	NSString *propertyName = [JCILaunchdPlist makeFirstCapital:NSStringFromSelector(selector)];
	id value = [[self plist] objectForKey:propertyName];
	// Massage program arguments
	if([propertyName isEqualToString:@"ProgramArguments"] && [[self plist] objectForKey:@"Program"] == nil){
		NSMutableArray *args = [value mutableCopy];
		[args removeObjectAtIndex:0];
		return [args autorelease];
	}
	if(value == nil){
		// Provide for default values
		if([propertyName isEqualToString:@"Program"]){
			if([self programArguments] != nil){
				return [[self programArguments] objectAtIndex:0];
			}
		}else if([propertyName isEqualToString:@"OnDemand"]){
			// Note: this key is deprecated, and is contrary to the 10.5 and 10.6 default
			return [NSNumber numberWithBool:YES];
		}else if([propertyName isEqualToString:@"KeepAlive"]){
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"RunAtLoad"]){
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"ExitTimeOut"]){
			return [NSNumber numberWithInt:20];
		}else if([propertyName isEqualToString:@"ThrottleInterval"]){
			return [NSNumber numberWithInt:10];
		}else if([propertyName isEqualToString:@"InitGroups"]){
			return [NSNumber numberWithBool:YES];
		}else if([propertyName isEqualToString:@"LaunchOnlyOnce"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"EnableGlobbing"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"EnableTransactions"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"StartOnMount"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"Debug"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"WaitForDebugger"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"AbandonProcessGroup"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"HopefullyExitsFirst"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"HopefullyExitsFirst"]){
			// Inferred from the man page
			return [NSNumber numberWithBool:NO];
		}else if([propertyName isEqualToString:@"Disabled"]){
			// Inferred from man page
			return [NSNumber numberWithBool:NO];
		}
	}else{
		return value;
	}
	return nil;
}

void plistSetProxy(id self, SEL sel, id value){
    NSString *selector = NSStringFromSelector(sel);
	NSString *littleName = [JCILaunchdPlist makeFirstLowercase:[selector substringWithRange:NSMakeRange(3, ([selector length] - 4))]];
	[self willChangeValueForKey:littleName];
	NSString *propertyName = [JCILaunchdPlist makeFirstCapital:littleName];
	// Un-massage the input
	if([propertyName isEqualToString:@"ProgramArguments"]){
		if([[self plist] objectForKey:@"Program"] == nil){
			NSRange argumentsRange = NSMakeRange(1, [[self programArguments] count]);
			[[[self plist] objectForKey:@"ProgramArguments"] replaceObjectsInRange:argumentsRange withObjectsFromArray:value];
			[self didChangeValueForKey:littleName];
            if([self saveOnChange]){
                [self save];
            }
			return;
		}
	}
	[[self plist] setValue:value forKey:propertyName];
	[self didChangeValueForKey:littleName];
    if([self saveOnChange]){
        [self save];
    }
}
