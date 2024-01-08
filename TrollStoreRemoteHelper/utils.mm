//
//  utils.m
//  TrollStoreRemoteHelper
//
//  Created by APPLE on 2023/12/27.
//  Copyright © 2023 chaoge. All rights reserved.
//

#include "utils.h"

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern "C" {
int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);
}

int fd_is_valid(int fd) {
    return fcntl(fd, F_GETFD) != -1 || errno != EBADF;
}

NSString* getNSStringFromFile(int fd) {
    NSMutableString* ms = [NSMutableString new];
    ssize_t num_read;
    char c;
    if (!fd_is_valid(fd)) {
        return @"";
    }
    while ((num_read = read(fd, &c, sizeof(c)))) {
        [ms appendString:[NSString stringWithFormat:@"%c", c]];
        //if(c == '\n') {
        //    break;
        //}
    }
    return ms.copy;
}

extern char** environ;
int spawn(NSArray* args, NSString** stdOut, NSString** stdErr, pid_t* pidPtr, int flag) {
    NSString* file = args.firstObject;
    NSUInteger argCount = [args count];
    char **argsC = (char **)malloc((argCount + 1) * sizeof(char*));
    for (NSUInteger i = 0; i < argCount; i++) {
        argsC[i] = strdup([[args objectAtIndex:i] UTF8String]);
    }
    argsC[argCount] = NULL;
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    if ((flag & SPAWN_FLAG_ROOT) != 0) {
        posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
        posix_spawnattr_set_persona_uid_np(&attr, 0);
        posix_spawnattr_set_persona_gid_np(&attr, 0);
    }
    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);
    int outErr[2];
    if(stdErr) {
        pipe(outErr);
        posix_spawn_file_actions_adddup2(&action, outErr[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&action, outErr[0]);
    }
    int out[2];
    if(stdOut) {
        pipe(out);
        posix_spawn_file_actions_adddup2(&action, out[1], STDOUT_FILENO);
        posix_spawn_file_actions_addclose(&action, out[0]);
    }
    pid_t task_pid;
    pid_t* task_pid_ptr = &task_pid;
    if (pidPtr != 0) {
        task_pid_ptr = pidPtr;
    }
    int status = -200;
    int spawnError = posix_spawnp(task_pid_ptr, [file UTF8String], &action, &attr, (char* const*)argsC, environ);
    NSLog(@"posix_spawn %@ %d -> %d", args.firstObject, getpid(), task_pid);
    posix_spawnattr_destroy(&attr);
    for (NSUInteger i = 0; i < argCount; i++) {
        free(argsC[i]);
    }
    free(argsC);
    if(spawnError != 0) {
        NSLog(@"posix_spawn error %d\n", spawnError);
        return spawnError;
    }
    if ((flag & SPAWN_FLAG_NOWAIT) != 0) {
        return 0;
    }
    __block volatile BOOL _isRunning = YES;
    NSMutableString* outString = [NSMutableString new];
    NSMutableString* errString = [NSMutableString new];
    dispatch_semaphore_t sema = 0;
    dispatch_queue_t logQueue;
    if(stdOut || stdErr) {
        logQueue = dispatch_queue_create("com.opa334.TrollStore.LogCollector", NULL);
        sema = dispatch_semaphore_create(0);
        int outPipe = out[0];
        int outErrPipe = outErr[0];
        __block BOOL outEnabled = stdOut != nil;
        __block BOOL errEnabled = stdErr != nil;
        dispatch_async(logQueue, ^{
            while(_isRunning) {
                @autoreleasepool {
                    if(outEnabled) {
                        [outString appendString:getNSStringFromFile(outPipe)];
                    }
                    if(errEnabled) {
                        [errString appendString:getNSStringFromFile(outErrPipe)];
                    }
                }
            }
            dispatch_semaphore_signal(sema);
        });
    }
    do {
        if (waitpid(task_pid, &status, 0) != -1) {
            NSLog(@"Child status %d", WEXITSTATUS(status));
        } else {
            perror("waitpid");
            _isRunning = NO;
            return -222;
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    _isRunning = NO;
    if (stdOut || stdErr) {
        if(stdOut) {
            close(out[1]);
        }
        if(stdErr) {
            close(outErr[1]);
        }
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        if(stdOut) {
            *stdOut = outString.copy;
        }
        if(stdErr) {
            *stdErr = errString.copy;
        }
    }
    return WEXITSTATUS(status);
}


NSString* getTrollStoreBundlePath() {
    NSString* appContainersPath = @"/var/containers/Bundle/Application";
    NSError* error;
    NSArray* containers = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appContainersPath error:&error];
    if (error) {
        NSLog(@"error getting app bundles paths %@", error);
    }
    if (!containers) {
        return nil;
    }
    for(NSString* container in containers) {
        NSString* containerPath = [appContainersPath stringByAppendingPathComponent:container];
        BOOL isDirectory = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:containerPath isDirectory:&isDirectory];
        if (exists && isDirectory) {
            NSString* trollStoreApp = [containerPath stringByAppendingPathComponent:@"TrollStore.app"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:trollStoreApp]) {
                return trollStoreApp;
            }
        }
    }
    return nil;
}



