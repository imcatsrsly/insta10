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
static NSString * const IGTextModeDidChangeNotification = @"IGTextModeDidChange";
static BOOL IGTextDemoEnabled(void) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"IGTextDemoMode"];
    return value == nil || [value boolValue];
}

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
    view.tintColor = color;
    return view;
}

@interface IGNodeController : UIViewController
- (void)openNode:(NSString *)name;
- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size color:(UIColor *)color bold:(BOOL)bold;
- (void)addDividerAtY:(CGFloat)y;
@end

@interface IGFeedNode : IGNodeController
@property (nonatomic, strong) UIScrollView *feedScroll;
- (void)rebuildFeed;
@end
@interface IGExploreNode : IGNodeController @end
@interface IGActivityNode : IGNodeController
@property (nonatomic, strong) UIScrollView *activityScroll;
- (void)renderActivity;
@end
@interface IGProfileNode : IGNodeController
- (void)renderProfile;
@end
@interface IGSettingsNode : IGNodeController @end
@interface IGCommentsNode : IGNodeController
@property (nonatomic, strong) UIView *composerBar;
@property (nonatomic, strong) UIScrollView *commentsScroll;
- (void)renderComments;
@end
@interface IGVideoNode : IGNodeController @end
@interface IGSearchNode : IGNodeController
@property (nonatomic, strong) UIView *tabUnderline;
@property (nonatomic, strong) UIView *results;
@property (nonatomic, assign) NSInteger selectedSearchTab;
@end
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
        if (IGTextDemoEnabled()) {
            UILabel *username = [[UILabel alloc] initWithFrame:CGRectMake(60, 11, MIN(150, width-110), 24)];
            username.text = @"null";
            username.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            username.textColor = UIColor.blackColor;
            [header addSubview:username];
        } else {
            [header addSubview:IGSkeleton(CGRectMake(60, 14, MIN(116, width * 0.38), 10), 5)];
            [header addSubview:IGSkeleton(CGRectMake(60, 32, MIN(78, width * 0.26), 7), 3.5)];
        }
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
        if (IGTextDemoEnabled()) {
            UILabel *likes = [[UILabel alloc] initWithFrame:CGRectMake(14, y, width-28, 21)];
            likes.text = @"0 likes";
            likes.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            likes.textColor = UIColor.blackColor;
            [self addSubview:likes];

            UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(14, y+23, width-28, 20)];
            caption.text = @"null  null";
            caption.font = [UIFont systemFontOfSize:14];
            caption.textColor = UIColor.blackColor;
            [self addSubview:caption];

            UILabel *commentsCount = [[UILabel alloc] initWithFrame:CGRectMake(14, y+43, width-28, 18)];
            commentsCount.text = @"View all 0 comments";
            commentsCount.font = [UIFont systemFontOfSize:14];
            commentsCount.textColor = IGMuted();
            [self addSubview:commentsCount];
            self.frame = CGRectMake(0, 0, width, y + 70);
        } else {
            [self addSubview:IGSkeleton(CGRectMake(14, y + 2, 86, 9), 4.5)];
            [self addSubview:IGSkeleton(CGRectMake(14, y + 22, width * 0.69, 8), 4)];
            [self addSubview:IGSkeleton(CGRectMake(14, y + 36, width * 0.46, 8), 4)];
            [self addSubview:IGSkeleton(CGRectMake(14, y + 54, width * 0.37, 7), 3.5)];
            self.frame = CGRectMake(0, 0, width, y + 74);
        }
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
    else if ([name isEqualToString:@"Search"]) next = [IGSearchNode new];
    else if ([name isEqualToString:@"Options"]) next = [IGSettingsNode new];
    else next = [IGPlaceholderNode new];
    next.title = name;
    if ([name isEqualToString:@"Comments"]) next.hidesBottomBarWhenPushed = YES;
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
    UIImageView *logo = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 103, 30)];
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.image = [[UIImage imageNamed:@"logotype-feed"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    self.navigationItem.titleView = logo;

    UIButton *inbox = [UIButton buttonWithType:UIButtonTypeCustom];
    inbox.frame = CGRectMake(0, 0, 34, 34);
    inbox.tintColor = UIColor.blackColor;
    [inbox setImage:IGIconImage(@"inbox", UIColor.blackColor, 26, NO) forState:UIControlStateNormal];
    [inbox addTarget:self action:@selector(openInbox) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:inbox];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    self.feedScroll = scroll;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textModeChanged) name:IGTextModeDidChangeNotification object:nil];
    [self rebuildFeed];
}
- (void)rebuildFeed {
    [self.feedScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.feedScroll.bounds.size.width;
    CGFloat y = 0;
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat mediaHeight = i == 0 ? width * 0.62 : width;
        IGPostSkeleton *post = [[IGPostSkeleton alloc] initWithWidth:width mediaHeight:mediaHeight];
        post.frame = CGRectMake(0, y, width, post.frame.size.height);
        [self.feedScroll addSubview:post];
        y += post.frame.size.height;
    }
    self.feedScroll.contentSize = CGSizeMake(width, y);
}
- (void)textModeChanged { [self rebuildFeed]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)openInbox { [self openNode:@"Messages"]; }
@end

