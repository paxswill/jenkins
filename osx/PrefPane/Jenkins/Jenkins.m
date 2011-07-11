//
//  Jenkins.m
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import "Jenkins.h"

@interface Jenkins()
-(void)updatePlist;
-(void)loadPlist;
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

- (void)mainViewDidLoad{
	// Find the Jenkins launchd plist
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES);
	NSString *libraryPath = [libraryPaths count] > 0 ? [[libraryPaths objectAtIndex:0] retain] 
	                                                 : @"/Library/LaunchDaemons/";
	[libraryPaths release];
	self.plistName = @"org.jenkins-ci.plist";
	self.plistPath = [libraryPath stringByAppendingString:self.plistName];
	[libraryPath release];
	[self updatePlist];
	
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
	[self updatePlist];
}

-(void)updatePlist{
	self.launchdPlist = [NSMutableDictionary dictionaryWithContentsOfFile:self.plistPath];
	NSAssert(self.launchdPlist, @"launchdPlist is not supposed to be null");
}

-(BOOL)isRunning{
	// Get launchd listing
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
	// Search for the job
	for(NSString *line in rawLines){
		NSArray *lineData = [line componentsSeparatedByString:@"\t"];
		if([[lineData objectAtIndex:2] isEqualToString:self.plistName]){
			if([[lineData objectAtIndex:0] isEqualToString:@"-"]){
				return NO;
			}else{
				return YES;
			}
		}
	}
	return NO;
}

-(void)setRunning:(BOOL)runJenkins{
	if(self.running != runJenkins){
		NSArray *unloadArgs = [NSArray arrayWithObjects:@"unload", [self.plistPath stringByAppendingString:self.plistName], nil];
		NSArray *loadArgs = [NSArray arrayWithObjects:@"load", [self.plistPath stringByAppendingString:self.plistName], nil];
		NSArray *startArgs = [NSArray arrayWithObjects:@"start", self.plistName, nil];
		[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:unloadArgs];
		[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:loadArgs];
		[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:startArgs];
	}
}

- (IBAction)startJenkins:(id)sender{
	
}

- (IBAction)updateJenkins:(id)sender{
	
}

@end
