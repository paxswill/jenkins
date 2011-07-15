//
//  JCIPrefPane.m
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import "JCIPrefPane.h"
#import <objc/runtime.h>

static const NSSet *javaOptions;

@interface JCIPrefPane()
+(NSString *)convertToArgumentString:(NSDictionary *)argumentDict;
+(NSMutableDictionary *)parseJavaArgument:(NSString *)arg;
-(void)updateVariablesDictionaryArray;
-(void)updateArgumentsDictionaryArray;
-(void)setHeaderIndices;
@end

@implementation JCIPrefPane

@synthesize plist;
@synthesize uiEnabled;

@synthesize startButton;
@synthesize updateButton;
@synthesize autostart;
@synthesize authorizationView;
@synthesize variables;
@synthesize jenkinsArgs;
@synthesize javaArgs;

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

+(void)initialize{
	// Skip the "Show something and exit" options
	javaOptions = [[NSSet alloc] initWithObjects:
				   @"-jar ",
				   @"-client",
				   @"-server",
				   @"-classpath "
				   @"-cp ",
				   @"-d32",
				   @"-d64",
				   @"-enableassertions",
				   @"-ea",
				   @"-disableassertions",
				   @"-da",
				   @"-enablesystemassertions",
				   @"-esa",
				   @"-disablesystemassertions",
				   @"-dsa",
				   @"-jar",
				   @"-verbose",
				   @"-verbose:gc",
				   @"-verbose:jni",
				   @"-showversion",
				   @"-Xint",
				   @"-Xbatch",
				   @"-Xdebug",
				   @"-Xcheck:jni",
				   @"-Xfuture",
				   @"-Xnoclassgc",
				   @"-Xincgc",
				   @"-Xprof",
				   @"-Xrs",
				   @"-XX:+UseAltSigs",
				   nil];
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
		[self updateVariablesDictionaryArray];
		[self updateArgumentsDictionaryArray];
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
	self.startButton.title = self.plist.running ? @"Stop" : @"Start";
	// Set autostart checkbox
	if(![self.plist.disabled boolValue] && [self.plist.runAtLoad boolValue]){
		[self.autostart setState:NSOnState];
	}else{
		[self.autostart setState:NSOffState];
	}
}

-(void)updateVariablesDictionaryArray{
	NSMutableArray *vars = [[NSMutableArray alloc] initWithCapacity:[self.plist.environmentVariables count]];
	for(NSString *key in self.plist.environmentVariables){
		NSMutableDictionary *varDict = [NSMutableDictionary dictionaryWithCapacity:2];
		[varDict setValue:key forKey:@"option"];
		[varDict setValue:[self.plist.environmentVariables valueForKey:key] forKey:@"value"];
		[vars addObject:varDict];
	}
	self.variables = [vars autorelease];
	[self setHeaderIndices];
}

-(void)updateArgumentsDictionaryArray{
	self.jenkinsArgs = [NSMutableArray array];
	self.javaArgs = [NSMutableArray array];
	NSArray *rawArgs = [self.plist.programArguments copy];
	for(int i = (int)[rawArgs count] - 1; i >= 0; --i){
		NSString *argument = [rawArgs objectAtIndex:i];
		id<NSObject> value = [NSNull null];
		if([argument characterAtIndex:0] != '-'){
			// Go back for the argument
			value = argument;
			argument = [[rawArgs objectAtIndex:--i] stringByAppendingString:@" "];
		}
		NSMutableDictionary *argDict = [JCIPrefPane parseJavaArgument:argument];
		if(argDict){
			if(value != [NSNull null]){
				[argDict setValue:value forKey:@"Value"];
			}
			[self.javaArgs addObject:argDict];
		}else{
			if([argument rangeOfString:@"="].location != NSNotFound){
				// Split argument
				NSRange equalRange = [argument rangeOfString:@"="];
				value = [argument substringFromIndex:(equalRange.location + 1)];
				argument = [argument substringToIndex:(equalRange.location + 1)];
			}
			argDict = [NSMutableDictionary dictionaryWithCapacity:2];
			[argDict setValue:argument forKey:@"option"];
			[argDict setValue:value forKey:@"value"];
			[self.jenkinsArgs addObject:argDict];
		}
	}
	[self setHeaderIndices];
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

+(NSMutableDictionary *)parseJavaArgument:(NSString *)arg{
	if([javaOptions containsObject:arg]){
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNull null], @"value", arg, @"option", nil];
	}else if([arg rangeOfString:@"-agentlib:"].location == 0){
		NSString *option = [arg substringToIndex:9];
		NSString *value = [arg substringFromIndex:9];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-agentpath:"].location == 0){
		NSString *option = [arg substringToIndex:10];
		NSString *value = [arg substringFromIndex:10];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if(([arg rangeOfString:@"-D"].location == 0) && ([arg rangeOfString:@"="].location != NSNotFound)){
		NSRange equalRange = [arg rangeOfString:@"="];
		NSString *option = [arg substringToIndex:(equalRange.location + 1)];
		NSString *value = [arg substringFromIndex:(equalRange.location + 1)];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-enableassertions:"].location == 0){
		NSString *option = [arg substringToIndex:17];
		NSString *value = [arg substringFromIndex:17];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-ea:"].location == 0){
		NSString *option = [arg substringToIndex:3];
		NSString *value = [arg substringFromIndex:3];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-disableassertions:"].location == 0){
		NSString *option = [arg substringToIndex:19];
		NSString *value = [arg substringFromIndex:19];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-da:"].location == 0){
		NSString *option = [arg substringToIndex:3];
		NSString *value = [arg substringFromIndex:3];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-javaagent:"].location == 0){
		NSString *option = [arg substringToIndex:11];
		NSString *value = [arg substringFromIndex:11];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-verbose:"].location == 0){
		NSString *option = [arg substringToIndex:9];
		NSString *value = [arg substringFromIndex:9];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"−Xbootclasspath:"].location == 0){
		NSString *option = [arg substringToIndex:16];
		NSString *value = [arg substringFromIndex:16];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"−Xbootclasspath/a:"].location == 0){
		NSString *option = [arg substringToIndex:18];
		NSString *value = [arg substringFromIndex:18];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"−Xbootclasspath/p:"].location == 0){
		NSString *option = [arg substringToIndex:18];
		NSString *value = [arg substringFromIndex:18];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-Xloggc:"].location == 0){
		NSString *option = [arg substringToIndex:8];
		NSString *value = [arg substringFromIndex:8];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-Xms"].location == 0){
		NSString *option = [arg substringToIndex:4];
		NSString *value = [arg substringFromIndex:4];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-Xmx"].location == 0){
		NSString *option = [arg substringToIndex:4];
		NSString *value = [arg substringFromIndex:4];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-Xrunhprof:"].location == 0){
		NSString *option = [arg substringToIndex:11];
		NSString *value = [arg substringFromIndex:11];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else if([arg rangeOfString:@"-Xss"].location == 0){
		NSString *option = [arg substringToIndex:4];
		NSString *value = [arg substringFromIndex:4];
		return [NSMutableDictionary dictionaryWithObjectsAndKeys:option, @"option", value, @"value", nil];
	}else{
		return nil;
	}
}

