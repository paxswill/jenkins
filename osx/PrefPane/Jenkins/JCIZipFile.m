//
//  JCIZipFile.m
//  Jenkins Preference Pane
//
//  Created by William Ross on 7/21/11.
//  Copyright 2011 Will Ross. All rights reserved.
//

// So we can continue building in 10.6 but take advantage os 10.7 for those running Lion


#import "JCIZipFile.h"
#import "NSData+ZKAdditions.h"

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
			NSUInteger compressedLength;
			NSUInteger uncompressedLength;
			if(flag & 0x8){
				// file size in footer
				uint32_t footerSignature = CFSwapInt32LittleToHost(0x08074b50);
				NSData *footerSignatureData = [NSData dataWithBytes:&footerSignature length:4];
				NSRange footerRange = [self.fileData rangeOfData:footerSignatureData options:0 range:NSMakeRange(signatureOffset, dataLength - signatureOffset)];
				if(footerRange.location != NSNotFound){
					compressedLength = (NSUInteger)((uint32_t)(*(rawData + footerRange.location + 8)));
					uncompressedLength = (NSUInteger)((uint32_t)(*(rawData + footerRange.location + 12)));
				}else{
					NSLog(@"Problem finding end of file");
					return nil;
				}
			}else{
				compressedLength = (NSUInteger)((uint32_t)(*(rawData + signatureOffset + 18)));
				uncompressedLength = (NSUInteger)((uint32_t)(*(rawData + signatureOffset + 22)));
			}
			if(compressionMethod == 8){
				// deflate
				NSMutableData *manifestData = [NSData dataWithBytes:(rawData + fileDataOffset) length:compressedLength];
				NSString *manifest = [[NSString alloc] initWithData:[manifestData JCIzk_inflate] encoding:NSUTF8StringEncoding];
				NSArray *lines = [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				[manifest release];
				for(NSString *line in lines){
					NSRange versionRange = [line rangeOfString:@"Implementation-Version: "];
					if(versionRange.location != NSNotFound){
						return [line substringFromIndex:versionRange.location];
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

@end



