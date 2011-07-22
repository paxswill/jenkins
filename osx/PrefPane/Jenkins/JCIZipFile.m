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


void * debugAlloc(void *opaque, uInt items, uInt size);
void debugFree(void *opaque, void *address);

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
	// This is more than a little naive, but /shouldn't/ take too much time, as the manifest should be the first file
	uint32_t headerSignature = CFSwapInt32LittleToHost(0x04034b50);
	NSData *headerSignatureData = [NSData dataWithBytes:&headerSignature length:4];
	NSRange headerSignatureRange = [self.fileData rangeOfData:headerSignatureData options:0 range:NSMakeRange(0, [self.fileData length])];
	const uint8_t *rawData = [self.fileData bytes];
	NSUInteger dataLength = [self.fileData length];
	while(headerSignatureRange.location != NSNotFound){
		NSUInteger signatureOffset = headerSignatureRange.location;
		uint16_t fileNameLength = (uint16_t)(*(rawData + signatureOffset + 26));
		uint16_t extraLength = (uint16_t)(*(rawData + signatureOffset + 28));
		NSString *fileName = [[NSString alloc] initWithBytes:(rawData + signatureOffset + 30) length:fileNameLength encoding:NSUTF8StringEncoding];
		if([fileName rangeOfString:@"META-INF/MANIFEST.MF"].location != NSNotFound){
			uint16_t flag = (uint16_t)(*(rawData + signatureOffset + 6));
			uint16_t compressionMethod = (uint16_t)(*(rawData + signatureOffset + 8));
			NSUInteger fileDataOffset = signatureOffset + 30 + fileNameLength + extraLength;
			uint32_t originalCRC;
			uint32_t compressedLength;
			uint32_t uncompressedLength;
			if(flag & 0x8){
				// file size in footer
				uint32_t footerSignature = CFSwapInt32LittleToHost(0x08074b50);
				NSData *footerSignatureData = [NSData dataWithBytes:&footerSignature length:4];
				NSRange footerRange = [self.fileData rangeOfData:footerSignatureData options:0 range:NSMakeRange(signatureOffset, dataLength - signatureOffset)];
				if(footerRange.location != NSNotFound){
					originalCRC = (uint32_t)(*(rawData + footerRange.location + 4));
					compressedLength = (uint32_t)(*(rawData + footerRange.location + 8));
					uncompressedLength = (uint32_t)(*(rawData + footerRange.location + 12));
				}else{
					NSLog(@"Problem finding end of file");
					return nil;
				}
			}else{
				originalCRC = (uint32_t)(*(rawData + signatureOffset + 14));
				compressedLength = (uint32_t)(*(rawData + signatureOffset + 18));
				uncompressedLength = (uint32_t)(*(rawData + signatureOffset + 22));
			}
			if(compressionMethod == 8){
				// deflate
				NSMutableData *manifestData = [NSMutableData dataWithLength:uncompressedLength + uncompressedLength / 2];
				[self inflate:[NSData dataWithBytes:(rawData + fileDataOffset) length:compressedLength] toData:manifestData];
				// Pull the version out
				NSString *manifest = [[NSString alloc] initWithData:manifestData encoding:NSUTF8StringEncoding];
				NSArray *lines = [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
				[manifest release];
				for(NSString *line in lines){
					NSRange versionRange = [line rangeOfString:@"Implementation-Version: "];
					if(versionRange.location != NSNotFound){
						return [line substringFromIndex:versionRange.length];
					}
				}
			}else{
				NSLog(@"Unsupported compression algorithm (%d)", compressionMethod);
			}
		}
		signatureOffset += 4;
		headerSignatureRange = [self.fileData rangeOfData:headerSignatureData options:0 range:NSMakeRange(signatureOffset, dataLength - signatureOffset)];
	}
	return nil;
}

-(void)inflate:(NSData *)input toData:(NSMutableData *)output{
	z_stream stream;
	stream.zalloc = debugAlloc;
	stream.zfree = debugFree;
	stream.opaque = Z_NULL;
	
	// Set source and destination
	stream.avail_in = (uInt)[input length];
	stream.next_in = [input bytes];
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
                uInt growSize = [output length] / 2;
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

void * debugAlloc(void *opaque, uInt items, uInt size){
	void *mem = malloc(items * size);
	if(!mem){
		NSLog(@"Error allocating memory for zlib");
		return Z_NULL;
	}else{
		return mem;
	}
}

void debugFree(void *opaque, void *address){
	free(address);
}




