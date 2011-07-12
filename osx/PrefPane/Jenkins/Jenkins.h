//
//  Jenkins.h
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>

typedef enum{
	JCIWinstoneLaunchOption = 0,    // --Option=Value
	JCIJavaSystemProperty,      // -DOption=value
	JCIJavaExtension,           // -XOptionValue
	JCISeparated,               // -Option [Value]
} JCILaunchOption;

@interface Jenkins : NSPreferencePane
@property (nonatomic, readwrite, retain) NSMutableDictionary *launchdPlist;
@property (nonatomic, readwrite, retain) NSString *plistPath;
@property (nonatomic, readwrite, retain) NSString *plistName;
@property (nonatomic, readwrite, assign, getter = isRunning) BOOL running;
@property (readwrite, assign) BOOL uiEnabled;

@property (nonatomic, readwrite, retain) NSString *httpPort;
@property (nonatomic, readwrite, retain) NSString *httpsPort;
@property (nonatomic, readwrite, retain) NSString *ajpPort;
@property (nonatomic, readwrite, retain) NSString *jenkinsWar;
@property (nonatomic, readwrite, retain) NSString *prefix;
@property (nonatomic, readwrite, retain) NSString *heapSize;
@property (nonatomic, readwrite, retain) NSString *jenkinsHome;
@property (nonatomic, readwrite, retain) NSString *otherFlags;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *startButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *updateButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *autostart;
@property (nonatomic, readwrite, assign) IBOutlet SFAuthorizationView *authorizationView;


- (void)mainViewDidLoad;

- (BOOL)isUnlocked;
-(NSString *)getEnvironmentVariable:(NSString *)varName;
-(void)setEnvironmentVariable:(NSString *)varName value:(id)value;
-(NSString *)getLaunchOption:(NSString *)option;
-(void)setLaunchOption:(NSString *)option value:(id<NSObject>)value type:(JCILaunchOption)optionType;
- (IBAction)toggleJenkins:(id)sender;
- (IBAction)updateJenkins:(id)sender;

@end
