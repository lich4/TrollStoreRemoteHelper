#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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


@implementation MainWin
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
- (instancetype)initWithWindow:(UIWindow*)window_ {
    @autoreleasepool {
        if (self.window == nil) {
            self.window = window_;
            CGSize size = UIScreen.mainScreen.bounds.size;
            UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
            label.text = @"Hello World!!!";
            [self.window addSubview:label];
        }
        return self;
    }
}
@end

