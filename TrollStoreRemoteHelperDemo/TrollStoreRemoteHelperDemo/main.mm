#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface MainWin : UIViewController<WKNavigationDelegate, WKScriptMessageHandler>
+ (instancetype)inst;
- (instancetype)init;
- (void)initWithWindow:(UIWindow*)window;
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
@end

@implementation MainWin {
    WKWebView* webview;
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
- (void)initWithWindow:(UIWindow*)window_ {
    @autoreleasepool {
        if (self.window != nil) {
            return;
        }
        self.window = window_;
        CGSize size = UIScreen.mainScreen.bounds.size;
        NSString* imgpath = [NSString stringWithFormat:@"%@/splash.png", NSBundle.mainBundle.bundlePath];
        UIImageView* imgview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        imgview.image = [UIImage imageWithContentsOfFile:imgpath];
        [self.window addSubview:imgview];
        
        WKWebView* webview = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        [self.window addSubview:webview];
        webview.navigationDelegate = self;
        self->webview = webview;
        NSString* wwwpath = [NSString stringWithFormat:@"%@/www/index.html", NSBundle.mainBundle.bundlePath];
        NSURL* url = [NSURL fileURLWithPath:wwwpath];
        NSURLRequest* req = [NSURLRequest requestWithURL:url];
        [webview loadRequest:req];
    }
}
- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.window bringSubviewToFront:self->webview];
}
@end

int main(int argc, char * argv[]) {
    return UIApplicationMain(argc, argv, nil, @"AppDelegate");
}

