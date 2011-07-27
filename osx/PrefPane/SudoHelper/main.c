//
//  main.c
//  SudoHelper
//
//  Created by William Ross on 7/27/11.
//  Copyright 2011 Naval Research Lab. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

int main (int argc, const char * argv[])
{
	if(argc < 2){
		fprintf(stderr, "Arguemnts must match execv, where the first argument is the first to\
				execv, and further arguments are put into the second execv argument");
		exit(1);
	}
	int err;
	err = setuid(0);
	if(err == -1){
		fprintf(stderr, "Error switching UID: %s (%d)\n", strerror(errno), errno);
	}
	// Create the argument list
	char ** child_argv = NULL;
	if(argc > 2){
		int argv_count = argc - 1;
		child_argv = malloc(sizeof(char *) * argv_count);
		for(int i = 2; i < argc; ++i){
			child_argv[i] = argv[i - 2];
		}
		child_argv[argv_count] = NULL;
	}
	err = execv(argv[1], child_argv);
	// By returning, execv failed
	fprintf(stderr, "Error calling execv: %s (%d)\n", strerror(errno), errno);
}