@implementation IGExploreNode
- (void)viewDidLoad {
    [super viewDidLoad];

    UIControl *search = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 220, 32)];
    search.backgroundColor = IGColor(0xEFEFF1);
    search.layer.cornerRadius = 5;
    [search addTarget:self action:@selector(openSearch) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *magnifier = [[UIImageView alloc] initWithFrame:CGRectMake(8, 7, 18, 18)];
    magnifier.contentMode = UIViewContentModeScaleAspectFit;
    magnifier.image = [[UIImage imageNamed:@"searchbar-mag-glass"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [search addSubview:magnifier];
    UILabel *searchText = [self label:@"Search" frame:CGRectMake(32, 0, 175, 32) size:15 color:IGMuted() bold:NO];
    searchText.userInteractionEnabled = NO;
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
- (void)openSearch { [self openNode:@"Search"]; }
@end

@implementation IGSearchNode
- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat width = self.view.bounds.size.width;
    UIView *searchField = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 32)];
    searchField.backgroundColor = IGColor(0xEFEFF1);
    searchField.layer.cornerRadius = 5;
    UIImageView *magnifier = [[UIImageView alloc] initWithFrame:CGRectMake(8, 7, 18, 18)];
    magnifier.contentMode = UIViewContentModeScaleAspectFit;
    magnifier.image = [[UIImage imageNamed:@"searchbar-mag-glass-on"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [searchField addSubview:magnifier];
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(32, 0, 180, 32)];
    field.placeholder = @"Search places";
    field.font = [UIFont systemFontOfSize:15];
    [searchField addSubview:field];
    self.navigationItem.titleView = searchField;
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelSearch)];
    self.navigationItem.rightBarButtonItem = cancel;

    UIView *tabs = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 52)];
    NSArray *titles = @[@"Top", @"People", @"Tags", @"Places"];
    for (NSInteger i=0; i<titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(i*width/4, 0, width/4, 51);
        button.tag = i;
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:i == 3 ? UIColor.blackColor : IGMuted() forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:15];
        [button addTarget:self action:@selector(selectSearchTab:) forControlEvents:UIControlEventTouchUpInside];
        [tabs addSubview:button];
    }
    self.tabUnderline = [[UIView alloc] initWithFrame:CGRectMake(width*3/4, 50, width/4, 2)];
    self.tabUnderline.backgroundColor = UIColor.blackColor;
    [tabs addSubview:self.tabUnderline];
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(0, 51.5, width, 0.5)];
    divider.backgroundColor = IGLine();
    [tabs addSubview:divider];
    [self.view addSubview:tabs];

    self.results = [[UIView alloc] initWithFrame:CGRectMake(0, 52, width, self.view.bounds.size.height-52)];
    [self.view addSubview:self.results];
    [self showPlacesResult];
}
- (void)showPlacesResult {
    [self.results.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.results.bounds.size.width;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 64)];
    UIImageView *pin = [[UIImageView alloc] initWithFrame:CGRectMake(22, 18, 24, 24)];
    pin.contentMode = UIViewContentModeScaleAspectFit;
    pin.image = [[UIImage imageNamed:@"search-location-filled"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [row addSubview:pin];
    UILabel *label = [self label:@"Near Current Location" frame:CGRectMake(68, 0, width-78, 64) size:16 color:IGBlue() bold:NO];
    [row addSubview:label];
    row.backgroundColor = IGColor(0xF5F5F7);
    [self.results addSubview:row];
}
- (void)selectSearchTab:(UIButton *)sender {
    self.selectedSearchTab = sender.tag;
    CGFloat width = self.view.bounds.size.width;
    [UIView animateWithDuration:0.18 animations:^{
        self.tabUnderline.frame = CGRectMake(sender.tag*width/4, 50, width/4, 2);
    }];
    for (UIView *view in sender.superview.subviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)view;
            [button setTitleColor:button.tag == sender.tag ? UIColor.blackColor : IGMuted() forState:UIControlStateNormal];
        }
    }
    if (sender.tag == 3) [self showPlacesResult];
    else {
        [self.results.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        CGFloat width = self.results.bounds.size.width;
        for (NSInteger i=0; i<5; i++) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, i*62, width, 62)];
            [row addSubview:IGSkeleton(CGRectMake(14, 9, 44, 44), 22)];
            [row addSubview:IGSkeleton(CGRectMake(72, 18, width*0.46, 9), 4.5)];
            [row addSubview:IGSkeleton(CGRectMake(72, 37, width*0.30, 7), 3.5)];
            [self.results addSubview:row];
        }
    }
}
- (void)cancelSearch { [self.navigationController popViewControllerAnimated:YES]; }
@end

