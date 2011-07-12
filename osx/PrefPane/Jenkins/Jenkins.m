//
//  Jenkins.m
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import "Jenkins.h"

@interface Jenkins()
-(void)loadPlist;
-(void)savePlist;
+(NSString *)convertToArgumentString:(id<NSObject>)obj;
@end

@implementation Jenkins

@synthesize launchdPlist;
@synthesize plistPath;
@synthesize plistName;
@synthesize uiEnabled;

@synthesize otherFlags;
@synthesize startButton;
@synthesize updateButton;
@synthesize autostart;
@synthesize authorizationView;

- (void)mainViewDidLoad{
	// Setup authorization
	[self.authorizationView setAutoupdate:YES];
	AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &items};
	[self.authorizationView setAuthorizationRights:&rights];
	self.authorizationView.delegate = self;
	self.uiEnabled = [self isUnlocked];
	
	// Find the Jenkins launchd plist
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES);
	NSString *libraryPath = [libraryPaths count] > 0 ? [[libraryPaths objectAtIndex:0] retain] 
	                                                 : @"/Library";
	[libraryPaths release];
	libraryPath = [libraryPath stringByAppendingString:@"/LaunchDaemons/"];
	self.plistName = @"org.jenkins-ci.plist";
	self.plistPath = [libraryPath stringByAppendingString:self.plistName];
	[libraryPath release];
	[self loadPlist];
}

-(void)willSelect{
	[self loadPlist];
	// Set the start/stop button
	if(self.running){
		self.startButton.title = @"Stop";
	}else{
		self.startButton.title = @"Start";
	}
	// Set autostart checkbox
	if(![[self.launchdPlist valueForKey:@"Disabled"] boolValue] && [[self.launchdPlist valueForKey:@"RunAtLoad"] boolValue]){
		[self.autostart setState:NSOnState];
	}else{
		[self.autostart setState:NSOffState];
	}
}

-(void)loadPlist{
	// Reading is unprivileged, so no auth services 
	NSData *plistData = [NSData dataWithContentsOfFile:self.plistPath];
	[self willChangeValueForKey:@"httpPort"];
	[self willChangeValueForKey:@"httpsPort"];
	[self willChangeValueForKey:@"ajpPort"];
	[self willChangeValueForKey:@"jenkinsWar"];
	[self willChangeValueForKey:@"prefix"];
	[self willChangeValueForKey:@"heapSize"];
	[self willChangeValueForKey:@"jenkinsHome"];
	self.launchdPlist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListMutableContainersAndLeaves format:NULL errorDescription:NULL];
	NSAssert(self.launchdPlist, @"launchdPlist is not supposed to be null");
	[self didChangeValueForKey:@"httpPort"];
	[self didChangeValueForKey:@"httpsPort"];
	[self didChangeValueForKey:@"ajpPort"];
	[self didChangeValueForKey:@"jenkinsWar"];
	[self didChangeValueForKey:@"prefix"];
	[self didChangeValueForKey:@"heapSize"];
	[self didChangeValueForKey:@"jenkinsHome"];
}

-(void)savePlist{
	// Create a pipe, and use it to funnel the plist data to the elevated process
	// Set up the pipe
	NSPipe *authPipe = [[NSPipe alloc] init];
	NSFileHandle *writeHandle = [authPipe fileHandleForWriting];
	FILE *bridge = fdopen([[authPipe fileHandleForReading] fileDescriptor], "r");
	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:self.launchdPlist format:NSPropertyListXMLFormat_v1_0 errorDescription:NULL];
	// Set up the task
	NSString *helperPath = [[self bundle] pathForResource:@"SecureWrite" ofType:nil];
	const char *argv[] = {[self.plistPath UTF8String], NULL};
	// Write on a thread, or we will deadlock for data length longer than 4096 bytes
	[NSThread detachNewThreadSelector:@selector(writeData:) toTarget:writeHandle withObject:plistData];
	// Spawn the privileged process
	AuthorizationExecuteWithPrivileges([[self.authorizationView authorization] authorizationRef], [helperPath UTF8String], kAuthorizationFlagDefaults, (char * const *)argv, &bridge);
	// The execution call above blocks until it's done, and the thread is done then.
	fclose(bridge);
	[writeHandle closeFile];
	[authPipe release];
}

