//
//  Jenkins.h
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

@interface Jenkins : NSPreferencePane

@property (nonatomic, readwrite, retain) NSMutableDictionary *launchdPlist;
@property (nonatomic, readwrite, retain) NSString *plistPath;
@property (nonatomic, readwrite, retain) NSString *plistName;
@property (nonatomic, readwrite, assign, getter = isRunning) BOOL running;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *httpPortField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *httpsPortField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ajpPortField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *jenkinsWarField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *prefixField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *heapSizeField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *jenkinsHomeField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *otherField;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *startButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *updateButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *autostart;


- (void)mainViewDidLoad;

- (IBAction)startJenkins:(id)sender;
- (IBAction)updateJenkins:(id)sender;

@end
