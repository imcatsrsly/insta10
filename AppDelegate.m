#import "IGApplication.h"
#import "IGApplication.h"

@implementation IGAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [[IGApplicationController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
