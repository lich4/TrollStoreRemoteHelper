#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <GCDWebServers/GCDWebServers.h>
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
static BOOL _webview_inited = NO;
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
        // 从WKWebView换UIWebView: 巨魔+越狱共存环境下签名问题导致delegate不生效而黑屏
        UIWebView* webview = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        webview.delegate = self;
        self.webview = webview;

        NSString* wwwpath = [NSString stringWithFormat:@"http://127.0.0.1:%d", GSERV_PORT];
        NSURL* url = [NSURL URLWithString:wwwpath];
        NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.0];
        [webview loadRequest:req];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!_webview_inited) { // 巨魔+越狱共存环境下因签名问题导致delegate不生效而黑屏
                [self.window addSubview:webview];
                [self.window bringSubviewToFront:webview];
                _webview_inited = YES;
            }
        });
    }
}
- (void)webViewDidFinishLoad:(UIWebView*)webview {
    [self.window addSubview:webview];
    [self.window bringSubviewToFront:webview];
    _webview_inited = YES;
}
@end


@interface Service: NSObject
+ (instancetype)inst;
- (instancetype)init;
- (void)serve;
@end

@implementation Service {
    NSMutableArray* logList;
    NSString* helper;
    NSString* bid;
    pid_t pid_sshd;
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
        self->pid_sshd = -1;
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
        return self;
    }
}
- (void)applicationsDidUninstall:(NSArray<LSApplicationProxy*>*)list {
    @autoreleasepool {
        for (LSApplicationProxy* proxy in list) {
            if ([proxy.bundleIdentifier isEqualToString:self->bid]) {
                NSLog(@"%@ uninstalled, exit", log_prefix); // 卸载时系统不能自动杀本进程,需手动退出
                [LSApplicationWorkspace.defaultWorkspace removeObserver:self];
                if (self->pid_sshd > 0) {
                    kill(self->pid_sshd, SIGKILL);
                }
                exit(0);
            }
        }
    }
}
- (void)checkIPChange {
    NSString* newLocalIP = getLocalIP();
    if (![self->localIP isEqualToString:newLocalIP]) {
        NSLog(@"%@ detect IP change %@ -> %@, exit", log_prefix, self->localIP, newLocalIP);
        exit(0);
    }
}
- (void)serve {
    @autoreleasepool {
        NSString* localIP = getLocalIP();
        if (localIP == nil) {
            Alert(@"Error", @"ip fetch failed", 10);
            exit(0);
        }
        if (!localPortOpen(GSSHD_PORT)) { // 先启动sshd防止GSERV_PORT端口继承给sshd
            [self addLog:@"sshd listen=%@:%d", localIP, GSSHD_PORT];
            NSString* root_path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"fakeroot"];
            NSDictionary* param = @{
                @"cwd": root_path,
            };
            //int status = spawn(@[@"dropbear", @"-p", [@GSSHD_PORT stringValue], @"-F", @"-S", root_path], nil, nil, &self->pid_sshd, SPAWN_FLAG_ROOT | SPAWN_FLAG_NOWAIT);
            // dropbear使用fork,不兼容16.x+arm64e; sshdog使用posix_spawn,兼容性更好
            int status = spawn(@[@"sshdog"], nil, nil, &self->pid_sshd, SPAWN_FLAG_ROOT | SPAWN_FLAG_NOWAIT, param);
            NSLog(@"%@ spawn sshd status=%d pid=%d", log_prefix, status, self->pid_sshd);
        } else {
            [self addLog:@"sshd listen=%@:%d", localIP, GSSHD_PORT];
        }
        self->localIP = localIP;
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
            [self addLog:@"pid=%d listen=%@:%d", getpid(), localIP, GSERV_PORT];
            NSLog(@"%@ pid=%d listen=%@:%d", log_prefix, getpid(), localIP, GSERV_PORT);
            BOOL status = [_webServer startWithPort:GSERV_PORT bonjourName:nil];
            if (!status) {
                NSLog(@"%@ serve failed, exit", log_prefix);
                exit(0);
            }
            [LSApplicationWorkspace.defaultWorkspace addObserver:self];
            [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(checkIPChange) userInfo:nil repeats:YES];
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
        }
        return @{
            @"status": @-1,
        };
    }
}
- (int)handlePUT:(NSString*)path with:(NSData*)data { // for upload file or install ipa
    @autoreleasepool {
        NSString* fileName = [path lastPathComponent];
        NSString* filePath = [NSString stringWithFormat:@"%@/tmp/%@", NSHomeDirectory(), fileName];
        if (![data writeToFile:filePath atomically:YES]) {
            [self addLog:@"download failed: %@", filePath];
            return 411;
        }
        [self addLog:@"download success: %@", filePath];
        NSLog(@"%@ download success: %@", log_prefix, filePath);
        if ([path hasPrefix:@"/install"]) {
            if (self->helper == nil) {
                return 410;
            }
            int status = spawn(@[@"trollstorehelper", @"install", filePath], nil, nil, nil, SPAWN_FLAG_ROOT); // 需要先卸载吗?
            if (status != 0) {
                [self addLog:@"install failed %d: %@", status, fileName];
                NSLog(@"%@ install failed %d: %@", log_prefix, status, fileName);
                return 412;
            }
            [self addLog:@"install success %@", fileName];
            NSLog(@"%@ install success %@", log_prefix, fileName);
        } else if ([path hasPrefix:@"/shell"]) {
            NSString* stdOut = @"";
            NSString* stdErr = @"";
            int status = spawn(@[@"sh", filePath], &stdOut, &stdErr, nil, SPAWN_FLAG_ROOT);
            [self addLog:@"cmd=%@ status=%d stdout=%@ stderr=%@", data, status, stdOut, stdErr];
        }
        return 200;
    }
}
@end

NSString* getCwd() {
    char cwd[PATH_MAX];
    getcwd(cwd, sizeof(cwd));
    return @(cwd);
}

int main(int argc, char** argv) {
    @autoreleasepool {
        if (argc == 1) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (!localPortOpen(GSERV_PORT)) {
                    pid_t pid_serv = -1;
                    int status = spawn(@[getAppEXEPath(), @"serve"], nil, nil, &pid_serv, SPAWN_FLAG_ROOT | SPAWN_FLAG_NOWAIT);
                    NSLog(@"%@ spawn server status=%d pid=%d", log_prefix, status, pid_serv);
                }
            });
            return UIApplicationMain(argc, argv, nil, @"AppDelegate");
        }
        if (0 == strcmp(argv[1], "serve")) {
            NSLog(@"%@ serve cwd=%@", log_prefix, getCwd());
            signal(SIGHUP, SIG_IGN);
            signal(SIGTERM, SIG_IGN); // 防止App被Kill以后daemon退出
            [Service.inst serve];
            [NSRunLoop.mainRunLoop run];
        }
        return -1;
    }
}


// todo 增加posix_spawn ssh