@implementation IGActivityNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Activity";
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    self.activityScroll = scroll;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renderActivity) name:IGTextModeDidChangeNotification object:nil];
    [self renderActivity];
}
- (void)renderActivity {
    [self.activityScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = 6;
    for (NSInteger i = 0; i < 8; i++) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 68)];
        [row addSubview:IGSkeleton(CGRectMake(14, 10, 46, 46), 23)];
        if (IGTextDemoEnabled()) {
            [row addSubview:[self label:@"null" frame:CGRectMake(72, 10, width-140, 20) size:14 color:UIColor.blackColor bold:YES]];
            [row addSubview:[self label:@"0 likes" frame:CGRectMake(72, 31, width-140, 20) size:13 color:IGMuted() bold:NO]];
        } else {
            [row addSubview:IGSkeleton(CGRectMake(72, 14, width * 0.51, 9), 4.5)];
            [row addSubview:IGSkeleton(CGRectMake(72, 32, width * 0.35, 8), 4)];
        }
        [row addSubview:IGSkeleton(CGRectMake(width-56, 11, 42, 42), 1)];
        [self.activityScroll addSubview:row];
        y += 68;
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(72, y, width-72, 0.5)];
        line.backgroundColor = IGLine();
        [self.activityScroll addSubview:line];
    }
    self.activityScroll.contentSize = CGSizeMake(width, y);
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

@implementation IGProfileNode
- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *settings = [UIButton buttonWithType:UIButtonTypeCustom];
    settings.frame = CGRectMake(0, 0, 34, 34);
    [settings setImage:IGIconImage(@"settings", UIColor.blackColor, 24, NO) forState:UIControlStateNormal];
    [settings addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:settings];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renderProfile) name:IGTextModeDidChangeNotification object:nil];
    [self renderProfile];
}
- (void)renderProfile {
    [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    BOOL textMode = IGTextDemoEnabled();
    CGFloat width = self.view.bounds.size.width;
    UIView *title = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 170, 34)];
    if (textMode) {
        UILabel *username = [[UILabel alloc] initWithFrame:title.bounds];
        username.text = @"null";
        username.textAlignment = NSTextAlignmentCenter;
        username.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        username.textColor = UIColor.blackColor;
        [title addSubview:username];
    } else {
        [title addSubview:IGSkeleton(CGRectMake(4, 12, 116, 10), 5)];
    }
    self.navigationItem.titleView = title;

    UIView *summary = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 145)];
    [summary addSubview:IGSkeleton(CGRectMake(16, 20, 82, 82), 41)];
    CGFloat statsX = 112;
    CGFloat statsWidth = (width - statsX) / 3.0;
    NSArray *statNames = @[@"posts", @"followers", @"following"];
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat x = statsX + i * statsWidth;
        if (textMode) {
            UILabel *count = [[UILabel alloc] initWithFrame:CGRectMake(x, 20, statsWidth, 25)];
            count.text = @"0";
            count.textAlignment = NSTextAlignmentCenter;
            count.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
            count.textColor = UIColor.blackColor;
            [summary addSubview:count];
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(x, 46, statsWidth, 20)];
            label.text = statNames[i];
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont systemFontOfSize:12];
            label.textColor = IGMuted();
            [summary addSubview:label];
        } else {
            [summary addSubview:IGSkeleton(CGRectMake(x + (statsWidth-30)/2, 27, 30, 10), 5)];
            [summary addSubview:IGSkeleton(CGRectMake(x + (statsWidth-40)/2, 49, 40, 7), 3.5)];
        }
    }
    if (textMode) {
        UIButton *edit = [UIButton buttonWithType:UIButtonTypeCustom];
        edit.frame = CGRectMake(statsX, 78, width-statsX-14, 30);
        edit.backgroundColor = IGColor(0xF5F5F7);
        edit.layer.cornerRadius = 3;
        [edit setTitle:@"Edit Profile" forState:UIControlStateNormal];
        [edit setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        edit.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [summary addSubview:edit];
    } else {
        [summary addSubview:IGSkeleton(CGRectMake(statsX, 78, width-statsX-14, 30), 3)];
    }
    [self.view addSubview:summary];

    if (textMode) {
        [self.view addSubview:[self label:@"null" frame:CGRectMake(15, 150, width-30, 22) size:15 color:UIColor.blackColor bold:YES]];
        [self.view addSubview:[self label:@"null" frame:CGRectMake(15, 177, width-30, 20) size:14 color:UIColor.blackColor bold:NO]];
    } else {
        [self.view addSubview:IGSkeleton(CGRectMake(15, 154, MIN(width-30, 128), 11), 5.5)];
        [self.view addSubview:IGSkeleton(CGRectMake(15, 181, width-30, 8), 4)];
        [self.view addSubview:IGSkeleton(CGRectMake(15, 197, width*0.63, 8), 4)];
    }

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
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)openSettings { [self openNode:@"Options"]; }
@end

