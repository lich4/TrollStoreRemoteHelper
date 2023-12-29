#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define USE_WKWEBVIEW

#ifdef USE_WKWEBVIEW
#import <WebKit/WebKit.h> // 如果使用UIWebView,TrollStore安装IPA后无法显示Web页面,整个是灰的(普通安装没该问题的),bug?
#endif

static NSString* log_prefix = @"TrollStoreRemoteHelper";

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

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}

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

#import <GCDWebServers/GCDWebServers.h>
#include "utils.h"

#define G_PORT 1222

@implementation MainWin {
    unsigned short port;
    WebviewDelegate* delegate;
    NSMutableArray* logList;
    NSString* helper;
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
    self->logList = [NSMutableArray new];
    self->port = G_PORT;
    self->helper = [self findHelper];
    return self;
}
- (void)initServer {
    static GCDWebServer* _webServer = nil;
    if (_webServer == nil) {
        _webServer = [GCDWebServer new];
        NSString* html_root = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"www"];
        [_webServer addGETHandlerForBasePath:@"/" directoryPath:html_root indexFilename:nil cacheAge:3600 allowRangeRequests:YES];
        [_webServer addDefaultHandlerForMethod:@"PUT" requestClass:GCDWebServerDataRequest.class processBlock:^GCDWebServerResponse*(GCDWebServerDataRequest* request) {
            int status = [self handlePUT:request.path with:request.data];
            return [GCDWebServerResponse responseWithStatusCode:status];
        }];
        [_webServer addDefaultHandlerForMethod:@"POST" requestClass:GCDWebServerRequest.class processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
            NSDictionary* jres = [self handlePOST:request.path];
            return [GCDWebServerDataResponse responseWithJSONObject:jres];
        }];
        NSString* localIP = getLocalIP();
        [self addLog:@"TrollStoreRemoteHelper pid=%d listen=%@:%d", getpid(), localIP, self->port];
        [_webServer startWithPort:self->port bonjourName:nil];
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
            NSURL* nsurl = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/index.html", self->port]];
            NSURLRequest* req = [NSURLRequest requestWithURL:nsurl];
            [web loadRequest:req];
        }
        return self;
    }
}
- (NSString*)findHelper {
    NSString* bundlePath = getTrollStoreBundlePath();
    if (bundlePath == nil) {
        [self addLog:@"helper not find"];
        return nil;
    }
    NSString* path = [bundlePath stringByAppendingPathComponent:@"trollstorehelper"];
    [self addLog:@"helper find: %@", path];
    return path;
}
- (void)addLog:(NSString*)fmt, ... {
    va_list va;
    va_start(va, fmt);
    NSString* log = [[NSString alloc] initWithFormat:fmt arguments:va];
    NSDateFormatter* dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* dateStr = [dateFormatter stringFromDate:[NSDate date]];
    [self->logList addObject:[NSString stringWithFormat:@"%@\t%@", dateStr, log]];
}
- (NSDictionary*)handlePOST:(NSString*)path {
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
- (int)handlePUT:(NSString*)path with:(NSData*)data { // for install ipa
    @autoreleasepool {
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
        int status = spawnRoot(self->helper, @[@"install", filePath], nil, nil); // 需要先卸载吗?
        if (status != 0) {
            [self addLog:@"install failed %d: %@", status, fileName];
            return 412;
        }
        [self addLog:@"install success %@", fileName];
        return 200;
    }
}
@end

