//
//  Jenkins.m
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import "Jenkins.h"

@interface Jenkins()
+(NSString *)convertToArgumentString:(id<NSObject>)obj;
@end

@implementation Jenkins

@synthesize plist;
@synthesize uiEnabled;

@synthesize otherFlags;
@synthesize startButton;
@synthesize updateButton;
@synthesize autostart;
@synthesize authorizationView;

-(id)initWithBundle:(NSBundle *)bundle{
	if((self = [super initWithBundle:bundle])){
		// Find the Jenkins launchd plist
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES);
		NSString *libraryPath = [libraryPaths count] > 0 ? [[libraryPaths objectAtIndex:0] retain] 
		: @"/Library";
		[libraryPaths release];
		libraryPath = [libraryPath stringByAppendingString:@"/LaunchDaemons/"];
		self.plist = [[[JCILaunchdPlist alloc] initWithPath:[libraryPath stringByAppendingString:@"org.jenkins-ci.plist"]] autorelease];
		[libraryPath release];
	}
	return self;
}

- (void)mainViewDidLoad{
	// Setup authorization
	[self.authorizationView setAutoupdate:YES];
	AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &items};
	[self.authorizationView setAuthorizationRights:&rights];
	self.authorizationView.delegate = self;
	self.uiEnabled = [self isUnlocked];
	self.plist.authorization = self.authorizationView.authorization;
}

-(void)willSelect{
	// Set the start/stop button
	if(self.plist.running){
		self.startButton.title = @"Stop";
	}else{
		self.startButton.title = @"Start";
	}
	// Set autostart checkbox
	if(![self.plist.disabled boolValue] && [self.plist.runAtLoad boolValue]){
		[self.autostart setState:NSOnState];
	}else{
		[self.autostart setState:NSOffState];
	}
}

-(BOOL)isUnlocked{
	return [self.authorizationView authorizationState] == SFAuthorizationViewUnlockedState;
}


-(NSString *)getEnvironmentVariable:(NSString *)varName{
	return [self.plist.environmentVariables valueForKey:varName];
}

-(void)setEnvironmentVariable:(NSString *)varName value:(id)value{
	[self.plist.environmentVariables setValue:value forKey:varName];
	[self.plist save];
}

// This method is tenuous and needs some major tests for all edge cases
-(NSString *)getLaunchOption:(NSString *)option{
	NSArray *args = self.plist.programArguments;
	NSInteger count = [args count];
	for(NSInteger i = 0; i < count; ++i){
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
	NSMutableArray *args = self.plist.programArguments;
	NSInteger count = [args count];
	// Try to find the argument if defined
	for(NSInteger i = 0; i < count; ++i){
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
	[self.plist save];
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
	self.plist.running = !self.plist.running;
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

- (void)authorizationViewCreatedAuthorization:(SFAuthorizationView *)view{
	self.plist.authorization = view.authorization;
}

- (void)authorizationViewReleasedAuthorization:(SFAuthorizationView *)view{
	self.plist.authorization = nil;
}

@end