// This would be nice to put in a category on NSString, NSNumber and possibly other classes, but PrefPanes run within
// System Preferences.app, and categories can collide.
+(NSString *)convertToArgumentString:(NSDictionary *)argumentDict{
	id<NSObject> value = [argumentDict valueForKey:@"value"];
	if(value != [NSNull null]){
		return [[argumentDict valueForKey:@"option"] stringByAppendingString:(NSString *)value];
	}else{
		return [argumentDict valueForKey:@"option"];
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
	if([self.variables count] > 0){
		count += [self.variables count];
		count += 1;
	}
	if([self.javaArgs count] > 0){
		count += [self.javaArgs count];
		count += 1;
	}
	if([self.jenkinsArgs count] > 0){
		count += [self.jenkinsArgs count];
		count += 1;
	}
	return count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex{
	if(rowIndex == environmentHeaderIndex && [[aTableColumn identifier] isEqualToString:@"option"]){
		return @"Environment Variables";
	}else if(rowIndex == javaHeaderIndex && [[aTableColumn identifier] isEqualToString:@"option"]){
		return @"Java Options";
	}else if(rowIndex == jenkinsHeaderIndex && [[aTableColumn identifier] isEqualToString:@"option"]){
		return @"Jenkins Options";
	}else{
		int offset = 1;
		if(rowIndex < javaHeaderIndex && rowIndex > environmentHeaderIndex){
			// Environment Variable
			return [[self.variables objectAtIndex:(rowIndex - offset)] valueForKey:[aTableColumn identifier]];
		}else if(rowIndex < jenkinsHeaderIndex && rowIndex > javaHeaderIndex){
			// Java
			offset += [self.variables count] > 0 ? [self.variables count] + 1 : 0;
			return [[self.javaArgs objectAtIndex:(rowIndex - offset)] valueForKey:[aTableColumn identifier]];
		}else if(rowIndex > jenkinsHeaderIndex){
			// Jenkins
			offset += [self.variables count] > 0 ? [self.variables count] + 1 : 0;
			offset += [self.javaArgs count] > 0 ? [self.javaArgs count] + 1 : 0;
			return [[self.jenkinsArgs objectAtIndex:(rowIndex - offset)] valueForKey:[aTableColumn identifier]];
		}else{
			return nil;
		}
	}
}

#pragma mark - NSTableViewDelegate

-(void)setHeaderIndices{
	int offset = 0;
	// Env
	if([self.variables count] > 0){
		environmentHeaderIndex = 0;
		offset += [self.variables count] + 1;
	}else{
		environmentHeaderIndex = INT_MAX;
	}
	// Java
	if([self.javaArgs count] > 0){
		javaHeaderIndex = offset;
		offset += [self.javaArgs count] + 1;
	}else{
		javaHeaderIndex = INT_MAX;
	}
	// Jenkins
	if([self.jenkinsArgs count] > 0){
		jenkinsHeaderIndex = offset;
		offset += [self.jenkinsArgs count] + 1;
	}else{
		jenkinsHeaderIndex = INT_MAX;
	}
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row{
	return row == environmentHeaderIndex || row == javaHeaderIndex || row == jenkinsHeaderIndex;
}

#pragma mark - SFAuthorizationView Delegate

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view {
    self.uiEnabled = [self isUnlocked];
	self.startButton.title = self.plist.running ? @"Stop" : @"Start";
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