@implementation IGSettingsNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Options";
    CGFloat width = self.view.bounds.size.width;
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    CGFloat y = 0;

    NSArray *sections = @[
        @{@"title": @"FOLLOW PEOPLE", @"rows": @[@"Facebook Friends", @"Find Contacts", @"Invite Facebook Friends"]},
        @{@"title": @"ACCOUNT", @"rows": @[@"Edit Profile", @"Change Password", @"Posts You've Liked", @"Two-Factor Authentication"]}
    ];
    for (NSDictionary *section in sections) {
        UIView *heading = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 42)];
        heading.backgroundColor = IGColor(0xFAFAFA);
        [heading addSubview:[self label:section[@"title"] frame:CGRectMake(16, 16, width-32, 18) size:12 color:IGMuted() bold:YES]];
        [scroll addSubview:heading];
        y += 42;
        for (NSString *title in section[@"rows"]) {
            BOOL invite = [title hasPrefix:@"Invite"];
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 54)];
            UILabel *label = [self label:title frame:CGRectMake(16, 0, width-52, 54) size:15 color:invite ? IGColor(0x3F5F8A) : IGColor(0x262626) bold:NO];
            label.center = CGPointMake(label.center.x, 27);
            [row addSubview:label];
            if (!invite) {
                UIImageView *chevron = [[UIImageView alloc] initWithFrame:CGRectMake(width-32, 19, 12, 16)];
                chevron.contentMode = UIViewContentModeScaleAspectFit;
                chevron.image = [[UIImage imageNamed:@"chevron-settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
                [row addSubview:chevron];
            }
            [scroll addSubview:row];
            y += 54;
            UIView *line = [[UIView alloc] initWithFrame:CGRectMake(16, y, width-16, 0.5)];
            line.backgroundColor = IGLine();
            [scroll addSubview:line];
        }
        y += 18;
    }

    UIView *account = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 52)];
    [account addSubview:[self label:@"Private Account" frame:CGRectMake(16, 0, width-90, 52) size:15 color:IGColor(0x262626) bold:NO]];
    UISwitch *privateSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width-66, 10, 51, 31)];
    privateSwitch.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [account addSubview:privateSwitch];
    [scroll addSubview:account];
    y += 52;
    UILabel *privacyHint = [self label:@"When your account is private, only people you approve can see your photos and videos." frame:CGRectMake(16, y, width-32, 54) size:12 color:IGMuted() bold:NO];
    privacyHint.numberOfLines = 3;
    [scroll addSubview:privacyHint];
    y += 72;

    UIView *settingsHeader = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 42)];
    settingsHeader.backgroundColor = IGColor(0xFAFAFA);
    [settingsHeader addSubview:[self label:@"SETTINGS" frame:CGRectMake(16, 16, width-32, 18) size:12 color:IGMuted() bold:YES]];
    [scroll addSubview:settingsHeader];
    y += 42;
    UIView *reelsRow = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 54)];
    [reelsRow addSubview:[self label:@"Show Reels in Explore" frame:CGRectMake(16, 0, width-90, 54) size:15 color:IGColor(0x262626) bold:NO]];
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(width-66, 11, 51, 31)];
    toggle.transform = CGAffineTransformMakeScale(0.9, 0.9);
    toggle.on = [[NSUserDefaults standardUserDefaults] objectForKey:@"IGShowReels"] == nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"IGShowReels"];
    [toggle addTarget:self action:@selector(toggleReels:) forControlEvents:UIControlEventValueChanged];
    [reelsRow addSubview:toggle];
    [scroll addSubview:reelsRow];
    y += 54;
    UILabel *hint = [self label:@"Hides the Reels shelf from Explore." frame:CGRectMake(16, y, width-32, 34) size:12 color:IGMuted() bold:NO];
    [scroll addSubview:hint];
    y += 38;
    UIView *textModeRow = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 54)];
    [textModeRow addSubview:[self label:@"Text demo mode" frame:CGRectMake(16, 0, width-90, 54) size:15 color:IGColor(0x262626) bold:NO]];
    UISwitch *textMode = [[UISwitch alloc] initWithFrame:CGRectMake(width-66, 11, 51, 31)];
    textMode.transform = CGAffineTransformMakeScale(0.9, 0.9);
    textMode.on = IGTextDemoEnabled();
    [textMode addTarget:self action:@selector(toggleTextMode:) forControlEvents:UIControlEventValueChanged];
    [textModeRow addSubview:textMode];
    [scroll addSubview:textModeRow];
    y += 54;
    UILabel *textModeHint = [self label:@"Shows null and zero placeholders instead of text skeletons." frame:CGRectMake(16, y, width-32, 34) size:12 color:IGMuted() bold:NO];
    textModeHint.numberOfLines = 2;
    [scroll addSubview:textModeHint];
    scroll.contentSize = CGSizeMake(width, y+42);
}
- (void)toggleReels:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"IGShowReels"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)toggleTextMode:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"IGTextDemoMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:IGTextModeDidChangeNotification object:nil];
}
@end

