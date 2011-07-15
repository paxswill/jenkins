//
//  JCIPrefPane.h
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import "JCILaunchdPlist.h"

typedef enum{
	JCIWinstoneLaunchOption = 0,    // --Option=Value
	JCIJavaSystemProperty,      // -DOption=value
	JCIJavaExtension,           // -XOptionValue
	JCISeparated,               // -Option [Value]
} JCILaunchOption;

@interface JCIPrefPane : NSPreferencePane{
	JCILaunchdPlist *plist;
	BOOL uiEnabled;

	NSButton *startButton;
	NSButton *updateButton;
	NSButton *autostart;
	SFAuthorizationView *authorizationView;
	NSMutableArray *variables;
	NSMutableArray *arguments;
}
@property (nonatomic, readwrite, retain) JCILaunchdPlist *plist;
@property (readwrite, assign) BOOL uiEnabled;

@property (nonatomic, readwrite, assign) IBOutlet NSButton *startButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *updateButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *autostart;
@property (nonatomic, readwrite, assign) IBOutlet SFAuthorizationView *authorizationView;
@property (nonatomic, readwrite, retain) NSMutableArray *variables;
@property (nonatomic, readwrite, retain) NSMutableArray *arguments;

- (void)mainViewDidLoad;

- (BOOL)isUnlocked;
-(NSString *)getEnvironmentVariable:(NSString *)varName;
-(void)setEnvironmentVariable:(NSString *)varName value:(id)value;
-(NSString *)getLaunchOption:(NSString *)option;
-(void)setLaunchOption:(NSString *)option value:(id<NSObject>)value type:(JCILaunchOption)optionType;
- (IBAction)toggleJenkins:(id)sender;
- (IBAction)updateJenkins:(id)sender;

@end
