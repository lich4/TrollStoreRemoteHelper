#import <Foundation/Foundation.h>
#import <GCDWebServers/GCDWebServers.h>
#include "Reachability.h"
#import <UIKit/UIKit.h>
#include "utils.h"

#define PRODUCT         "TrollStoreRemoteHelper"
#define GSERV_PORT      1222
#define GSSHD_PORT      1223

NSString* log_prefix = @(PRODUCT "Logger");


@interface AppDelegate : UIViewController<UIApplicationDelegate, UIWindowSceneDelegate, UIWebViewDelegate>
@property(strong, nonatomic) UIWindow* window;
@property(retain) UIWebView* webview;
@end

@implementation AppDelegate
static UIWindow* _g_wind = nil;
static AppDelegate* _g_app = nil;
- (void)sceneWillEnterForeground:(UIScene*)scene API_AVAILABLE(ios(13.0)) {
    _g_wind = self.window;
}
- (BOOL)application:(UIApplication*)application willFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id>*)launchOptions {
    _g_wind = self.window;
    return YES;
}
- (void)viewDidAppear:(BOOL)animated {
    @autoreleasepool {
        [super viewDidAppear:animated];
        self.window = _g_wind;
        _g_app = self;
        
        CGSize size = UIScreen.mainScreen.bounds.size;
        // iOS>=16时WKWebView只能在沙盒中运行,不能用于TrollStore环境
        UIWebView* webview = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        webview.delegate = self;
        self.webview = webview;

        NSString* wwwpath = [NSString stringWithFormat:@"http://127.0.0.1:%d", GSERV_PORT];
        NSURL* url = [NSURL URLWithString:wwwpath];
        NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.0];
        [webview loadRequest:req];
    }
}
- (void)webViewDidFinishLoad:(UIWebView*)webview {
    [self.window addSubview:webview];
    [self.window bringSubviewToFront:webview];
}
- (void)webView:(UIWebView*)webview didFailLoadWithError:(NSError*)error {
    NSString* surl = webview.request.URL.absoluteString;
    [NSThread sleepForTimeInterval:0.5];
    if (surl.length == 0) { // 服务端未初始化时url会被置空
        surl = [NSString stringWithFormat:@"http://127.0.0.1:%d", GSERV_PORT];
    }
    NSURL* url = [NSURL URLWithString:surl];
    NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:3.0];
    [webview loadRequest:req];
}
@end


@interface Service: NSObject
+ (instancetype)inst;
- (instancetype)init;
- (void)serve;
@end

static pid_t pid_sshd = -1;

