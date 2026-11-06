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
static NSString * const IGTestEventsDidChangeNotification = @"IGTestEventsDidChange";
static NSString * const IGSettingsDidChangeNotification = @"IGSettingsDidChange";
static NSString * const IGTestEventsKey = @"IGTestEvents";
static BOOL IGTextDemoEnabled(void) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"IGTextDemoMode"];
    return value == nil || [value boolValue];
}
static NSArray *IGTestEvents(void) {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:IGTestEventsKey] ?: @[];
}
static NSArray *IGSortedTestEvents(NSString *type) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *event, NSDictionary *bindings) {
        return !type || [event[@"type"] isEqualToString:type];
    }];
    NSArray *filtered = [IGTestEvents() filteredArrayUsingPredicate:predicate];
    return [filtered sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"date"] compare:b[@"date"]];
    }];
}
static NSInteger IGTestEventCount(NSString *type) {
    return [IGSortedTestEvents(type) count];
}
static NSInteger IGUnreadLikeCount(void) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *event, NSDictionary *bindings) {
        return [event[@"type"] isEqualToString:@"like"] && ![event[@"read"] boolValue];
    }];
    return [[IGTestEvents() filteredArrayUsingPredicate:predicate] count];
}
static NSInteger IGUnreadMessageCount(void) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *event, NSDictionary *bindings) {
        return [event[@"type"] isEqualToString:@"message"] && ![event[@"read"] boolValue];
    }];
    return [[IGTestEvents() filteredArrayUsingPredicate:predicate] count];
}
static void IGAddTestEvent(NSString *type, NSString *text) {
    NSMutableArray *events = [IGTestEvents() mutableCopy];
    [events addObject:@{@"type": type, @"text": text ?: @"", @"date": @([[NSDate date] timeIntervalSince1970]), @"read": @NO}];
    [[NSUserDefaults standardUserDefaults] setObject:events forKey:IGTestEventsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:IGTestEventsDidChangeNotification object:nil];
}
static void IGMarkTestEventsRead(NSString *type) {
    NSMutableArray *events = [NSMutableArray array];
    BOOL changed = NO;
    for (NSDictionary *event in IGTestEvents()) {
        NSMutableDictionary *copy = [event mutableCopy];
        BOOL matches = !type || [event[@"type"] isEqualToString:type] ||
            ([type isEqualToString:@"activity"] && ([event[@"type"] isEqualToString:@"like"] || [event[@"type"] isEqualToString:@"follow"]));
        if (matches && ![event[@"read"] boolValue]) { copy[@"read"] = @YES; changed = YES; }
        [events addObject:copy];
    }
    if (changed) {
        [[NSUserDefaults standardUserDefaults] setObject:events forKey:IGTestEventsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:IGTestEventsDidChangeNotification object:nil];
    }
}
static void IGClearTestEvents(void) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:IGTestEventsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:IGTestEventsDidChangeNotification object:nil];
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
@interface IGExploreNode : IGNodeController
@property (nonatomic, strong) UIScrollView *exploreScroll;
- (void)renderExplore;
@end
@interface IGActivityNode : IGNodeController
@property (nonatomic, strong) UIScrollView *activityScroll;
- (void)renderActivity;
@end
@interface IGProfileNode : IGNodeController
- (void)renderProfile;
@end
@interface IGSettingsNode : IGNodeController
@property (nonatomic, assign) NSInteger selectedSection;
@property (nonatomic, assign) NSInteger selectedDevTab;
- (void)renderSettings;
- (void)selectSettingsTab:(UIButton *)sender;
- (void)selectDevTab:(UIButton *)sender;
- (CGFloat)addOptionRowsTo:(UIScrollView *)scroll width:(CGFloat)width startY:(CGFloat)y;
- (CGFloat)addDevRowsTo:(UIScrollView *)scroll width:(CGFloat)width startY:(CGFloat)y;
- (void)triggerMessage;
- (void)triggerLike;
- (void)triggerFollower;
- (void)clearTestEvents;
@end
@interface IGCommentsNode : IGNodeController
@property (nonatomic, strong) UIView *composerBar;
@property (nonatomic, strong) UIScrollView *commentsScroll;
- (void)renderComments;
@end
@interface IGVideoNode : IGNodeController @end
@interface IGInboxNode : IGNodeController
@property (nonatomic, strong) UIScrollView *inboxScroll;
- (void)renderInbox;
- (void)openConversation;
@end
@interface IGConversationNode : IGNodeController
@property (nonatomic, strong) UIScrollView *conversationScroll;
- (void)renderConversation;
@end
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
            likes.text = [NSString stringWithFormat:@"%ld likes", (long)IGTestEventCount(@"like")];
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
    else if ([name isEqualToString:@"Messages"]) next = [IGInboxNode new];
    else next = [IGPlaceholderNode new];
    next.title = name;
    if ([name isEqualToString:@"Comments"]) next.hidesBottomBarWhenPushed = YES;
    if ([name isEqualToString:@"Messages"]) next.hidesBottomBarWhenPushed = YES;
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuildFeed) name:IGTestEventsDidChangeNotification object:nil];
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
    self.exploreScroll = scroll;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renderExplore) name:IGSettingsDidChangeNotification object:nil];
    [self renderExplore];
}
- (void)renderExplore {
    [self.exploreScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = 0;
    BOOL showReels = [[NSUserDefaults standardUserDefaults] objectForKey:@"IGShowReels"] == nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"IGShowReels"];
    if (showReels) {
        UIButton *reels = [UIButton buttonWithType:UIButtonTypeCustom];
        reels.frame = CGRectMake(0, 0, width, 180);
        UIView *media = IGSkeleton(reels.bounds, 0);
        [reels addSubview:media];
        [reels addSubview:IGIconView(@"play", CGRectMake((width-42)/2, 44, 42, 42), IGMuted(), NO)];
        UILabel *label = [self label:@"REELS" frame:CGRectMake(14, 112, 140, 17) size:11 color:IGMuted() bold:YES];
        [reels addSubview:label];
        [reels addSubview:IGSkeleton(CGRectMake(14, 137, MIN(220, width-28), 12), 6)];
        [reels addTarget:self action:@selector(openReels) forControlEvents:UIControlEventTouchUpInside];
        [self.exploreScroll addSubview:reels];
        y = CGRectGetMaxY(reels.frame);
    }

    CGFloat tileWidth = width / 3.0;
    NSInteger count = 18;
    for (NSInteger i = 0; i < count; i++) {
        NSInteger row = i / 3;
        NSInteger column = i % 3;
        CGRect frame = CGRectMake(column * tileWidth + 1, y + row * tileWidth + 1, tileWidth - 2, tileWidth - 2);
        UIView *tile = IGSkeleton(frame, 0);
        [self.exploreScroll addSubview:tile];
    }
    self.exploreScroll.contentSize = CGSizeMake(width, y + ceil(count / 3.0) * tileWidth);
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renderActivity) name:IGTestEventsDidChangeNotification object:nil];
    [self renderActivity];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    IGMarkTestEventsRead(@"activity");
    [self renderActivity];
}
- (void)renderActivity {
    [self.activityScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = 6;
    NSMutableArray *activityEvents = [NSMutableArray array];
    for (NSDictionary *event in IGSortedTestEvents(nil)) {
        if ([event[@"type"] isEqualToString:@"like"] || [event[@"type"] isEqualToString:@"follow"]) [activityEvents addObject:event];
    }
    NSArray *visibleEvents = [[activityEvents reverseObjectEnumerator] allObjects];
    NSInteger rowCount = visibleEvents.count ? MIN(visibleEvents.count, 20) : 8;
    for (NSInteger i = 0; i < rowCount; i++) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 68)];
        [row addSubview:IGSkeleton(CGRectMake(14, 10, 46, 46), 23)];
        if (visibleEvents.count) {
            NSDictionary *event = visibleEvents[i];
            NSString *action = [event[@"type"] isEqualToString:@"like"] ? @"liked your photo" : @"started following you";
            NSString *message = [NSString stringWithFormat:@"null %@", action];
            UILabel *label = [self label:message frame:CGRectMake(72, 11, width-132, 42) size:14 color:UIColor.blackColor bold:NO];
            label.numberOfLines = 2;
            [row addSubview:label];
            [row addSubview:[self label:@"now" frame:CGRectMake(width-49, 11, 38, 18) size:12 color:IGMuted() bold:NO]];
            if ([event[@"type"] isEqualToString:@"like"]) [row addSubview:IGSkeleton(CGRectMake(width-56, 35, 42, 28), 1)];
            else {
                UIButton *followBack = [UIButton buttonWithType:UIButtonTypeSystem];
                followBack.frame = CGRectMake(width-82, 34, 68, 28);
                [followBack setTitle:@"Follow" forState:UIControlStateNormal];
                followBack.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
                [row addSubview:followBack];
            }
        } else if (IGTextDemoEnabled()) {
            [row addSubview:[self label:@"null" frame:CGRectMake(72, 10, width-140, 20) size:14 color:UIColor.blackColor bold:YES]];
            [row addSubview:[self label:@"0 likes" frame:CGRectMake(72, 31, width-140, 20) size:13 color:IGMuted() bold:NO]];
            [row addSubview:IGSkeleton(CGRectMake(width-56, 11, 42, 42), 1)];
        } else {
            [row addSubview:IGSkeleton(CGRectMake(72, 14, width * 0.51, 9), 4.5)];
            [row addSubview:IGSkeleton(CGRectMake(72, 32, width * 0.35, 8), 4)];
            [row addSubview:IGSkeleton(CGRectMake(width-56, 11, 42, 42), 1)];
        }
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renderProfile) name:IGTestEventsDidChangeNotification object:nil];
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
            count.text = [NSString stringWithFormat:@"%ld", (long)(i == 1 ? IGTestEventCount(@"follow") : 0)];
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
    self.selectedSection = 0;
    self.selectedDevTab = 0;
    [self renderSettings];
}
- (void)renderSettings {
    [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.view.bounds.size.width;
    UIView *tabs = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
    NSArray *titles = @[@"OPTIONS", @"DEV"];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(i * width/2, 0, width/2, 43);
        button.tag = i;
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:i == self.selectedSection ? UIColor.blackColor : IGMuted() forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:i == self.selectedSection ? UIFontWeightSemibold : UIFontWeightRegular];
        [button addTarget:self action:@selector(selectSettingsTab:) forControlEvents:UIControlEventTouchUpInside];
        [tabs addSubview:button];
    }
    UIView *underline = [[UIView alloc] initWithFrame:CGRectMake(self.selectedSection * width/2, 42, width/2, 2)];
    underline.backgroundColor = UIColor.blackColor;
    [tabs addSubview:underline];
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(0, 43.5, width, 0.5)];
    divider.backgroundColor = IGLine();
    [tabs addSubview:divider];
    [self.view addSubview:tabs];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 44, width, self.view.bounds.size.height-44)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    CGFloat contentY = self.selectedSection == 0
        ? [self addOptionRowsTo:scroll width:width startY:0]
        : [self addDevRowsTo:scroll width:width startY:0];
    scroll.contentSize = CGSizeMake(width, contentY + 16);
}
- (void)selectSettingsTab:(UIButton *)sender {
    self.selectedSection = sender.tag;
    [self renderSettings];
}
- (void)selectDevTab:(UIButton *)sender {
    self.selectedDevTab = sender.tag;
    [self renderSettings];
}
- (CGFloat)addOptionRowsTo:(UIScrollView *)scroll width:(CGFloat)width startY:(CGFloat)y {
    NSArray *sections = @[
        @{ @"title": @"FOLLOW PEOPLE", @"rows": @[@"Facebook Friends", @"Find Contacts", @"Invite Facebook Friends"] },
        @{ @"title": @"ACCOUNT", @"rows": @[@"Edit Profile", @"Change Password", @"Posts You've Liked", @"Two-Factor Authentication"] }
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
            [row addSubview:[self label:title frame:CGRectMake(16, 0, width-52, 54) size:15 color:invite ? IGColor(0x3F5F8A) : IGColor(0x262626) bold:NO]];
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
    UILabel *hint = [self label:@"When your account is private, only people you approve can see your photos and videos." frame:CGRectMake(16, y, width-32, 54) size:12 color:IGMuted() bold:NO];
    hint.numberOfLines = 3;
    [scroll addSubview:hint];
    return y + 72;
}
- (CGFloat)addDevRowsTo:(UIScrollView *)scroll width:(CGFloat)width startY:(CGFloat)y {
    UIView *tabs = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 40)];
    NSArray *titles = @[@"CONTROLS", @"TRIGGERS"];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(i * width/2, 0, width/2, 39);
        button.tag = i;
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:i == self.selectedDevTab ? IGBlue() : IGMuted() forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        [button addTarget:self action:@selector(selectDevTab:) forControlEvents:UIControlEventTouchUpInside];
        [tabs addSubview:button];
    }
    UIView *underline = [[UIView alloc] initWithFrame:CGRectMake(self.selectedDevTab * width/2, 38, width/2, 2)];
    underline.backgroundColor = IGBlue();
    [tabs addSubview:underline];
    [scroll addSubview:tabs];
    y += 40;
    if (self.selectedDevTab == 0) {
        UIView *heading = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 42)];
        heading.backgroundColor = IGColor(0xFAFAFA);
        [heading addSubview:[self label:@"DEVELOPER CONTROLS" frame:CGRectMake(16, 16, width-32, 18) size:12 color:IGMuted() bold:YES]];
        [scroll addSubview:heading];
        y += 42;

        UIView *reelsRow = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 54)];
        [reelsRow addSubview:[self label:@"Show Reels in Explore" frame:CGRectMake(16, 0, width-90, 54) size:15 color:IGColor(0x262626) bold:NO]];
        UISwitch *reels = [[UISwitch alloc] initWithFrame:CGRectMake(width-66, 11, 51, 31)];
        reels.transform = CGAffineTransformMakeScale(0.9, 0.9);
        reels.on = [[NSUserDefaults standardUserDefaults] objectForKey:@"IGShowReels"] == nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"IGShowReels"];
        [reels addTarget:self action:@selector(toggleReels:) forControlEvents:UIControlEventValueChanged];
        [reelsRow addSubview:reels];
        [scroll addSubview:reelsRow];
        y += 54;
        [scroll addSubview:[self label:@"Shows the Reels shelf on Explore." frame:CGRectMake(16, y, width-32, 30) size:12 color:IGMuted() bold:NO]];
        y += 38;

        UIView *nullsRow = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 54)];
        [nullsRow addSubview:[self label:@"Null demo data" frame:CGRectMake(16, 0, width-90, 54) size:15 color:IGColor(0x262626) bold:NO]];
        UISwitch *nulls = [[UISwitch alloc] initWithFrame:CGRectMake(width-66, 11, 51, 31)];
        nulls.transform = CGAffineTransformMakeScale(0.9, 0.9);
        nulls.on = IGTextDemoEnabled();
        [nulls addTarget:self action:@selector(toggleTextMode:) forControlEvents:UIControlEventValueChanged];
        [nullsRow addSubview:nulls];
        [scroll addSubview:nullsRow];
        y += 54;
        [scroll addSubview:[self label:@"Replaces account names and copy with null placeholders." frame:CGRectMake(16, y, width-32, 32) size:12 color:IGMuted() bold:NO]];
        return y + 38;
    }

    UIView *heading = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 42)];
    heading.backgroundColor = IGColor(0xFAFAFA);
    [heading addSubview:[self label:@"TEST TRIGGERS" frame:CGRectMake(16, 16, width-32, 18) size:12 color:IGMuted() bold:YES]];
    [scroll addSubview:heading];
    y += 42;
    NSArray *triggers = @[
        @{ @"title": @"Send message to yourself", @"detail": @"Shows as unread until you open the chat.", @"action": @"Send", @"selector": NSStringFromSelector(@selector(triggerMessage)), @"count": @"" },
        @{ @"title": @"Add a like", @"detail": [NSString stringWithFormat:@"Likes received: %ld", (long)IGTestEventCount(@"like")], @"action": @"Add", @"selector": NSStringFromSelector(@selector(triggerLike)), @"count": @"" },
        @{ @"title": @"Add a follower", @"detail": [NSString stringWithFormat:@"Followers added: %ld", (long)IGTestEventCount(@"follow")], @"action": @"Add", @"selector": NSStringFromSelector(@selector(triggerFollower)), @"count": @"" }
    ];
    for (NSDictionary *trigger in triggers) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 66)];
        [row addSubview:[self label:trigger[@"title"] frame:CGRectMake(16, 7, width-112, 22) size:14 color:IGColor(0x262626) bold:YES]];
        [row addSubview:[self label:trigger[@"detail"] frame:CGRectMake(16, 31, width-112, 26) size:11 color:IGMuted() bold:NO]];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(width-82, 18, 68, 32);
        [button setTitle:trigger[@"action"] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [button addTarget:self action:NSSelectorFromString(trigger[@"selector"]) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:button];
        [scroll addSubview:row];
        y += 66;
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(16, y, width-16, 0.5)];
        line.backgroundColor = IGLine();
        [scroll addSubview:line];
    }
    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    clear.frame = CGRectMake(16, y+8, width-32, 44);
    [clear setTitle:@"Clear test events" forState:UIControlStateNormal];
    [clear setTitleColor:IGColor(0xED4956) forState:UIControlStateNormal];
    [clear addTarget:self action:@selector(clearTestEvents) forControlEvents:UIControlEventTouchUpInside];
    [scroll addSubview:clear];
    return y + 60;
}
- (void)toggleReels:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"IGShowReels"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:IGSettingsDidChangeNotification object:nil];
}
- (void)toggleTextMode:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"IGTextDemoMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:IGTextModeDidChangeNotification object:nil];
}
- (void)triggerMessage {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Message yourself" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Message"; field.autocapitalizationType = UITextAutocapitalizationTypeSentences; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Send" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        if (text.length) IGAddTestEvent(@"message", text);
        [self renderSettings];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)triggerLike {
    IGAddTestEvent(@"like", @"");
    [self renderSettings];
}
- (void)triggerFollower {
    IGAddTestEvent(@"follow", @"");
    [self renderSettings];
}
- (void)clearTestEvents {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear test events?" message:@"This removes the local test messages, likes, and followers." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { IGClearTestEvents(); [self renderSettings]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@implementation IGInboxNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Direct";
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    self.inboxScroll = scroll;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renderInbox) name:IGTestEventsDidChangeNotification object:nil];
    [self renderInbox];
}
- (void)renderInbox {
    [self.inboxScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.view.bounds.size.width;
    NSArray *messages = IGSortedTestEvents(@"message");
    if (messages.count == 0) {
        [self.inboxScroll addSubview:[self label:@"No messages yet" frame:CGRectMake(16, 28, width-32, 24) size:14 color:IGMuted() bold:NO]];
        self.inboxScroll.contentSize = CGSizeMake(width, 80);
        return;
    }
    NSDictionary *last = messages.lastObject;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 72)];
    [row addSubview:IGSkeleton(CGRectMake(14, 12, 46, 46), 23)];
    [row addSubview:[self label:@"null" frame:CGRectMake(72, 8, width-120, 22) size:14 color:UIColor.blackColor bold:YES]];
    UILabel *preview = [self label:last[@"text"] frame:CGRectMake(72, 31, width-96, 22) size:13 color:IGMuted() bold:NO];
    preview.lineBreakMode = NSLineBreakByTruncatingTail;
    [row addSubview:preview];
    if (IGUnreadMessageCount() > 0) {
        UIView *unread = [[UIView alloc] initWithFrame:CGRectMake(width-22, 29, 8, 8)];
        unread.backgroundColor = IGBlue();
        unread.layer.cornerRadius = 4;
        [row addSubview:unread];
    }
    [self.inboxScroll addSubview:row];
    UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
    tap.frame = row.bounds;
    [tap addTarget:self action:@selector(openConversation) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:tap];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(72, 71.5, width-72, 0.5)];
    line.backgroundColor = IGLine();
    [self.inboxScroll addSubview:line];
    self.inboxScroll.contentSize = CGSizeMake(width, 72);
}
- (void)openConversation {
    IGConversationNode *conversation = [IGConversationNode new];
    conversation.title = @"null";
    conversation.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:conversation animated:YES];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

