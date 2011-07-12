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
@end

@implementation Jenkins

@synthesize launchdPlist;
@synthesize plistPath;
@synthesize plistName;
@synthesize uiEnabled;

@synthesize httpPortField;
@synthesize httpsPortField;
@synthesize ajpPortField;
@synthesize jenkinsWarField;
@synthesize prefixField;
@synthesize heapSizeField;
@synthesize jenkinsHomeField;
@synthesize otherField;
@synthesize startButton;
@synthesize updateButton;
@synthesize autostart;
@synthesize authorizationView;

- (void)mainViewDidLoad{
	// Setup authorization
	
	// Find the Jenkins launchd plist
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES);
	NSString *libraryPath = [libraryPaths count] > 0 ? [[libraryPaths objectAtIndex:0] retain] 
	                                                 : @"/Library/LaunchDaemons/";
	[libraryPaths release];
	self.plistName = @"org.jenkins-ci.plist";
	self.plistPath = [libraryPath stringByAppendingString:self.plistName];
	[libraryPath release];
	[self loadPlist];
	
	// Start watching the various keys
	[self addObserver:self forKeyPath:@"httpPortField" options:NSKeyValueObservingOptionNew context:NULL];
	[self addObserver:self forKeyPath:@"httpsPortField" options:NSKeyValueObservingOptionNew context:NULL];
	[self addObserver:self forKeyPath:@"ajpPortField" options:NSKeyValueObservingOptionNew context:NULL];
	[self addObserver:self forKeyPath:@"jenkinsWarField" options:NSKeyValueObservingOptionNew context:NULL];
	[self addObserver:self forKeyPath:@"prefixField" options:NSKeyValueObservingOptionNew context:NULL];
	[self addObserver:self forKeyPath:@"heapSizeField" options:NSKeyValueObservingOptionNew context:NULL];
	[self addObserver:self forKeyPath:@"jenkinsHomeField" options:NSKeyValueObservingOptionNew context:NULL];
	[self addObserver:self forKeyPath:@"otherField" options:NSKeyValueObservingOptionNew context:NULL];
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
	NSData *plistData = [NSData dataWithContentsOfFile:self.plistPath];
	self.launchdPlist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListMutableContainersAndLeaves format:NULL errorDescription:NULL];
	NSAssert(self.launchdPlist, @"launchdPlist is not supposed to be null");
}

-(void)savePlist{
	[self.launchdPlist writeToFile:self.plistPath atomically:YES];
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
		NSArray *lineData = [line componentsSeparatedByString:@"\t"];
		if([[lineData objectAtIndex:2] isEqualToString:self.plistName]){
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

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
	if(object != self){
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	id newValue = [change objectForKey:NSKeyValueChangeNewKey];
	if([keyPath isEqualToString:@"httpPortField"]){
		
	}else if([keyPath isEqualToString:@"httpsPortField"]){
		
	}else if([keyPath isEqualToString:@"ajpPortField"]){
		
	}else if([keyPath isEqualToString:@"jenkinsWarField"]){
		
	}else if([keyPath isEqualToString:@"prefixField"]){
		
	}else if([keyPath isEqualToString:@"heapSizeField"]){
		
	}else if([keyPath isEqualToString:@"jenkinsHomeField"]){
		NSMutableDictionary *env = [self.launchdPlist objectForKey:@"EnvironmentVariables"];
		[env setValue:newValue forKey:@"JENKINS_HOME"];
	}else if([keyPath isEqualToString:@"otherField"]){
		
	}else{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

-(NSString *)getEnvironmentVariable:(NSString *)varName{
	NSDictionary *env = [self.launchdPlist objectForKey:@"EnvironmentVariables"];
	return [env valueForKey:varName];
}

-(void)setEnvironmentVariable:(NSString *)varName value:(id)value{
	NSMutableDictionary *env = [self.launchdPlist objectForKey:@"EnvironmentVariables"];
	[env setValue:value forKey:varName];
}

// This method is tenuous and needs some major tests for all edge cases
-(id<NSObject>)getLaunchOption:(NSString *)option{
	// option is the name of the option 
	NSArray *args = [self.launchdPlist objectForKey:@"ProgramArguments"];
	// If the Program key is missing, args[0] is used as the executable
	NSInteger executableOffset = [self.launchdPlist objectForKey:@"Program"] == nil ? 0 : 1;
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
			if([arg characterAtIndex:1] == 'm'){
				if([arg characterAtIndex:2] == 's' || [arg characterAtIndex:2] == 'x'){
					return [NSNumber numberWithInteger:[[arg substringFromIndex:3] integerValue]];
				}
			}else if([arg characterAtIndex:1] == 's' && [arg characterAtIndex:2] == 's'){
				return [NSNumber numberWithInteger:[[arg substringFromIndex:3] integerValue]];
			}else{
				// Other Extensions (to be implemented later)
			}
		}else{
			// Something else, either a seperated value or a simple flag
			if([arg isEqualToString:option]){
				// Simple flag
				return [NSNumber numberWithBool:YES];
			}else if((i + 1 < count) && [[args objectAtIndex:(i + 1)] characterAtIndex:0] != '-'){
				return [args objectAtIndex:++i];
			}
		}
	}
	return nil;
}

- (IBAction)toggleJenkins:(id)sender{
	self.running = !self.running;
}

- (IBAction)updateJenkins:(id)sender{
	// This will be an extensive task
}

@end