-(BOOL)isUnlocked{
	return [self.authorizationView authorizationState] == SFAuthorizationViewUnlockedState;
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
		// Unload (and implicitly stop) the daemon in all cases, as the configuration may be changing
		NSArray *unloadArgs = [NSArray arrayWithObjects:@"unload", self.plistPath, nil];
		[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:unloadArgs];
		if(runJenkins){
			// Reload and start the daemon
			NSArray *loadArgs = [NSArray arrayWithObjects:@"load", self.plistPath, nil];
			NSArray *startArgs = [NSArray arrayWithObjects:@"start", self.plistName, nil];
			[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:loadArgs];
			[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:startArgs];
		}
	}
}

-(NSString *)getEnvironmentVariable:(NSString *)varName{
	NSDictionary *env = [self.launchdPlist objectForKey:@"EnvironmentVariables"];
	return [env valueForKey:varName];
}

-(void)setEnvironmentVariable:(NSString *)varName value:(id)value{
	NSMutableDictionary *env = [self.launchdPlist objectForKey:@"EnvironmentVariables"];
	[env setValue:value forKey:varName];
	[self savePlist];
}

// This method is tenuous and needs some major tests for all edge cases
-(NSString *)getLaunchOption:(NSString *)option{
	NSArray *args = [self.launchdPlist objectForKey:@"ProgramArguments"];
	// If the Program key is missing, args[0] is used as the executable
	NSInteger executableOffset = [self.launchdPlist objectForKey:@"Program"] == nil ? 1 : 0;
	NSInteger count = [args count];
	for(NSInteger i = executableOffset; i < count; ++i){
		// Trim the leading '-'
		NSString *arg = [[args objectAtIndex:i] substringFromIndex:1];
		// In three cases, the first character is a specific character
		if(([arg characterAtIndex:0] == '-' || [arg characterAtIndex:0] == 'D') && [arg rangeOfString:@"="].location != NSNotFound){
			// Winstone Argument and Java System Property
			NSRange equalRange = [arg rangeOfString:@"="];
			if(equalRange.location != NSNotFound){
				if([[arg substringToIndex:equalRange.location] isEqualToString:option]){
					return [[[arg substringFromIndex:(equalRange.location + 1)] retain] autorelease];
				}
			}
		}else if([arg characterAtIndex:0] == 'X'){
			// Java extension
			// Currently, this only supports -Xms# -Xmx# and -Xss#
			if([option isEqualToString:@"mx"] ||
			   [option isEqualToString:@"ms"] ||
			   [option isEqualToString:@"ss"]){
				return [arg substringFromIndex:3];
			}
		}else{
			// Something else, either a separated value or a simple flag
			if([arg isEqualToString:option]){
				if((i + 1 < count) && [[args objectAtIndex:(i + 1)] characterAtIndex:0] != '-'){
					return [args objectAtIndex:++i];
				}else{
					// simple flag
					return @"YES";
				}
			}
		}
	}
	return nil;
}

