//
//  JCIComboSource.m
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/15/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

#import "JCIComboSource.h"
#import "JCIPrefPane.h"
#import <objc/runtime.h>

static const NSArray *javaArgs;
static const NSArray *jenkinsArgs;
static const NSArray *environmentVariables;

@interface JCIComboSource()
@property (nonatomic, assign, readwrite) JCIOptionType type;
@end

@implementation JCIComboSource

@synthesize type;

+(void)load{
	// 10.6 formalized a lot of previously informal protocols
	// Here we add the NSComboBoxCell data source protocol if we're running 10.6
	SInt32 majorVersion;
	SInt32 minorVersion;
	Gestalt(gestaltSystemVersionMajor, &majorVersion);
	Gestalt(gestaltSystemVersionMinor, &minorVersion);
	if(majorVersion >= 10 && minorVersion >= 6){
		Protocol *dataSourceProtocol = objc_getProtocol("NSComboBoxCellDataSource");
		class_addProtocol([JCIComboSource class], dataSourceProtocol);
	}
}

+(void)initialize{
	// These are sorted arrays
	javaArgs = [[NSArray alloc] initWithObjects:
				@"-client",
				@"-server",
				@"-agentlib:",
				@"-agentpath",
				@"-classpath ",
				@"-cp ",
				@"-D",
				@"-d32",
				@"-d64",
				@"-enableassertions",
				@"-enableassertions:",
				@"-ea",
				@"-ea:",
				@"-disableassertions",
				@"-disableassertions:",
				@"-da",
				@"-da:",
				@"-enablesystemassertions",
				@"-enablesystemassertions:",
				@"-esa",
				@"-esa:",
				@"-disablesystemassertions",
				@"-disablesystemassertions:",
				@"-dsa",
				@"-dsa:",
				@"-jar ",
				@"-javaagent:",
				@"-verbose",
				@"-verbose:",
				@"-verbose:gc",
				@"-verbose:jni",
				@"-showversion",
				@"-Xint",
				@"-Xbatch",
				@"-Xdebug",
				@"-Xbootclasspath:",
				@"-Xbootclasspath/a:",
				@"-Xbootclasspath/p:",
				@"-Xcheck:jni",
				@"-Xfuture",
				@"-Xnoclassgc",
				@"-Xincgc",
				@"-Xloggc:",
				@"-Xms",
				@"-Xmx",
				@"-Xprof",
				@"-Xrunhprof:",
				@"-Xrs",
				@"-Xss",
				@"-XX:+UseAltSigs",
				nil];
	jenkinsArgs = [[NSArray alloc] initWithObjects:
				   @"--accessLoggerClassName=",
				   @"--ajp13ListenAddress=",
				   @"--ajp13Port=",
				   @"--clusterClassName=",
				   @"--clusterNodes=",
				   @"--commonLibFolder=",
				   @"--config=",
				   @"--controlPort=",
				   @"--debug=",
				   @"--directoryListings=",
				   @"--handlerCountMax=",
				   @"--handlerCountMaxIdle=",
				   @"--handlerCountStartup=",
				   @"--httpDoHostnameLookups=",
				   @"--httpListenAddress=",
				   @"--httpPort=",
				   @"--httpsDoHostnameLookups=",
				   @"--httpsKeyManagerType=",
				   @"--httpsKeyStore=",
				   @"--httpsKeyStorePassword=",
				   @"--httpsListenAddress=",
				   @"--httpsPort=",
				   @"--invokerPrefix=",
				   @"--javaHome=",
				   @"--logThrowingLineNo=",
				   @"--logThrowingThread=",
				   @"--logfile=",
				   @"--preferredClassLoader=",
				   @"--prefix=",
				   @"--simpleAccessLogger.file=",
				   @"--simpleAccessLogger.format=",
				   @"--simulateModUniqueId=",
				   @"--toolsJar=",
				   @"--useCluster=",
				   @"--useInvoker=",
				   @"--useJasper=",
				   @"--useSavedSessions=",
				   @"--useServletReloading=",
				   nil];
	environmentVariables = [[NSArray alloc] initWithObjects:
							@"JENKINS_HOME",
							nil];
}

-(id)initWithType:(JCIOptionType)optionType{
	if((self = [super init])){
		self.type = optionType;
	}
	return self;
}

#pragma mark - NSComboBoxCellDataSource

- (NSUInteger)comboBoxCell:(NSComboBoxCell *)aComboBoxCell indexOfItemWithStringValue:(NSString *)aString{
	switch (self.type) {
		case JCIEnvironmentVariable:
			return [environmentVariables indexOfObject:aString];
		case JCIJavaArgument:
			return [javaArgs indexOfObject:aString];
		case JCIJenkinsArgument:
			return [jenkinsArgs indexOfObject:aString];
		default:
			return NSNotFound;
	}
}

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(NSInteger)index{
	switch (type) {
		case JCIEnvironmentVariable:
			return [environmentVariables objectAtIndex:index];
		case JCIJavaArgument:
			return [javaArgs objectAtIndex:index];
		case JCIJenkinsArgument:
			return [jenkinsArgs objectAtIndex:index];
		default:
			return nil;
	}
}

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell{
	switch (type) {
		case JCIEnvironmentVariable:
			return [environmentVariables count];
		case JCIJavaArgument:
			return [javaArgs count];
		case JCIJenkinsArgument:
			return [jenkinsArgs count];
		default:
			return 0;
	}
}

@end
