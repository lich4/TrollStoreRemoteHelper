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
#include <dlfcn.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <spawn.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/stat.h>

extern NSString* log_prefix;

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString* bundleIdentifier;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (void)addObserver:(id)observer;
- (void)removeObserver:(id)observer;
@end


// borrow from TSUtils
enum {
    SPAWN_FLAG_ROOT     = 1,
    SPAWN_FLAG_NOWAIT   = 2,
    SPAWN_FLAG_SUSPEND  = 4,
};
int spawn(NSArray* args, NSString** stdOut, NSString** stdErr, pid_t* pidPtr, int flag, NSDictionary* param=nil);
NSString* getTrollStoreBundlePath();

NSString* getLocalIP();
void addPathEnv(NSString* path, BOOL tail=YES);
BOOL localPortOpen(int port);
NSString* getAppEXEPath();
void runAsDaemon(void(^Block)());
int platformize_me();
void Alert(NSString* title, NSString* msg, CFTimeInterval tmout);
#endif /* utils_h */
