//
//  JCIZipFile.h
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/21/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCIZipFile : NSObject{
@private
	NSData *fileData;
}
@property (readwrite, retain) NSData *fileData;
-(id)initWithFile:(NSString *)fileName;
-(NSString *)jarVersion;
@end
