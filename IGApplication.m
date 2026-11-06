#import "IGApplication.h"
#import "IGIcon.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *IGColor(NSInteger hex) {
    return [UIColor colorWithRed:((hex >> 16) & 255) / 255.0
                           green:((hex >> 8) & 255) / 255.0
                            blue:(hex & 255) / 255.0 alpha:1.0];
}
static UIColor *IGBlue(void) { return IGColor(0x3897F0); }
static UIColor *IGLine(void) { return IGColor(0xDBDBDB); }
static UIColor *IGMuted(void) { return IGColor(0x999999); }
static UIColor *IGSkeletonColor(void) { return IGColor(0xE8E8E8); }

static UIView *IGSkeleton(CGRect frame, CGFloat radius) {
    UIView *view = [[UIView alloc] initWithFrame:frame];
    view.backgroundColor = IGSkeletonColor();
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = YES;
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.58;
    pulse.toValue = @0.95;
    pulse.duration = 1.05;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [view.layer addAnimation:pulse forKey:@"ig.skeleton.pulse"];
    return view;
}

static UIImageView *IGIconView(NSString *name, CGRect frame, UIColor *color, BOOL selected) {
    UIImageView *view = [[UIImageView alloc] initWithFrame:frame];
    view.contentMode = UIViewContentModeScaleAspectFit;
    view.image = IGIconImage(name, color, MIN(frame.size.width, frame.size.height), selected);
    return view;
}

@interface IGNodeController : UIViewController
- (void)openNode:(NSString *)name;
- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size color:(UIColor *)color bold:(BOOL)bold;
- (void)addDividerAtY:(CGFloat)y;
@end

@interface IGFeedNode : IGNodeController @end
@interface IGExploreNode : IGNodeController @end
@interface IGActivityNode : IGNodeController @end
@interface IGProfileNode : IGNodeController @end
@interface IGSettingsNode : IGNodeController @end
@interface IGCommentsNode : IGNodeController @end
@interface IGVideoNode : IGNodeController @end
@interface IGPlaceholderNode : IGNodeController @end

@interface IGPostSkeleton : UIView
- (instancetype)initWithWidth:(CGFloat)width mediaHeight:(CGFloat)mediaHeight;
@end

@implementation IGPostSkeleton
- (instancetype)initWithWidth:(CGFloat)width mediaHeight:(CGFloat)mediaHeight {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.backgroundColor = UIColor.whiteColor;

        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 56)];
        [header addSubview:IGSkeleton(CGRectMake(12, 9, 38, 38), 19)];
        [header addSubview:IGSkeleton(CGRectMake(60, 14, MIN(116, width * 0.38), 10), 5)];
        [header addSubview:IGSkeleton(CGRectMake(60, 32, MIN(78, width * 0.26), 7), 3.5)];
        [header addSubview:IGIconView(@"more", CGRectMake(width - 38, 16, 26, 24), UIColor.blackColor, NO)];
        [self addSubview:header];

        UIView *media = IGSkeleton(CGRectMake(0, 56, width, mediaHeight), 0);
        UIImageView *camera = IGIconView(@"camera", CGRectMake((width - 28) / 2, 56 + (mediaHeight - 28) / 2, 28, 28), IGColor(0xBDBDBD), NO);
        [self addSubview:media];
        [self addSubview:camera];

        CGFloat y = 56 + mediaHeight;
        UIView *actions = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 42)];
        [actions addSubview:IGIconView(@"heart", CGRectMake(12, 7, 28, 28), UIColor.blackColor, NO)];
        UIButton *comments = [UIButton buttonWithType:UIButtonTypeCustom];
        comments.frame = CGRectMake(54, 7, 28, 28);
        [comments setImage:IGIconImage(@"comment", UIColor.blackColor, 28, NO) forState:UIControlStateNormal];
        [comments addTarget:self action:@selector(openComments) forControlEvents:UIControlEventTouchUpInside];
        [actions addSubview:comments];
        [actions addSubview:IGIconView(@"share", CGRectMake(96, 7, 28, 28), UIColor.blackColor, NO)];
        [self addSubview:actions];

        y += 42;
        [self addSubview:IGSkeleton(CGRectMake(14, y + 2, 86, 9), 4.5)];
        [self addSubview:IGSkeleton(CGRectMake(14, y + 22, width * 0.69, 8), 4)];
        [self addSubview:IGSkeleton(CGRectMake(14, y + 36, width * 0.46, 8), 4)];
        [self addSubview:IGSkeleton(CGRectMake(14, y + 54, width * 0.37, 7), 3.5)];
        self.frame = CGRectMake(0, 0, width, y + 74);
    }
    return self;
}
- (void)openComments {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"IGOpenComments" object:nil];
}
@end