@implementation IGConversationNode
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"null";
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    self.conversationScroll = scroll;
    [self renderConversation];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    IGMarkTestEventsRead(@"message");
}
- (void)renderConversation {
    [self.conversationScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = 16;
    for (NSDictionary *message in IGSortedTestEvents(@"message")) {
        NSString *text = message[@"text"] ?: @"";
        CGFloat bubbleWidth = MIN(width-72, MAX(110, [text sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15]}].width + 28));
        CGFloat bubbleHeight = MAX(42, ceil([text boundingRectWithSize:CGSizeMake(bubbleWidth-24, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15]} context:nil].size.height) + 20);
        UIView *bubble = [[UIView alloc] initWithFrame:CGRectMake(16, y, bubbleWidth, bubbleHeight)];
        bubble.backgroundColor = IGColor(0xEFEFF1);
        bubble.layer.cornerRadius = 18;
        UILabel *label = [self label:text frame:CGRectMake(12, 9, bubbleWidth-24, bubbleHeight-18) size:15 color:UIColor.blackColor bold:NO];
        label.numberOfLines = 0;
        [bubble addSubview:label];
        [self.conversationScroll addSubview:bubble];
        y += bubbleHeight + 10;
    }
    self.conversationScroll.contentSize = CGSizeMake(width, y+16);
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

