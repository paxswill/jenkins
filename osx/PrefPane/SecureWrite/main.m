//
//  main.m
//  SecureWrite
//
//  Created by William Ross on 7/12/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#import <stdlib.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/types.h>
#import <sys/uio.h>
#import <assert.h>

int main (int argc, const char * argv[])
{
	fprintf(stderr, "Elevated reading in progress");
	// A file handle, and a path are required in argv
	if(argc != 2){
		exit(1);
	}
	// The pipe handle should already be open
	int readFD = fcntl(STDIN_FILENO, F_DUPFD, 0);
	int writeFD = open(argv[1], O_WRONLY | O_CREAT);
	assert(writeFD > 0);
	size_t bufferSize = 1024;
	size_t actualSize;
	void *buffer = malloc(bufferSize);
	while(actualSize = read(readFD, buffer, bufferSize), actualSize != 0){
		assert(actualSize > 0);
		ssize_t writtenBytes = write(writeFD, buffer, actualSize);
		assert(writtenBytes > 0);
	}
	free(buffer);
	close(writeFD);
    return 0;
}

