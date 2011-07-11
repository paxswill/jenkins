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

- (void)mainViewDidLoad{
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
	// Se the start/stop button
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
	self.launchdPlist = [NSMutableDictionary dictionaryWithContentsOfFile:self.plistPath];
	NSAssert(self.launchdPlist, @"launchdPlist is not supposed to be null");
}

-(void)savePlist{
	
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
	 Search for the job. THe format for each line is
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
		// Unload (and implicitly stop) the daemon in all cases, as the configuartion may be changing
		NSArray *unloadArgs = [NSArray arrayWithObjects:@"unload", [self.plistPath stringByAppendingString:self.plistName], nil];
		[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:unloadArgs];
		if(runJenkins){
			// Reload and start the daemon
			NSArray *loadArgs = [NSArray arrayWithObjects:@"load", [self.plistPath stringByAppendingString:self.plistName], nil];
			NSArray *startArgs = [NSArray arrayWithObjects:@"start", self.plistName, nil];
			[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:loadArgs];
			[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:startArgs];
		}
	}
}

- (IBAction)startJenkins:(id)sender{
	
}

- (IBAction)updateJenkins:(id)sender{
	
}

@end
