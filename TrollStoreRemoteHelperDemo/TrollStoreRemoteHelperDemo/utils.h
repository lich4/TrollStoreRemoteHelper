//
//  utils.h
//  TrollStoreRemoteHelper
//
//  Created by APPLE on 2023/12/27.
//  Copyright © 2023 chaoge. All rights reserved.
//

#ifndef utils_h
#define utils_h

#import <Foundation/Foundation.h>

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <spawn.h>
#include <sys/types.h>
#include <sys/socket.h>

// borrow from TSUtils
enum {
    SPAWN_FLAG_ROOT     = 1,
    SPAWN_FLAG_NOWAIT   = 2,
};
int spawn(NSArray* args, NSString** stdOut, NSString** stdErr, pid_t* pidPtr, int flag);
NSString* getAppEXEPath();

extern NSString* log_prefix;

#endif /* utils_h */