NSString* getLocalIP() { // 获取wifi ipv4
    NSString* result = nil;
    struct ifaddrs* interfaces = 0;
    struct ifaddrs* temp_addr = 0;
    if (0 == getifaddrs(&interfaces)) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if(!strcmp(temp_addr->ifa_name, "en0")) {
                    char* ip = inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr);
                    result = @(ip);
                    break;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
        freeifaddrs(interfaces);
    }
    return result;
}

void addPathEnv(NSString* path, BOOL tail) {
    const char* c_path_env = getenv("PATH");
    NSMutableArray* path_arr = [NSMutableArray new];
    if (c_path_env != 0) {
        path_arr = [[@(c_path_env) componentsSeparatedByString:@":"] mutableCopy];
    }
    if (tail) {
        [path_arr addObject:path];
    } else {
        [path_arr insertObject:path atIndex:0];
    }
    NSString* path_env = [path_arr componentsJoinedByString:@":"];
    setenv("PATH", path_env.UTF8String, 1);
}

BOOL localPortOpen(int port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in ip4;
    memset(&ip4, 0, sizeof(struct sockaddr_in));
    ip4.sin_len = sizeof(ip4);
    ip4.sin_family = AF_INET;
    ip4.sin_port = htons(port);
    inet_aton("127.0.0.1", &ip4.sin_addr);
    int so_error = -1;
    struct timeval tv;
    fd_set fdset;
    fcntl(sock, F_SETFL, O_NONBLOCK);
    connect(sock, (struct sockaddr*)&ip4, sizeof(ip4));
    FD_ZERO(&fdset);
    FD_SET(sock, &fdset);
    tv.tv_sec = 3;
    tv.tv_usec = 0;
    if (select(sock + 1, NULL, &fdset, NULL, &tv) == 1) {
        socklen_t len = sizeof(so_error);
        getsockopt(sock, SOL_SOCKET, SO_ERROR, &so_error, &len);
    }
    close(sock);
    return 0 == so_error;
}

extern "C" int _NSGetExecutablePath(char* buf, uint32_t* bufsize);
NSString* getAppEXEPath() {
    char exe[256];
    uint32_t bufsize = sizeof(exe);
    _NSGetExecutablePath(exe, &bufsize);
    return @(exe);
}

void runAsDaemon(void(^Block)()) {
    static int fds[2];
    int flag;
    pipe(fds);
    flag = fcntl(fds[0], F_GETFL, 0);
    fcntl(fds[0], F_SETFL, flag | O_NONBLOCK);
    flag = fcntl(fds[1], F_GETFL, 0);
    fcntl(fds[1], F_SETFL, flag | O_NONBLOCK);
    int forkpid = fork();
    if (forkpid < 0) {
        return;
    } else if (forkpid > 0) { // father
        return;
    }
    setsid();
    chdir("/");
    umask(0);
    int null_in = open("/dev/null", O_RDONLY);
    int null_out = open("/dev/null", O_WRONLY);
    dup2(null_in, STDIN_FILENO);
    dup2(null_out, STDOUT_FILENO);
    dup2(null_out, STDERR_FILENO);
    Block();
}

void Alert(NSString* title, NSString* msg, CFTimeInterval tmout) {
    if ([NSThread isMainThread]) {
        CFUserNotificationDisplayAlert(tmout, kCFUserNotificationPlainAlertLevel, nil, nil, nil, (__bridge CFStringRef)msg, (__bridge CFStringRef)title, CFSTR("OK"), nil, nil, nil);
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            CFUserNotificationDisplayAlert(tmout, kCFUserNotificationPlainAlertLevel, nil, nil, nil, (__bridge CFStringRef)msg, (__bridge CFStringRef)title, CFSTR("OK"), nil, nil, nil);
        });
    }
}