@implementation IGCommentsNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Comments";
    CGFloat width = self.view.bounds.size.width;
    CGFloat composerHeight = 48;
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, self.view.bounds.size.height-composerHeight)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    self.commentsScroll = scroll;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renderComments) name:IGTextModeDidChangeNotification object:nil];
    [self renderComments];

    UIView *composer = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-composerHeight, width, composerHeight)];
    composer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    composer.backgroundColor = UIColor.whiteColor;
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    topLine.backgroundColor = IGLine();
    [composer addSubview:topLine];
    UIImageView *share = IGIconView(@"share", CGRectMake(14, 10, 26, 26), IGMuted(), NO);
    [composer addSubview:share];
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(52, 4, width-112, 40)];
    field.placeholder = @"Add a comment…";
    field.font = [UIFont systemFontOfSize:15];
    field.returnKeyType = UIReturnKeySend;
    [composer addSubview:field];
    UIButton *post = [UIButton buttonWithType:UIButtonTypeSystem];
    post.frame = CGRectMake(width-58, 4, 52, 40);
    [post setTitle:@"Post" forState:UIControlStateNormal];
    post.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [composer addSubview:post];
    [self.view addSubview:composer];
    self.composerBar = composer;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{ [field becomeFirstResponder]; });
}
- (void)renderComments {
    [self.commentsScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = 4;
    BOOL textMode = IGTextDemoEnabled();
    for (NSInteger i = 0; i < 8; i++) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 64)];
        [row addSubview:IGSkeleton(CGRectMake(14, 11, 40, 40), 20)];
        if (textMode) {
            [row addSubview:[self label:@"null" frame:CGRectMake(66, 8, width-90, 20) size:14 color:UIColor.blackColor bold:YES]];
            [row addSubview:[self label:@"null" frame:CGRectMake(66, 29, width-90, 21) size:14 color:UIColor.blackColor bold:NO]];
        } else {
            [row addSubview:IGSkeleton(CGRectMake(66, 13, width*0.38, 9), 4.5)];
            [row addSubview:IGSkeleton(CGRectMake(66, 31, width*0.66, 8), 4)];
        }
        [self.commentsScroll addSubview:row];
        y += 64;
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(66, y, width-66, 0.5)];
        line.backgroundColor = IGLine();
        [self.commentsScroll addSubview:line];
    }
    self.commentsScroll.contentSize = CGSizeMake(width, y);
}
- (void)keyboardFrameChanged:(NSNotification *)notification {
    CGRect screenFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [self.view convertRect:screenFrame fromView:nil];
    CGFloat y = MAX(0, CGRectGetMinY(keyboardFrame)-CGRectGetHeight(self.composerBar.frame));
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        CGRect composerFrame = self.composerBar.frame;
        composerFrame.origin.y = y;
        self.composerBar.frame = composerFrame;
        CGRect scrollFrame = self.commentsScroll.frame;
        scrollFrame.size.height = y;
        self.commentsScroll.frame = scrollFrame;
    }];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

