//
//  JCIPrefPane.m
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import "JCIPrefPane.h"
#import <objc/runtime.h>

@interface JCIPrefPane()
+(NSString *)convertToArgumentString:(id<NSObject>)obj;
-(NSMutableArray *)variablesDictionaryArray;
-(NSMutableArray *)argumentsDictionaryArray;
@end

@implementation JCIPrefPane

@synthesize plist;
@synthesize uiEnabled;

@synthesize startButton;
@synthesize updateButton;
@synthesize autostart;
@synthesize authorizationView;
@synthesize variables;
@synthesize arguments;

+(void)load{
	SInt32 majorVersion;
	SInt32 minorVersion;
	Gestalt(gestaltSystemVersionMajor, &majorVersion);
	Gestalt(gestaltSystemVersionMinor, &minorVersion);
	if(majorVersion >= 10 && minorVersion >= 6){
		Protocol *delegateProtocol = objc_getProtocol("NSTableViewDelegate");
		Protocol *dataSourceProtocol = objc_getProtocol("NSTableViewDataSource");
		class_addProtocol([JCIPrefPane class], delegateProtocol);
		class_addProtocol([JCIPrefPane class], dataSourceProtocol);
	}
}

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
		self.variables = [self variablesDictionaryArray];
		self.arguments = [self argumentsDictionaryArray];
		self.plist.helperPath = [[self bundle] pathForResource:@"SecureWrite" ofType:nil];
		[self.plist addObserver:self forKeyPath:@"environmentVariables" options:  NSKeyValueObservingOptionNew context:NULL];
		[self.plist addObserver:self forKeyPath:@"programArguments" options:  NSKeyValueObservingOptionNew context:NULL];
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

-(NSMutableArray *)variablesDictionaryArray{
	NSMutableArray *vars = [[NSMutableArray alloc] initWithCapacity:[self.plist.environmentVariables count]];
	for(NSString *key in self.plist.environmentVariables){
		NSMutableDictionary *varDict = [NSMutableDictionary dictionaryWithCapacity:2];
		[varDict setValue:key forKey:@"option"];
		[varDict setValue:[self.plist.environmentVariables valueForKey:key] forKey:@"value"];
		[vars addObject:varDict];
	}
	return [vars autorelease];
}

-(NSMutableArray *)argumentsDictionaryArray{
	NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:[self.plist.programArguments count]];
	NSArray *rawArgs = [self.plist.programArguments copy];
	for(int i = (int)[rawArgs count] - 1; i >= 0; --i){
		NSString *argument = [rawArgs objectAtIndex:i];
		id<NSObject> value = [NSNull null];
		if([argument characterAtIndex:0] != '-'){
			// Go back for the argument
			value = argument;
			argument = [rawArgs objectAtIndex:--i];
			
		}else if([argument rangeOfString:@"="].location != NSNotFound){
			// Split argument
			NSRange equalRange = [argument rangeOfString:@"="];
			value = [argument substringFromIndex:(equalRange.location + 1)];
			argument = [argument substringToIndex:(equalRange.location + 1)];
		}
		//else: the argument is a simple flag
		NSMutableDictionary *argDict = [NSMutableDictionary dictionaryWithCapacity:2];
		[argDict setValue:argument forKey:@"option"];
		[argDict setValue:value forKey:@"value"];
		[args addObject:argDict];
	}
	return [args autorelease];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
	if([keyPath isEqualToString:@"environmentVariables"] && object == self){
		
	}else if([keyPath isEqualToString:@"programArguments"] && object == self){
		
	}else{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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
							[newProperty replaceCharactersInRange:valueRange withString:[JCIPrefPane convertToArgumentString:value]];
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
					[newProperty replaceCharactersInRange:valueRange withString:[JCIPrefPane convertToArgumentString:value]];
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
					[args replaceObjectAtIndex:(i + 1) withObject:[JCIPrefPane convertToArgumentString:value]];
					return;
				}
				break;
		}
	}
	// Not found, add it
	switch (optionType) {
		case JCIWinstoneLaunchOption:
			[args addObject:[NSString stringWithFormat:@"--%@=%@", option, [JCIPrefPane convertToArgumentString:value]]];
			break;
		case JCIJavaSystemProperty:
			[args addObject:[NSString stringWithFormat:@"-D%@=%@", option, [JCIPrefPane convertToArgumentString:value]]];
			break;
		case JCIJavaExtension:
			[args addObject:[NSString stringWithFormat:@"-X%@%@", option, [JCIPrefPane convertToArgumentString:value]]];
			break;
		case JCISeparated:
			[args addObject:[NSString stringWithFormat:@"-%@ %@", option, [JCIPrefPane convertToArgumentString:value]]];
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

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView{
	NSInteger count = 0;
	// If there are to be rows in that section, add an extra row for a header
	if([self.plist.environmentVariables count] > 0){
		count += [self.variables count];
		count += 1;
	}
	if([self.plist.programArguments count] > 0){
		count += [self.arguments count];
		count += 1;
	}
	return count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex{
	NSInteger varCount = (NSInteger)[self.variables count];
	NSInteger argCount = (NSInteger)[self.arguments count];
	if(varCount > 0 && rowIndex == 0 && [[aTableColumn identifier] isEqualToString:@"option"]){
		return @"Environment Variables";
	}else if((varCount == 0 && argCount > 0 && rowIndex == 0) || (varCount > 0 && argCount > 0 && rowIndex == (varCount + 1)) && [[aTableColumn identifier] isEqualToString:@"option"]){
		return @"Launch Arguments";
	}else if(rowIndex < (varCount + 1) && rowIndex > 0){
		// Environment Variable Data row
		return [[self.variables objectAtIndex:(rowIndex - 1)] valueForKey:[aTableColumn identifier]];
	}else if(rowIndex > (varCount + 1)){
		// Arguments data row
		return [[self.arguments objectAtIndex:(rowIndex - varCount - 2)] valueForKey:[aTableColumn identifier]];
	}else{
		return nil;
	}
}

#pragma mark - NSTableViewDelegate

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row{
	if(row == 0 || ([self.variables count] > 0 && [self.arguments count] > 0 && (row == (NSInteger)[self.variables count] + 1))){
		return YES;
	}else{
		return NO;
	}
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