@interface IGApplicationController () <UITabBarControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIView *footerView;
@property (nonatomic, strong) NSMutableArray *footerButtons;
@property (nonatomic, strong) NSMutableArray *footerImageViews;
@property (nonatomic, strong) UIView *activityDot;
- (void)selectFooterTab:(UIButton *)sender;
- (void)updateFooterIcons;
- (void)updateFooterVisibility;
@end

@implementation IGApplicationController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = (id<UITabBarControllerDelegate>)self;
    self.viewControllers = @[
        [self nav:[IGFeedNode new] title:@"Home" icon:@"home"],
        [self nav:[IGExploreNode new] title:@"Search" icon:@"search"],
        [self nav:[IGPlaceholderNode new] title:@"Camera" icon:@"camera"],
        [self nav:[IGActivityNode new] title:@"Activity" icon:@"heart"],
        [self nav:[IGProfileNode new] title:@"Profile" icon:@"profile"]
    ];
    self.selectedIndex = 0;
    self.tabBar.hidden = YES;
    self.footerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.footerView.clipsToBounds = NO;
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    blur.frame = self.footerView.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.footerView addSubview:blur];
    UIView *wash = [[UIView alloc] initWithFrame:self.footerView.bounds];
    wash.backgroundColor = [UIColor colorWithWhite:1 alpha:0.62];
    wash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.footerView addSubview:wash];
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 0.5)];
    topLine.backgroundColor = IGLine();
    topLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.footerView addSubview:topLine];
    self.footerButtons = [NSMutableArray array];
    self.footerImageViews = [NSMutableArray array];
    NSArray *names = @[@"tab-home", @"tab-search", @"tab-camera", @"tab-heart", @"tab-profile"];
    NSArray *labels = @[@"Home", @"Search", @"Camera", @"Activity", @"Profile"];
    for (NSInteger i = 0; i < names.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = i;
        button.accessibilityLabel = labels[i];
        [button addTarget:self action:@selector(selectFooterTab:) forControlEvents:UIControlEventTouchUpInside];
        [self.footerView addSubview:button];
        [self.footerButtons addObject:button];
        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.userInteractionEnabled = NO;
        [button addSubview:icon];
        [self.footerImageViews addObject:icon];
    }
    self.activityDot = [[UIView alloc] initWithFrame:CGRectZero];
    self.activityDot.backgroundColor = IGColor(0xED4956);
    self.activityDot.layer.cornerRadius = 2.5;
    self.activityDot.userInteractionEnabled = NO;
    [self.footerView addSubview:self.activityDot];
    [self.view addSubview:self.footerView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFooterIcons) name:IGTestEventsDidChangeNotification object:nil];
    [self updateFooterIcons];
    [self updateFooterVisibility];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    // The 2016 reference footer is 91 px high on a 2x iPhone canvas (45.5 pt).
    // Keep the sub-point size so its top edge and artwork align with that reference.
    CGFloat height = 45.5;
    self.footerView.frame = CGRectMake(0, self.view.bounds.size.height-height, width, height);
    CGFloat itemWidth = width/5.0;
    for (NSInteger i = 0; i < self.footerButtons.count; i++) {
        UIButton *button = self.footerButtons[i];
        button.frame = CGRectMake(i*itemWidth, 0, itemWidth, height);
        UIImageView *icon = self.footerImageViews[i];
        // Instagram's original tab assets are 24 pt, except the activity glyph at 25 pt.
        // Center each image canvas in its tab cell and in the footer, regardless of unread state.
        CGFloat iconSize = i == 3 ? 25.0 : 24.0;
        icon.frame = CGRectMake((itemWidth-iconSize)/2.0, (height-iconSize)/2.0, iconSize, iconSize);
    }
    // The 4 pt unread marker sits under the heart; it never affects icon layout.
    CGFloat dotSize = 4.0;
    self.activityDot.frame = CGRectMake(3*itemWidth + (itemWidth-dotSize)/2.0, 39.25-dotSize/2.0, dotSize, dotSize);
    [self updateFooterVisibility];
}
- (void)selectFooterTab:(UIButton *)sender {
    self.selectedIndex = sender.tag;
    [self updateFooterIcons];
    [self updateFooterVisibility];
    if (sender.tag == 3) IGMarkTestEventsRead(@"activity");
}
- (void)updateFooterIcons {
    NSArray *names = @[@"tab-home", @"tab-search", @"tab-camera", @"tab-heart", @"tab-profile"];
    for (NSInteger i = 0; i < self.footerImageViews.count; i++) {
        UIImageView *icon = self.footerImageViews[i];
        UIColor *color = i == self.selectedIndex ? UIColor.blackColor : IGMuted();
        icon.image = IGIconImage(names[i], color, 24, i == self.selectedIndex);
    }
    self.activityDot.hidden = IGUnreadLikeCount() == 0;
}
- (void)updateFooterVisibility {
    UINavigationController *navigation = (UINavigationController *)self.selectedViewController;
    self.footerView.hidden = [navigation isKindOfClass:[UINavigationController class]] && navigation.topViewController.hidesBottomBarWhenPushed;
}
- (UINavigationController *)nav:(UIViewController *)root title:(NSString *)title icon:(NSString *)icon {
    root.title = title;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    navigation.delegate = self;
    navigation.tabBarItem.title = @"";
    NSString *tabIcon = [@"tab-" stringByAppendingString:icon];
    navigation.tabBarItem.image = IGIconImage(tabIcon, IGMuted(), 24, NO);
    navigation.tabBarItem.selectedImage = IGIconImage(tabIcon, UIColor.blackColor, 24, YES);
    return navigation;
}
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    [self updateFooterIcons];
    [self updateFooterVisibility];
    if ([viewController isEqual:self.viewControllers[3]]) IGMarkTestEventsRead(@"activity");
}
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (navigationController == self.selectedViewController) [self updateFooterVisibility];
}
- (void)routeToComments {
    UINavigationController *navigation = (UINavigationController *)self.selectedViewController;
    if (![navigation.topViewController isKindOfClass:[IGCommentsNode class]]) {
        IGCommentsNode *comments = [IGCommentsNode new];
        comments.title = @"Comments";
        comments.hidesBottomBarWhenPushed = YES;
        [navigation pushViewController:comments animated:YES];
    }
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
