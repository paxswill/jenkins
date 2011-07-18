//
//  JCIPrefPane.h
//  Jenkins
//
//  Created by William Ross on 7/11/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import "DKActionButton.h"
#import "JCILaunchdPlist.h"

@interface JCIPrefPane : NSPreferencePane{
	JCILaunchdPlist *plist;
	BOOL uiEnabled;

	NSButton *startButton;
	NSButton *updateButton;
	NSButton *autostart;
	SFAuthorizationView *authorizationView;
	DKActionButton *actionButton;
	NSMutableArray *variables;
	NSMutableArray *jenkinsArgs;
	NSMutableArray *javaArgs;
	int environmentHeaderIndex;
	int javaHeaderIndex;
	int jenkinsHeaderIndex;
}
@property (nonatomic, readwrite, retain) JCILaunchdPlist *plist;
@property (readwrite, assign) BOOL uiEnabled;

@property (nonatomic, readwrite, assign) IBOutlet NSButton *startButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *updateButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *autostart;
@property (nonatomic, readwrite, assign) IBOutlet SFAuthorizationView *authorizationView;
@property (nonatomic, readwrite, assign) IBOutlet DKActionButton *actionButton;
@property (nonatomic, readwrite, assign) IBOutlet NSTableView *tableView;
@property (nonatomic, readwrite, retain) NSMutableArray *variables;
@property (nonatomic, readwrite, retain) NSMutableArray *jenkinsArgs;
@property (nonatomic, readwrite, retain) NSMutableArray *javaArgs;

- (void)mainViewDidLoad;

- (BOOL)isUnlocked;
- (IBAction)toggleJenkins:(id)sender;
- (IBAction)updateJenkins:(id)sender;

@end