@implementation Service {
    NSMutableArray* logList;
    NSString* helper;
    NSString* bid;
    NSString* localIP;
}
+ (instancetype)inst {
    static dispatch_once_t pred = 0;
    static Service* inst_ = nil;
    dispatch_once(&pred, ^{
        inst_ = [self new];
    });
    return inst_;
}
- (instancetype)init {
    @autoreleasepool {
        self = super.init;
        self->bid = NSBundle.mainBundle.bundleIdentifier;
        self->logList = [NSMutableArray new];
        self->helper = nil;
        NSString* binPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"fakeroot/bin"];
        addPathEnv(binPath);
        NSString* trollPath = getTrollStoreBundlePath();
        if (trollPath == nil) {
            [self addLog:@"helper not find"];
            Alert(@"Error", @"helper not find", 10);
            return self;
        }
        NSFileManager* man = [NSFileManager defaultManager];
        NSString* helper_path = [trollPath stringByAppendingPathComponent:@"trollstorehelper"];
        if (![man fileExistsAtPath:helper_path]) {
            [self addLog:@"helper not find2"];
            Alert(@"Error", @"helper not find2s", 10);
            return self;
        }
        self->helper = helper_path;
        addPathEnv(trollPath);
        [self addLog:@"helper find: %@", helper_path];
        NSLog(@"%@ helper find: %@", log_prefix, helper_path);
        [self addLog:@"PATH=%s", getenv("PATH")];
        NSString* downPath = [NSString stringWithFormat:@"%@/tmp", NSHomeDirectory()];
        if (![man fileExistsAtPath:downPath]) {
            [man createDirectoryAtPath:downPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        return self;
    }
}
- (void)applicationsDidUninstall:(NSArray<LSApplicationProxy*>*)list {
    @autoreleasepool {
        for (LSApplicationProxy* proxy in list) {
            if ([proxy.bundleIdentifier isEqualToString:self->bid]) {
                NSLog(@"%@ uninstalled, exit", log_prefix); // 卸载时旧版daemon自动退出
                exit(0);
            }
        }
    }
}
- (void)applicationsDidInstall:(NSArray<LSApplicationProxy*>*)list {
    @autoreleasepool {
        for (LSApplicationProxy* proxy in list) {
            if ([proxy.bundleIdentifier isEqualToString:self->bid]) {
                NSLog(@"%@ updated, exit", log_prefix); // 覆盖安装时旧版daemon自动退出
                exit(0);
            }
        }
    }
}
- (void)serve_sshd {
    NSString* root_path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"fakeroot"];
    NSDictionary* param = @{
        @"cwd": root_path,
        @"close": getUnusedFds(),
    };
    //int status = spawn(@[@"dropbear", @"-p", [@GSSHD_PORT stringValue], @"-F", @"-S", root_path], nil, nil, &self->pid_sshd, SPAWN_FLAG_ROOT | SPAWN_FLAG_NOWAIT);
    // dropbear使用fork,不兼容16.x+arm64e; sshdog使用posix_spawn,兼容性更好
    int status = spawn(@[@"sshdog", @"-p", [@GSSHD_PORT stringValue]], nil, nil, &pid_sshd, SPAWN_FLAG_ROOT | SPAWN_FLAG_NOWAIT, param);
    NSLog(@"%@ spawn sshd status=%d pid=%d", log_prefix, status, pid_sshd);
    [self addLog:@"sshd listen=%@:%d", self->localIP, GSSHD_PORT];
}
- (void)serve {
    @autoreleasepool {
        self->localIP = getLocalIP();
        static GCDWebServer* _webServer = nil;
        if (_webServer == nil) {
            if (localPortOpen(GSERV_PORT)) {
                NSLog(@"%@ already served, exit", log_prefix);
                exit(0); // 服务已存在,退出
            }
            _webServer = [GCDWebServer new];
            NSString* html_root = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"www"];
            [_webServer addGETHandlerForBasePath:@"/" directoryPath:html_root indexFilename:@"index.html" cacheAge:1 allowRangeRequests:YES];
            [_webServer addDefaultHandlerForMethod:@"PUT" requestClass:GCDWebServerDataRequest.class processBlock:^GCDWebServerResponse*(GCDWebServerDataRequest* request) {
                int status = [self handlePUT:request.path with:request.data];
                return [GCDWebServerResponse responseWithStatusCode:status];
            }];
            [_webServer addDefaultHandlerForMethod:@"POST" requestClass:GCDWebServerDataRequest.class processBlock:^GCDWebServerResponse*(GCDWebServerDataRequest* request) {
                NSDictionary* jres = [self handlePOST:request.path with:request.text];
                return [GCDWebServerDataResponse responseWithJSONObject:jres];
            }];
            [self addLog:@"serv listen=%@:%d", self->localIP, GSERV_PORT];
            NSLog(@"%@ pid=%d listen=%@:%d", log_prefix, getpid(), self->localIP, GSERV_PORT);
            BOOL status = [_webServer startWithPort:GSERV_PORT bonjourName:nil];
            if (!status) {
                NSLog(@"%@ serve failed, exit", log_prefix);
                exit(0);
            }
            [LSApplicationWorkspace.defaultWorkspace addObserver:self];
            static Reachability* reach = [Reachability reachabilityWithHostname:@"www.baidu.com"];
            reach.reachabilityBlock = ^(Reachability* reachability, SCNetworkConnectionFlags flags) {
                self->localIP = getLocalIP();
                [self addLog:@"serv listen=%@:%d", self->localIP, GSERV_PORT];
                [self addLog:@"sshd listen=%@:%d", self->localIP, GSSHD_PORT];
            };
            [reach startNotifier];
        }
        if (!localPortOpen(GSSHD_PORT)) { // 先启动sshd防止GSERV_PORT端口继承给sshd
            [self serve_sshd];
        }
    }
}
- (void)addLog:(NSString*)fmt, ... {
    va_list va;
    va_start(va, fmt);
    NSString* log = [[NSString alloc] initWithFormat:fmt arguments:va];
    NSDateFormatter* dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
    [self->logList addObject:[NSString stringWithFormat:@"%@  %@", dateStr, log]];
}
- (NSDictionary*)handlePOST:(NSString*)path with:(NSString*)data {
    @autoreleasepool {
        if ([path isEqualToString:@"/log"]) {
            return @{
                @"status": @0,
                @"data": logList,
            };
        } else if ([path hasPrefix:@"/cmd"]) {
            NSString* stdOut = nil;
            NSString* stdErr = nil;
            NSArray* cmd = [data componentsSeparatedByString:@" "];
            int status = spawn(cmd, &stdOut, &stdErr, 0, SPAWN_FLAG_ROOT);
            return @{
                @"status": @(status),
                @"stdout": stdOut,
                @"stderr": stdErr,
            };
        } else if ([path hasPrefix:@"/shell"]) {
            NSString* filePath = [NSString stringWithFormat:@"%@/tmp/_tmp.sh", NSHomeDirectory()];
            if (![data writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
                return @{
                    @"status": @-1,
                };
            }
            NSString* stdOut = @"";
            NSString* stdErr = @"";
            int status = spawn(@[@"bash", filePath], &stdOut, &stdErr, nil, SPAWN_FLAG_ROOT);
            return @{
                @"status": @(status),
                @"stdout": stdOut,
                @"stderr": stdErr,
            };
        }
        return @{
            @"status": @-1,
        };
    }
}
- (int)handlePUT:(NSString*)path with:(NSData*)data { // for upload file or install ipa
    @autoreleasepool {
        if ([path hasPrefix:@"/install"]) {
            if (self->helper == nil) {
                return 410;
            }
            NSString* fileName = [path lastPathComponent];
            NSString* filePath = [NSString stringWithFormat:@"%@/tmp/%@", NSHomeDirectory(), fileName];
            if (![data writeToFile:filePath atomically:YES]) {
                [self addLog:@"download failed: %@", filePath];
                return 411;
            }
            [self addLog:@"download success: %@", filePath];
            NSLog(@"%@ download success: %@", log_prefix, filePath);
            int status = spawn(@[@"trollstorehelper", @"install", filePath], nil, nil, nil, SPAWN_FLAG_ROOT); // 需要先卸载吗?
            if (status != 0) {
                [self addLog:@"install failed %d: %@", status, fileName];
                NSLog(@"%@ install failed %d: %@", log_prefix, status, fileName);
                return 412;
            }
            [self addLog:@"install success %@", fileName];
            NSLog(@"%@ install success %@", log_prefix, fileName);
        }
        return 200;
    }
}
@end


int main(int argc, char** argv) {
    @autoreleasepool {
        if (argc == 1) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                pid_t pid_serv = -1;
                spawn(@[getAppEXEPath(), @"serve"], nil, nil, &pid_serv, SPAWN_FLAG_ROOT | SPAWN_FLAG_NOWAIT);
            });
            return UIApplicationMain(argc, argv, nil, @"AppDelegate");
        }
        if (0 == strcmp(argv[1], "serve")) {
            signal(SIGHUP, SIG_IGN);
            signal(SIGTERM, SIG_IGN); // 防止App被Kill以后daemon退出
            [Service.inst serve];
            atexit_b(^{
                [LSApplicationWorkspace.defaultWorkspace removeObserver:Service.inst];
                if (pid_sshd > 0) {
                    kill(pid_sshd, SIGKILL);
                }
            });
            [NSRunLoop.mainRunLoop run];
        }
        return -1;
    }
}


// todo 增加posix_spawn ssh
