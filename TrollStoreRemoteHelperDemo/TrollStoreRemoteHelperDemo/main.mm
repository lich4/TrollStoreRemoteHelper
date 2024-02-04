#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : UIViewController<UIApplicationDelegate, UIWindowSceneDelegate, WKNavigationDelegate>
@property(strong, nonatomic) UIWindow* window;
@property(retain) WKWebView* webview;
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
        WKWebViewConfiguration* conf = [WKWebViewConfiguration new];
        WKWebView* webview = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) configuration:conf];
        webview.navigationDelegate = self;
        self.webview = webview;

        NSString* wwwpath = [NSString stringWithFormat:@"%@/www/index.html", NSBundle.mainBundle.bundlePath];
        NSURL* url = [NSURL URLWithString:wwwpath];
        NSURLRequest* req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.0];;
        [webview loadRequest:req];
    }
}
- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation {
    [self.window addSubview:webView];
    [self.window bringSubviewToFront:webView];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}

