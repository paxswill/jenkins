//
//  JCIZipFile.m
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/21/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

// So we can continue building in 10.6 but take advantage os 10.7 for those running Lion


#import "JCIZipFile.h"
#import <stdint.h>
#import <string.h>
#import <zlib.h>

@interface JCIZipFile()
-(void)inflate:(NSData *)input toData:(NSMutableData *)output;
@end


@implementation JCIZipFile

@synthesize fileData;

-(id)initWithFile:(NSString *)fileName{
	if((self = [super init])){
		// 10.6 formalized a lot of previously informal protocols
		// Here we add the NSTableView delegate and dataSource protocols
		SInt32 majorVersion;
		SInt32 minorVersion;
		Gestalt(gestaltSystemVersionMajor, &majorVersion);
		Gestalt(gestaltSystemVersionMinor, &minorVersion);
		NSDataReadingOptions readOptions = 0;
		if(majorVersion >= 10 && minorVersion >= 7){
            // This is here so I can continue working on my dev machine (on 10.6) while partially adding support for 10.7
#ifdef MAC_OS_X_VERSION_10_7
			readOptions |= NSDataReadingMappedIfSafe;
#endif
		}else if(majorVersion >= 10 && minorVersion >= 6){
			readOptions |= NSDataReadingMapped;
		}else if(majorVersion >= 10 && minorVersion >= 4){
			readOptions |= NSMappedRead;
		}
		NSError *error = nil;
		self.fileData = [NSData dataWithContentsOfFile:fileName options:readOptions error:&error];
		if(!self.fileData){
			NSLog(@"Error opening file: %@", error);
			return nil;
		}
	}
	return self;
}

- (void)dealloc{
	
    [super dealloc];
}