@implementation IGNodeController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    self.navigationController.navigationBar.barTintColor = UIColor.whiteColor;
    self.navigationController.navigationBar.tintColor = UIColor.blackColor;
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSForegroundColorAttributeName: UIColor.blackColor,
        NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
    };
}
- (void)openNode:(NSString *)name {
    UIViewController *next = nil;
    if ([name isEqualToString:@"Comments"]) next = [IGCommentsNode new];
    else if ([name isEqualToString:@"Video"]) next = [IGVideoNode new];
    else if ([name isEqualToString:@"Options"]) next = [IGSettingsNode new];
    else next = [IGPlaceholderNode new];
    next.title = name;
    [self.navigationController pushViewController:next animated:YES];
}
- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size color:(UIColor *)color bold:(BOOL)bold {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    label.textColor = color;
    return label;
}
- (void)addDividerAtY:(CGFloat)y {
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, 0.5)];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    line.backgroundColor = IGLine();
    [self.view addSubview:line];
}
@end

@implementation IGFeedNode
- (void)viewDidLoad {
    [super viewDidLoad];
    UILabel *logo = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, 38)];
    logo.text = @"Instagram";
    logo.textAlignment = NSTextAlignmentCenter;
    logo.font = [UIFont fontWithName:@"Zapfino" size:19] ?: [UIFont italicSystemFontOfSize:22];
    logo.textColor = UIColor.blackColor;
    self.navigationItem.titleView = logo;

    UIButton *inbox = [UIButton buttonWithType:UIButtonTypeCustom];
    inbox.frame = CGRectMake(0, 0, 34, 34);
    [inbox setImage:IGIconImage(@"inbox", UIColor.blackColor, 26, NO) forState:UIControlStateNormal];
    [inbox addTarget:self action:@selector(openInbox) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:inbox];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    CGFloat width = scroll.bounds.size.width;
    CGFloat y = 0;
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat mediaHeight = i == 0 ? width * 0.62 : width;
        IGPostSkeleton *post = [[IGPostSkeleton alloc] initWithWidth:width mediaHeight:mediaHeight];
        post.frame = CGRectMake(0, y, width, post.frame.size.height);
        [scroll addSubview:post];
        y += post.frame.size.height;
    }
    scroll.contentSize = CGSizeMake(width, y);
}
- (void)openInbox { [self openNode:@"Messages"]; }
@end

@implementation IGExploreNode
- (void)viewDidLoad {
    [super viewDidLoad];

    UIView *search = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 32)];
    search.backgroundColor = IGColor(0xEFEFF1);
    search.layer.cornerRadius = 5;
    [search addSubview:IGIconView(@"search", CGRectMake(8, 7, 18, 18), IGMuted(), NO)];
    UILabel *searchText = [self label:@"Search" frame:CGRectMake(32, 0, 175, 32) size:15 color:IGMuted() bold:NO];
    [search addSubview:searchText];
    self.navigationItem.titleView = search;

    UIButton *people = [UIButton buttonWithType:UIButtonTypeCustom];
    people.frame = CGRectMake(0, 0, 34, 34);
    [people setImage:IGIconImage(@"addPerson", IGMuted(), 24, NO) forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:people];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    CGFloat y = 0;
    BOOL showReels = [[NSUserDefaults standardUserDefaults] objectForKey:@"IGShowReels"] == nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"IGShowReels"];
    if (showReels) {
        CGFloat width = self.view.bounds.size.width;
        UIButton *reels = [UIButton buttonWithType:UIButtonTypeCustom];
        reels.frame = CGRectMake(0, 0, width, 180);
        UIView *media = IGSkeleton(reels.bounds, 0);
        [reels addSubview:media];
        [reels addSubview:IGIconView(@"play", CGRectMake((width-42)/2, 44, 42, 42), IGMuted(), NO)];
        UILabel *label = [self label:@"REELS" frame:CGRectMake(14, 112, 140, 17) size:11 color:IGMuted() bold:YES];
        [reels addSubview:label];
        [reels addSubview:IGSkeleton(CGRectMake(14, 137, MIN(220, width-28), 12), 6)];
        [reels addTarget:self action:@selector(openReels) forControlEvents:UIControlEventTouchUpInside];
        [scroll addSubview:reels];
        y = CGRectGetMaxY(reels.frame);
    }

    CGFloat tileWidth = self.view.bounds.size.width / 3.0;
    NSInteger count = 18;
    for (NSInteger i = 0; i < count; i++) {
        NSInteger row = i / 3;
        NSInteger column = i % 3;
        CGRect frame = CGRectMake(column * tileWidth + 1, y + row * tileWidth + 1, tileWidth - 2, tileWidth - 2);
        UIView *tile = IGSkeleton(frame, 0);
        [scroll addSubview:tile];
    }
    scroll.contentSize = CGSizeMake(self.view.bounds.size.width, y + ceil(count / 3.0) * tileWidth);
}
- (void)openReels { [self openNode:@"Video"]; }
@end