-(void)setLaunchOption:(NSString *)option value:(id<NSObject>)value type:(JCILaunchOption)optionType{
	NSMutableArray *args = [self.launchdPlist objectForKey:@"ProgramArguments"];
	// If the Program key is missing, args[0] is used as the executable
	NSInteger executableOffset = [self.launchdPlist objectForKey:@"Program"] == nil ? 0 : 1;
	NSInteger count = [args count];
	// Try to find the argument if defined
	for(NSInteger i = executableOffset; i < count; ++i){
		NSString *arg = [[args objectAtIndex:i] substringFromIndex:1];
		switch (optionType) {
			case JCIWinstoneLaunchOption:
			case JCIJavaSystemProperty:
				if(([arg characterAtIndex:0] == '-' || [arg characterAtIndex:0] == 'D') && 
				   [arg rangeOfString:@"="].location != NSNotFound){
					NSMutableString *newProperty = [arg mutableCopy];
					NSRange equalRange = [arg rangeOfString:@"="];
					if(equalRange.location != NSNotFound){
						if([[arg substringToIndex:equalRange.location] isEqualToString:option]){
							NSRange valueRange = NSMakeRange(equalRange.location + 1, ([arg length] - equalRange.location - 1));
							[newProperty replaceCharactersInRange:valueRange withString:[Jenkins convertToArgumentString:value]];
							[newProperty insertString:@"-" atIndex:0];
							[args replaceObjectAtIndex:i withObject:newProperty];
							[newProperty release];
							return;
						}
					}
				}
				break;
			case JCIJavaExtension:
				if(([arg characterAtIndex:1] == 'm' && ([arg characterAtIndex:2] == 's' || [arg characterAtIndex:2] == 'x')) ||
				   ([arg characterAtIndex:1] == 's' && [arg characterAtIndex:2] == 's')){
					NSMutableString *newProperty = [arg mutableCopy];
					NSRange valueRange = NSMakeRange(3, [newProperty length] - 3);
					[newProperty replaceCharactersInRange:valueRange withString:[Jenkins convertToArgumentString:value]];
					[newProperty insertString:@"-" atIndex:0];
					[args replaceObjectAtIndex:i withObject:newProperty];
					[newProperty release];
					return;
				}else{
					// Other Extensions (to be implemented later)
				}
				break;
			case JCISeparated:
				if([arg isEqualToString:option]){
					[args replaceObjectAtIndex:(i + 1) withObject:[Jenkins convertToArgumentString:value]];
					return;
				}
				break;
		}
	}
	// Not found, add it
	switch (optionType) {
		case JCIWinstoneLaunchOption:
			[args addObject:[NSString stringWithFormat:@"--%@=%@", option, [Jenkins convertToArgumentString:value]]];
			break;
		case JCIJavaSystemProperty:
			[args addObject:[NSString stringWithFormat:@"-D%@=%@", option, [Jenkins convertToArgumentString:value]]];
			break;
		case JCIJavaExtension:
			[args addObject:[NSString stringWithFormat:@"-X%@%@", option, [Jenkins convertToArgumentString:value]]];
			break;
		case JCISeparated:
			[args addObject:[NSString stringWithFormat:@"-%@ %@", option, [Jenkins convertToArgumentString:value]]];
			break;
	}
	[self savePlist];
}

// This would be nice to put in a category on NSString, NSNumber and possibly other classes, but PrefPanes run within
// System Preferences.app, and categories can collide.
+(NSString *)convertToArgumentString:(id<NSObject>)obj{
	if([obj isKindOfClass:[NSNumber class]] && strcmp([(NSNumber *)obj objCType], @encode(BOOL))){
		return ([(NSNumber *)obj boolValue] ? @"true" : @"false");
	}else{
		return [obj description];
	}
}

- (IBAction)toggleJenkins:(id)sender{
	self.running = !self.running;
}

- (IBAction)updateJenkins:(id)sender{
	// This will be an extensive task
}

#pragma mark - Bindings integration

-(NSString *)httpPort{
	return [self getLaunchOption:@"httpPort"];
}

-(void)setHttpPort:(NSString *)portNum{
	[self setLaunchOption:@"httpPort" value:portNum type:JCIWinstoneLaunchOption];
}

-(NSString *)httpsPort{
	return [self getLaunchOption:@"httpsPort"];
}

-(void)setHttpsPort:(NSString *)portNum{
	[self setLaunchOption:@"httpsPort" value:portNum type:JCIWinstoneLaunchOption];
}

-(NSString *)ajpPort{
	return [self getLaunchOption:@"ajp13Port"];
}

-(void)setAjpPort:(NSString *)portNum{
	[self setLaunchOption:@"ajp13Port" value:portNum type:JCIWinstoneLaunchOption];
}

-(NSString *)jenkinsWar{
	return [self getLaunchOption:@"jar"];
}

-(void)setJenkinsWar:(NSString *)warPath{
	[self setLaunchOption:@"jar" value:warPath type:JCISeparated];
}

-(NSString *)prefix{
	return [self getLaunchOption:@"prefix"];
}

-(void)setPrefix:(NSString *)prefix{
	[self setLaunchOption:@"prefix" value:prefix type:JCIWinstoneLaunchOption];
}

-(NSString *)heapSize{
	return [self getLaunchOption:@"mx"];
}

-(void)setHeapSize:(NSString *)heapSize{
	[self setLaunchOption:@"mx" value:heapSize type:JCIJavaExtension];
}

-(NSString *)jenkinsHome{
	return [self getEnvironmentVariable:@"JENKINS_HOME"];
}

-(void)setJenkinsHome:(NSString *)homePath{
	[self setEnvironmentVariable:@"JENKINS_HOME" value:homePath];
}

#pragma mark - SFAuthorizationView Delegate

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view {
    self.uiEnabled = [self isUnlocked];
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view {
    self.uiEnabled = [self isUnlocked];
}

@end