-(NSString *)jarVersion{
	// Magic signatures
	uint32_t directoryListingSignature = CFSwapInt32LittleToHost(0x02014b50);
	uint32_t directoryListingEndSignature = CFSwapInt32LittleToHost(0x06054b50);
	NSData *directoryListingEndSignatureData = [NSData dataWithBytes:&directoryListingEndSignature length:4];
	uint32_t headerSignature = CFSwapInt32LittleToHost(0x04034b50);
	// Look through the directory for our file
	NSUInteger directoryEndOffset = [self.fileData rangeOfData:directoryListingEndSignatureData options:NSBackwardsSearch range:NSMakeRange(0, [self.fileData length])].location;
	if(directoryEndOffset == NSNotFound){
		NSLog(@"Directory ending not found");
		return nil;
	}
	// Assume only one "disk"
	uint32_t directoryOffset;
	[self.fileData getBytes:&directoryOffset range:NSMakeRange(directoryEndOffset + 16, 4)];
	uint16_t numRecords;
	[self.fileData getBytes:&numRecords range:NSMakeRange(directoryEndOffset + 10, 2)];
	uint32_t recordOffset = directoryOffset;
	BOOL found = NO;
	for(int i = 0; i < numRecords; ++i){
		// Check that this is a directory record
		uint32_t checkRecordSignature;
		[self.fileData getBytes:&checkRecordSignature range:NSMakeRange(recordOffset, 4)];
		if(checkRecordSignature != directoryListingSignature){
			NSLog(@"Directory listing mismatch, aborting");
			return nil;
		}
		// Get variable lengths
		uint16_t nameLength;
		[self.fileData getBytes:&nameLength range:NSMakeRange(recordOffset + 28, 2)];
		uint16_t extraLength;
		[self.fileData getBytes:&extraLength range:NSMakeRange(recordOffset + 30, 2)];
		uint16_t commentLength;
		[self.fileData getBytes:&commentLength range:NSMakeRange(recordOffset + 32, 2)];
		// Look for "META-INF/MANIFEST.MF"
		if(nameLength == 20 && strncmp("META-INF/MANIFEST.MF", (const char *)((uint8_t *)[self.fileData bytes] + recordOffset + 46), nameLength)){
			found = YES;
			break;
		}
		// Increment the record offset
		recordOffset += 46 + nameLength + extraLength + commentLength;
	}
	if(!found){
		NSLog(@"Manifest not found");
		return nil;
	}
	uint32_t directoryReferenceCRC;
	[self.fileData getBytes:&directoryReferenceCRC range:NSMakeRange(recordOffset + 16, 4)];
	uint16_t compressionMethod;
	[self.fileData getBytes:&compressionMethod range:NSMakeRange(recordOffset + 10, 2)];
	uint32_t compressedSize;
	[self.fileData getBytes:&compressedSize range:NSMakeRange(recordOffset + 20, 4)];
	uint32_t uncompressedSize;
	[self.fileData getBytes:&uncompressedSize range:NSMakeRange(recordOffset + 24, 4)];
	uint32_t localHeaderOffset;
	[self.fileData getBytes:&localHeaderOffset range:NSMakeRange(recordOffset + 42, 4)];
	// Go to the file and start reading it
	uint32_t checkLocalSignature;
	[self.fileData getBytes:&checkLocalSignature range:NSMakeRange(localHeaderOffset, 4)];
	if(checkLocalSignature != headerSignature){
		NSLog(@"Local Header signature does not match");
		return nil;
	}
	uint16_t nameLength;
	[self.fileData getBytes:&nameLength range:NSMakeRange(localHeaderOffset + 26, 2)];
	uint16_t extraLength;
	[self.fileData getBytes:&extraLength range:NSMakeRange(localHeaderOffset + 28, 2)];
	uint32_t fileDataOffset = localHeaderOffset + 30 + nameLength + extraLength;
	// Decompress
	NSData *manifestData;
	if(compressionMethod == 0){
		// No Compression
		manifestData = [self.fileData subdataWithRange:NSMakeRange(fileDataOffset, compressedSize)];
	}else if(compressionMethod == 8){
		// DEFLATE
		manifestData = [NSMutableData dataWithLength:uncompressedSize];
		[self inflate:[self.fileData subdataWithRange:NSMakeRange(fileDataOffset, compressedSize)] toData:(NSMutableData *)manifestData];
	}else{
		NSLog(@"Unsupported compression algorithm (%d)", compressionMethod);
	}
	// Check CRC
	uint32_t checkCRC = (uint32_t)crc32(0L, Z_NULL, 0);
	checkCRC = (uint32_t)crc32(checkCRC, [manifestData bytes], (uInt)[manifestData length]);
	if(checkCRC != directoryReferenceCRC){
		NSLog(@"CRC mismatch");
		return nil;
	}
	// Find the version
	NSString *manifest = [[NSString alloc] initWithData:manifestData encoding:NSUTF8StringEncoding];
	NSArray *lines = [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	[manifest release];
	for(NSString *line in lines){
		NSRange versionRange = [line rangeOfString:@"Implementation-Version: "];
		if(versionRange.location != NSNotFound){
			return [line substringFromIndex:versionRange.length];
		}
	}
	return nil;
}

-(void)inflate:(NSData *)input toData:(NSMutableData *)output{
	z_stream stream;
	stream.zalloc = Z_NULL;
	stream.zfree = Z_NULL;
	stream.opaque = Z_NULL;
	
	// Set source and destination
	stream.avail_in = (uInt)[input length];
	stream.next_in = (Bytef *)[input bytes];
	stream.avail_out = (uInt)[output length];
	stream.next_out = [output mutableBytes];
	
	int err = inflateInit2(&stream, -MAX_WBITS);
	if(err != Z_OK){
		NSLog(@"Error initializing infation: %s", stream.msg);
		return;
	}
	
	// Inflate
    do{
        err = inflate(&stream, Z_FINISH);
        switch (err) {
            case Z_BUF_ERROR:
            {
                uInt growSize = (uInt)[output length] / 2;
                [output increaseLengthBy:(growSize)];
                stream.avail_out = growSize;
                stream.next_out = (uint8_t *)[output mutableBytes] + growSize;
                err = Z_OK;
                break;   
            }
            case Z_NEED_DICT:
                err = Z_DATA_ERROR;
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
                inflateEnd(&stream);
                NSLog(@"Error inflating: %s (%d)", stream.msg, err);
                return;
        }
    }while(stream.avail_in != 0);
	inflateEnd(&stream);
	[output setLength:stream.total_out];
}

@end