@implementation IGActivityNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Activity";
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = 6;
    for (NSInteger i = 0; i < 8; i++) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 68)];
        [row addSubview:IGSkeleton(CGRectMake(14, 10, 46, 46), 23)];
        [row addSubview:IGSkeleton(CGRectMake(72, 14, width * 0.51, 9), 4.5)];
        [row addSubview:IGSkeleton(CGRectMake(72, 32, width * 0.35, 8), 4)];
        [row addSubview:IGSkeleton(CGRectMake(width-56, 11, 42, 42), 1)];
        [scroll addSubview:row];
        y += 68;
        [self addDividerAtY:y];
    }
    scroll.contentSize = CGSizeMake(width, y);
}
@end

@implementation IGProfileNode
- (void)viewDidLoad {
    [super viewDidLoad];

    UIView *title = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 170, 34)];
    [title addSubview:IGSkeleton(CGRectMake(4, 12, 116, 10), 5)];
    self.navigationItem.titleView = title;
    UIButton *settings = [UIButton buttonWithType:UIButtonTypeCustom];
    settings.frame = CGRectMake(0, 0, 34, 34);
    [settings setImage:IGIconImage(@"settings", UIColor.blackColor, 24, NO) forState:UIControlStateNormal];
    [settings addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:settings];

    CGFloat width = self.view.bounds.size.width;
    UIView *summary = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 145)];
    [summary addSubview:IGSkeleton(CGRectMake(16, 20, 82, 82), 41)];
    CGFloat statsX = 112;
    CGFloat statsWidth = (width - statsX) / 3.0;
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat x = statsX + i * statsWidth;
        [summary addSubview:IGSkeleton(CGRectMake(x + (statsWidth-30)/2, 27, 30, 10), 5)];
        [summary addSubview:IGSkeleton(CGRectMake(x + (statsWidth-40)/2, 49, 40, 7), 3.5)];
    }
    [summary addSubview:IGSkeleton(CGRectMake(statsX, 78, width-statsX-14, 30), 3)];
    [self.view addSubview:summary];

    [self.view addSubview:IGSkeleton(CGRectMake(15, 154, MIN(width-30, 128), 11), 5.5)];
    [self.view addSubview:IGSkeleton(CGRectMake(15, 181, width-30, 8), 4)];
    [self.view addSubview:IGSkeleton(CGRectMake(15, 197, width*0.63, 8), 4)];

    UIView *selector = [[UIView alloc] initWithFrame:CGRectMake(0, 218, width, 44)];
    NSArray *names = @[@"grid", @"list", @"pin", @"tagged"];
    for (NSInteger i = 0; i < names.count; i++) {
        UIColor *color = i == 0 ? IGBlue() : IGMuted();
        UIImageView *icon = IGIconView(names[i], CGRectMake(i*width/4 + (width/4-22)/2, 10, 22, 22), color, i == 0);
        [selector addSubview:icon];
    }
    [self.view addSubview:selector];
    [self addDividerAtY:262];

    UIScrollView *grid = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 263, width, self.view.bounds.size.height-263)];
    grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:grid];
    CGFloat tileWidth = width / 3.0;
    for (NSInteger i = 0; i < 18; i++) {
        CGRect frame = CGRectMake((i%3)*tileWidth+1, (i/3)*tileWidth+1, tileWidth-2, tileWidth-2);
        [grid addSubview:IGSkeleton(frame, 0)];
    }
    grid.contentSize = CGSizeMake(width, 6*tileWidth);
}
- (void)openSettings { [self openNode:@"Options"]; }
@end

