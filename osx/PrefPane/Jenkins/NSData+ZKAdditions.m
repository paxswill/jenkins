//
//  NSData+ZKAdditions.m
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/21/11.
//  Copyright 2009 Karl Moskowski. All rights reserved.
//

#import "NSData+ZKAdditions.h"
#import "zlib.h"

@implementation NSData (NSData_ZKAdditions)

- (NSData *) JCIzk_inflate {
	NSUInteger full_length = [self length];
	NSUInteger half_length = full_length / 2;
	
	NSMutableData *inflatedData = [NSMutableData dataWithLength:full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = [self length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, -MAX_WBITS) != Z_OK) return nil;
	while (!done) {
		if (strm.total_out >= [inflatedData length])
			[inflatedData increaseLengthBy:half_length];
		strm.next_out = [inflatedData mutableBytes] + strm.total_out;
		strm.avail_out = [inflatedData length] - strm.total_out;
		status = inflate(&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd(&strm) == Z_OK && done)
		[inflatedData setLength:strm.total_out];
	else
		inflatedData = nil;
	return inflatedData;
}

@end
