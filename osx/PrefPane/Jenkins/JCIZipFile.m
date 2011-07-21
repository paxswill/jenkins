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
#import <fcntl.h>
#import <sys/stat.h>
#import <sys/mman.h>
#import <zlib.h>

typedef struct{
	uint32_t signature;
	uint16_t minimumVersion;
	uint16_t flag;
	uint16_t compressionMethod;
	uint16_t modificationTime;
	uint16_t modificationDate;
	uint32_t crc32;
	uint32_t compressedSize;
	uint32_t uncompressedSize;
	uint16_t fileNameLength;
	uint16_t extraLength;
	void *fileName;
} JCIZipFileHeader;

@interface JCIZipFile()
-(NSData *)inflate:(NSData *)input;
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
	// This is more than a little naive, but /shouldn't/ take too much time, as the manifest should be the first file
	uint32_t headerSignature = CFSwapInt32LittleToHost(0x04034b50);
	NSData *headerSignatureData = [NSData dataWithBytes:&headerSignature length:4];
	NSRange headerSignatureRange = [self.fileData rangeOfData:headerSignatureData options:0 range:NSMakeRange(0, [self.fileData length])];
	const uint8_t *rawData = [self.fileData bytes];
	NSUInteger dataLength = [self.fileData length];
	while(headerSignatureRange.location != NSNotFound){
		NSUInteger signatureOffset = headerSignatureRange.location;
		const JCIZipFileHeader *fileHeader = (JCIZipFileHeader *)rawData + signatureOffset;
		NSString *fileName = [[NSString alloc] initWithBytes:fileHeader->fileName length:fileHeader->fileNameLength encoding:NSUTF8StringEncoding];
		if([fileName rangeOfString:@"META-INF/MANIFEST.MF"].location != NSNotFound){
			NSUInteger fileDataOffset = signatureOffset + 30 + fileHeader->fileNameLength + fileHeader->extraLength;
			NSUInteger fileDataLength;
			if(fileHeader->flag & 0x8){
				// file size in footer
				uint32_t footerSignature = CFSwapInt32LittleToHost(0x08074b50);
				NSData *footerSignatureData = [NSData dataWithBytes:&footerSignature length:4];
				NSRange footerRange = [self.fileData rangeOfData:footerSignatureData options:0 range:NSMakeRange(signatureOffset, dataLength - signatureOffset)];
				if(footerRange.location != NSNotFound){
					fileDataLength = footerRange.location - 1 - (30 + fileHeader->fileNameLength + fileHeader->extraLength);
				}else{
					NSLog(@"Problem finding end of file");
					return nil;
				}
			}else{
				fileDataLength = fileHeader->compressedSize;
			}
			if(fileHeader->compressionMethod == 8){
				// deflate
				NSString *manifest = [[NSString alloc] initWithData:[self inflate:[NSData dataWithBytes:(rawData + fileDataOffset) length:fileDataLength]] encoding:NSUTF8StringEncoding];
				NSArray *lines = [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				[manifest release];
				for(NSString *line in lines){
					NSRange versionRange = [line rangeOfString:@"Implementation-Version: "];
					if(versionRange.location != NSNotFound){
						return [line substringFromIndex:versionRange.location];
						
					}
				}
			}else{
				NSLog(@"Unsupported compression algorithm (%d)", fileHeader->compressionMethod);
			}
		}
		signatureOffset += 4;
		headerSignatureRange = [self.fileData rangeOfData:headerSignatureData options:0 range:NSMakeRange(signatureOffset, dataLength - signatureOffset)];
	}
	return nil;
}

-(NSData *)inflate:(NSData *)input{
	z_stream stream;
	stream.zalloc = Z_NULL;
	stream.zfree = Z_NULL;
	stream.opaque = Z_NULL;
	stream.avail_in = Z_NULL;
	stream.avail_out = Z_NULL;
	
	NSMutableData *outData = [[NSMutableData alloc] init];
	const size_t bufferSize = 1024 * 4;
	void *buffer = malloc(bufferSize);
	
	int err = inflateInit(&stream);
	if(err != Z_OK){
		return nil;
	}
	stream.avail_in = [input length];
	// Inflate
	do {
		stream.avail_out = bufferSize;
		stream.next_out = buffer;
		err = inflate(&stream, Z_NO_FLUSH);
		switch (err) {
			case Z_NEED_DICT:
				err = Z_DATA_ERROR;
			case Z_DATA_ERROR:
			case Z_MEM_ERROR:
				inflateEnd(&stream);
				return nil;
		}
		[outData appendBytes:buffer length:(bufferSize - stream.avail_out)];
	} while (err != Z_STREAM_END);
	free(buffer);
	return [outData autorelease];
}

@end