@implementation IGSettingsNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Options";
    UIView *section = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 48)];
    [section addSubview:[self label:@"FEED" frame:CGRectMake(16, 18, 200, 20) size:12 color:IGMuted() bold:YES]];
    [self.view addSubview:section];
    [self addDividerAtY:48];
    [self.view addSubview:[self label:@"Show Reels in Explore" frame:CGRectMake(16, 61, 250, 28) size:15 color:UIColor.blackColor bold:NO]];
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-66, 58, 51, 31)];
    toggle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    toggle.on = [[NSUserDefaults standardUserDefaults] objectForKey:@"IGShowReels"] == nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"IGShowReels"];
    [toggle addTarget:self action:@selector(toggleReels:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:toggle];
    [self addDividerAtY:100];
    UILabel *hint = [self label:@"Hides the Reels shelf from Explore." frame:CGRectMake(16, 108, self.view.bounds.size.width-32, 42) size:12 color:IGMuted() bold:NO];
    hint.numberOfLines = 2;
    [self.view addSubview:hint];
}
- (void)toggleReels:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"IGShowReels"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

@implementation IGCommentsNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Comments";
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = 4;
    for (NSInteger i = 0; i < 8; i++) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 64)];
        [row addSubview:IGSkeleton(CGRectMake(14, 11, 40, 40), 20)];
        [row addSubview:IGSkeleton(CGRectMake(66, 13, width*0.38, 9), 4.5)];
        [row addSubview:IGSkeleton(CGRectMake(66, 31, width*0.66, 8), 4)];
        [self.view addSubview:row];
        y += 64;
        [self addDividerAtY:y];
    }
}
@end

@implementation IGVideoNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Reels";
    UIView *media = IGSkeleton(self.view.bounds, 0);
    media.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:media];
    UIImageView *play = IGIconView(@"play", CGRectMake(0, 0, 54, 54), IGMuted(), NO);
    play.center = self.view.center;
    play.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:play];
}
@end

@implementation IGPlaceholderNode
- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:IGSkeleton(CGRectMake(24, 110, self.view.bounds.size.width-48, 12), 6)];
    [self.view addSubview:IGSkeleton(CGRectMake(42, 132, self.view.bounds.size.width-84, 8), 4)];
}
@end

@implementation IGApplicationController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.viewControllers = @[
        [self nav:[IGFeedNode new] title:@"Home" icon:@"home"],
        [self nav:[IGExploreNode new] title:@"Search" icon:@"search"],
        [self nav:[IGPlaceholderNode new] title:@"Camera" icon:@"camera"],
        [self nav:[IGActivityNode new] title:@"Activity" icon:@"heart"],
        [self nav:[IGProfileNode new] title:@"Profile" icon:@"profile"]
    ];
    self.selectedIndex = 0;
    self.tabBar.tintColor = UIColor.blackColor;
    self.tabBar.barTintColor = UIColor.whiteColor;
    self.tabBar.translucent = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeToComments) name:@"IGOpenComments" object:nil];
}
- (UINavigationController *)nav:(UIViewController *)root title:(NSString *)title icon:(NSString *)icon {
    root.title = title;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    navigation.tabBarItem.title = @"";
    navigation.tabBarItem.image = IGIconImage(icon, IGMuted(), 26, NO);
    navigation.tabBarItem.selectedImage = IGIconImage(icon, UIColor.blackColor, 26, YES);
    return navigation;
}
- (void)routeToComments {
    UINavigationController *navigation = (UINavigationController *)self.selectedViewController;
    if (![navigation.topViewController isKindOfClass:[IGCommentsNode class]]) {
        IGCommentsNode *comments = [IGCommentsNode new];
        comments.title = @"Comments";
        [navigation pushViewController:comments animated:YES];
    }
}
@end