@implementation IGVideoNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Video";
    UIButton *refresh = [UIButton buttonWithType:UIButtonTypeCustom];
    refresh.frame = CGRectMake(0, 0, 34, 34);
    refresh.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [refresh setImage:[[UIImage imageNamed:@"bar-button-refresh"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:refresh];

    CGFloat width = self.view.bounds.size.width;
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 54)];
    [header addSubview:IGSkeleton(CGRectMake(12, 8, 38, 38), 19)];
    if (IGTextDemoEnabled()) {
        [header addSubview:[self label:@"null" frame:CGRectMake(60, 11, MIN(width*0.46, 142), 24) size:15 color:UIColor.blackColor bold:YES]];
    } else {
        [header addSubview:IGSkeleton(CGRectMake(60, 15, MIN(width*0.46, 142), 10), 5)];
    }
    UIButton *more = [UIButton buttonWithType:UIButtonTypeCustom];
    more.frame = CGRectMake(width-42, 10, 30, 30);
    [more setImage:IGIconImage(@"more", UIColor.blackColor, 24, NO) forState:UIControlStateNormal];
    [more addTarget:self action:@selector(showPostActions) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:more];
    [scroll addSubview:header];

    CGFloat mediaHeight = width * 0.82;
    [scroll addSubview:IGSkeleton(CGRectMake(0, 54, width, mediaHeight), 0)];
    UIImageView *play = IGIconView(@"play", CGRectMake(0, 0, 44, 44), UIColor.whiteColor, NO);
    play.center = CGPointMake(width/2, 54+mediaHeight/2);
    [scroll addSubview:play];
    UIView *actions = [[UIView alloc] initWithFrame:CGRectMake(0, 54+mediaHeight, width, 44)];
    [actions addSubview:IGIconView(@"heart", CGRectMake(12, 8, 27, 27), UIColor.blackColor, NO)];
    [actions addSubview:IGIconView(@"comment", CGRectMake(54, 8, 27, 27), UIColor.blackColor, NO)];
    [actions addSubview:IGIconView(@"share", CGRectMake(96, 8, 27, 27), UIColor.blackColor, NO)];
    [scroll addSubview:actions];
    CGFloat y = CGRectGetMaxY(actions.frame)+14;
    if (IGTextDemoEnabled()) {
        [scroll addSubview:[self label:@"0 views" frame:CGRectMake(14, y-5, width-28, 22) size:14 color:UIColor.blackColor bold:YES]];
        [scroll addSubview:[self label:@"null  null" frame:CGRectMake(14, y+20, width-28, 22) size:14 color:UIColor.blackColor bold:NO]];
    } else {
        [scroll addSubview:IGSkeleton(CGRectMake(14, y, 84, 9), 4.5)];
        [scroll addSubview:IGSkeleton(CGRectMake(14, y+24, width*0.76, 9), 4.5)];
        [scroll addSubview:IGSkeleton(CGRectMake(14, y+42, width*0.55, 8), 4)];
    }
    scroll.contentSize = CGSizeMake(width, y+76);
}
- (void)showPostActions {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:nil]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Edit" style:UIAlertActionStyleDefault handler:nil]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:nil]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
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
    self.tabBar.barTintColor = [UIColor colorWithWhite:1.0 alpha:0.86];
    self.tabBar.translucent = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeToComments) name:@"IGOpenComments" object:nil];
}
- (UINavigationController *)nav:(UIViewController *)root title:(NSString *)title icon:(NSString *)icon {
    root.title = title;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    navigation.tabBarItem.title = @"";
    NSString *tabIcon = [@"tab-" stringByAppendingString:icon];
    navigation.tabBarItem.image = IGIconImage(tabIcon, IGMuted(), 24, NO);
    navigation.tabBarItem.selectedImage = IGIconImage(tabIcon, UIColor.blackColor, 24, YES);
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
