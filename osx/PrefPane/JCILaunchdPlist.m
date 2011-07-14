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
	}
	return self;
}

-(void)load{
	// Reload and start the daemon
	NSArray *loadArgs = [NSArray arrayWithObjects:@"load", self.path, nil];
	NSArray *startArgs = [NSArray arrayWithObjects:@"start", self.path, nil];
	[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:loadArgs];
	[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:startArgs];
}

-(void)unload{
	NSArray *unloadArgs = [NSArray arrayWithObjects:@"unload", self.path, nil];
	[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:unloadArgs];
}

-(void)start{
	
}

-(void)stop{
	
}

+(NSString *)makeFirstCapital:(NSString *)string{
	NSMutableString *capString = [string mutableCopy];
	const unichar first = [[string capitalizedString] characterAtIndex:0];
	[capString replaceCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithCharacters:&first length:1]];
	return [capString autorelease];
}

-(void)read{
	NSData *plistData = [NSData dataWithContentsOfFile:self.path];
	self.plist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListMutableContainersAndLeaves format:NULL errorDescription:NULL];
}

-(void)save{
	// Set up for elevated execution
	FILE *pipe;
	const char *argv[] = {[self.path UTF8String], NULL};
	// Spawn the privileged process
	AuthorizationExecuteWithPrivileges([self.authorization authorizationRef], [self.helperPath UTF8String], kAuthorizationFlagDefaults, (char * const *)argv, &pipe);
	// Write the data out
	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:self.plist format:NSPropertyListXMLFormat_v1_0 errorDescription:NULL];
	int writeFD = fileno(pipe);
	NSFileHandle *writeHandle = [[NSFileHandle alloc] initWithFileDescriptor:writeFD];
	[writeHandle writeData:plistData];
	[writeHandle closeFile];
	fclose(pipe);
}

-(BOOL)isRunning{
	// Get launchd listing (/bin/launchctl list)
	NSTask *existsTask = [[NSTask alloc] init];
	[existsTask setLaunchPath:@"/bin/launchctl"];
	[existsTask setArguments:[NSArray arrayWithObjects:@"list", nil]];
	NSPipe *existsPipe = [[NSPipe alloc] init];
	[existsTask setStandardOutput:existsPipe];
	[existsTask launch];
	[existsTask waitUntilExit];
	NSFileHandle *existsOutput = [existsPipe fileHandleForReading];
	NSData *existsData = [[existsOutput readDataToEndOfFile] retain];
	NSString *allLines = [[NSString alloc] initWithData:existsData encoding:NSUTF8StringEncoding];
	NSArray *rawLines = [[allLines componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] retain];
	[allLines release];
	/*
	 Search for the job. The format for each line is
	 PID	ExitState	launchdLabel
	 The space between each column is '\t'. If no value is given, the character '-' is substituted
	 */
	for(NSString *line in rawLines){
		if([line isEqualToString:@""]){
			continue;
		}
		NSArray *lineData = [line componentsSeparatedByString:@"\t"];
		if([[lineData objectAtIndex:2] isEqualToString:@"org.jenkins-ci"]){
			if([[lineData objectAtIndex:0] isEqualToString:@"-"]){
				// Loaded, not running
				return NO;
			}else{
				// Loaded and running
				return YES;
			}
		}
	}
	// Not loaded
	return NO;
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
	if([propertySet containsObject:selector]){
		if([selector rangeOfString:@"set"].location == NSNotFound){
			// getter
			return class_addMethod([self class], sel, (IMP)&plistGetProxy, "@:");
		}else{
			// setter
			return class_addMethod([self class], sel, (IMP)&plistSetProxy, "@:@");
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

void plistSetProxy(id self, SEL selector, id value){
	NSString *littleName = NSStringFromSelector(selector);
	[self willChangeValueForKey:littleName];
	NSString *propertyName = [JCILaunchdPlist makeFirstCapital:littleName];
	[[self plist] setValue:value forKey:propertyName];
	[self didChangeValueForKey:littleName];
	[self save];
}
