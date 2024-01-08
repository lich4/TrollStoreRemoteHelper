#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define USE_WKWEBVIEW

#ifdef USE_WKWEBVIEW
#import <WebKit/WebKit.h> // 如果使用UIWebView,TrollStore安装IPA后无法显示Web页面,整个是灰的(普通安装没该问题的),bug?
#endif

static NSString* log_prefix = @"TrollStoreRemoteLogger";

@interface MainWin : NSObject
+ (instancetype)inst;
- (instancetype)init;
- (instancetype)initWithWindow:(UIWindow*)window;
@property(retain) UIWindow* window;
@end

@interface SceneDelegate : UIResponder<UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow * window;
@end

@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
}
- (void)sceneDidDisconnect:(UIScene *)scene {
}
- (void)sceneWillResignActive:(UIScene *)scene {
}
- (void)sceneWillEnterForeground:(UIScene *)scene {
}
- (void)sceneDidEnterBackground:(UIScene *)scene {
}
- (void)sceneDidBecomeActive:(UIScene *)scene {
    @autoreleasepool {
        [MainWin.inst initWithWindow:self.window];
    }
}
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext*>*)URLContexts {
}
@end

@interface AppDelegate : UIResponder<UIApplicationDelegate>
@property (strong, nonatomic) UIWindow * window;
@end

@implementation AppDelegate
@synthesize window = _window;
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    @autoreleasepool {
        return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
    }
}
- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    @autoreleasepool {
        [MainWin.inst initWithWindow:self.window];
        return YES;
    }
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    return YES;
}
@end

@interface ViewController : UIViewController
@end
@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
}
@end

#ifdef USE_WKWEBVIEW
@interface WebviewDelegate : UIViewController <WKNavigationDelegate>
#else
@interface WebviewDelegate : UIViewController <UIWebViewDelegate>
#endif
@property(retain) UIWindow* window;
@property(retain) UIView* webview;
#ifdef USE_WKWEBVIEW
- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation *)navigation;
#else
- (void)webViewDidFinishLoad:(UIWebView *)webView;
#endif
@end

@implementation WebviewDelegate
#ifdef USE_WKWEBVIEW
- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.window bringSubviewToFront:self.webview];
}
#else
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self.window bringSubviewToFront:self.webview];
}
#endif
@end


#include "utils.h"
#import <GCDWebServers/GCDWebServers.h>
#define GSERV_PORT      1222
#define GSSHD_PORT      1223

@implementation MainWin {
    WebviewDelegate* delegate;
}
+ (instancetype)inst {
    static dispatch_once_t pred = 0;
    static MainWin* inst_ = nil;
    dispatch_once(&pred, ^{
        inst_ = [self new];
    });
    return inst_;
}
- (instancetype)init {
    self = super.init;
    self.window = nil;
    return self;
}
- (void)initServer {
    static bool serv_inited = false;
    if (!serv_inited) {
        serv_inited = true;
        pid_t pid_serv = -1;
        int status = spawn(@[getAppEXEPath(), @"serve"], nil, nil, &pid_serv, SPAWN_FLAG_ROOT | SPAWN_FLAG_NOWAIT);
        NSLog(@"%@ spawn server status=%d pid=%d", log_prefix, status, pid_serv);
    }
}
- (instancetype)initWithWindow:(UIWindow*)window_ {
    @autoreleasepool {
        [self initServer];
        if (self.window == nil) {
            self.window = window_;
            CGSize size = UIScreen.mainScreen.bounds.size;
            NSString* imgpath = [NSString stringWithFormat:@"%@/splash.png", NSBundle.mainBundle.bundlePath];
            UIImageView* imgview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
            imgview.image = [UIImage imageWithContentsOfFile:imgpath];
            [self.window addSubview:imgview];
#ifdef USE_WKWEBVIEW
            WKWebView* web = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
#else
            UIWebView* web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
#endif
            [self.window addSubview:web];
            self->delegate = [WebviewDelegate new];
            self->delegate.window = self.window;
            self->delegate.webview = web;
#ifdef USE_WKWEBVIEW
            web.navigationDelegate = self->delegate;
#else
            web.delegate = self->delegate;
#endif
            NSURL* nsurl = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/index.html", GSERV_PORT]];
            NSURLRequest* req = [NSURLRequest requestWithURL:nsurl];
            [web loadRequest:req];
        }
        return self;
    }
}
@end


@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString* bundleIdentifier;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (void)addObserver:(id)observer;
- (void)removeObserver:(id)observer;
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
            int status = spawn(@[@"dropbear", @"-p", [@GSSHD_PORT stringValue], @"-F", @"-S", root_path], nil, nil, &self->pid_sshd, SPAWN_FLAG_NOWAIT);
            NSLog(@"%@ spawn sshd status=%d pid=%d", log_prefix, status, self->pid_sshd);
        } else {
            [self addLog:@"sshd listen=%@:%d", localIP, GSSHD_PORT];
        }
        static GCDWebServer* _webServer = nil;
        if (_webServer == nil) {
            if (localPortOpen(GSERV_PORT)) {
                NSLog(@"%@ already served, exit", log_prefix);
                exit(0); // 服务已存在,退出
            }
            _webServer = [GCDWebServer new];
            NSString* html_root = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"www"];
            [_webServer addGETHandlerForBasePath:@"/" directoryPath:html_root indexFilename:nil cacheAge:3600 allowRangeRequests:YES];
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

int main(int argc, char** argv) {
    @autoreleasepool {
        if (argc == 1) {
            NSString * appDelegateClassName = NSStringFromClass([AppDelegate class]);
            return UIApplicationMain(argc, argv, nil, appDelegateClassName);
        }
        if (0 == strcmp(argv[1], "serve")) {
            runAsDaemon(^{ // 防止App退出后被杀
                [Service.inst serve];
                [NSRunLoop.mainRunLoop run];
            });
            return 0;
        }
        return -1;
    }
}

