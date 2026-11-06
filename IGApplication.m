#import "IGApplication.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *IGColor(NSInteger hex) {
    return [UIColor colorWithRed:((hex >> 16) & 255) / 255.0 green:((hex >> 8) & 255) / 255.0 blue:(hex & 255) / 255.0 alpha:1.0];
}
static UIColor *IGBlue(void) { return IGColor(0x3897F0); }
static UIColor *IGLine(void) { return IGColor(0xDBDBDB); }
static UIColor *IGMuted(void) { return IGColor(0x999999); }

@interface IGNodeController : UIViewController
@property (nonatomic, copy) NSString *nodeName;
- (void)openNode:(NSString *)name;
@end
@interface IGFeedNode : IGNodeController @end
@interface IGExploreNode : IGNodeController @end
@interface IGActivityNode : IGNodeController @end
@interface IGProfileNode : IGNodeController @end
@interface IGSettingsNode : IGNodeController @end
@interface IGCommentsNode : IGNodeController @end
@interface IGVideoNode : IGNodeController @end
@interface IGPlaceholderNode : IGNodeController @end

@interface IGArtworkView : UIView
@property (nonatomic) NSInteger style;
@end

@implementation IGArtworkView
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    NSArray *top = @[[UIColor colorWithRed:.34 green:.67 blue:.78 alpha:1], [UIColor colorWithRed:.94 green:.66 blue:.43 alpha:1], [UIColor colorWithRed:.47 green:.70 blue:.48 alpha:1], [UIColor colorWithRed:.39 green:.54 blue:.69 alpha:1]];
    NSArray *bottom = @[[UIColor colorWithRed:.12 green:.38 blue:.43 alpha:1], [UIColor colorWithRed:.63 green:.36 blue:.28 alpha:1], [UIColor colorWithRed:.19 green:.43 blue:.29 alpha:1], [UIColor colorWithRed:.22 green:.32 blue:.48 alpha:1]];
    UIColor *colors[] = {top[self.style % 4], bottom[self.style % 4]};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = {0, 1};
    NSArray *components = @[(id)colors[0].CGColor, (id)colors[1].CGColor];
    CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)components, locations);
    CGContextDrawLinearGradient(c, gradient, CGPointZero, CGPointMake(0, CGRectGetHeight(rect)), 0);
    CGGradientRelease(gradient); CGColorSpaceRelease(space);
    CGFloat w = CGRectGetWidth(rect), h = CGRectGetHeight(rect);
    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:1 alpha:.76] CGColor]);
    CGContextFillEllipseInRect(c, CGRectMake(w*.71, h*.15, MIN(w,h)*.12, MIN(w,h)*.12));
    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:.08 alpha:.19] CGColor]);
    CGContextMoveToPoint(c, 0, h*.68); CGContextAddCurveToPoint(c, w*.28, h*.48, w*.49, h*.82, w*.67, h*.61); CGContextAddCurveToPoint(c, w*.84, h*.44, w*.92, h*.54, w, h*.43); CGContextAddLineToPoint(c, w, h); CGContextAddLineToPoint(c, 0, h); CGContextClosePath(c); CGContextFillPath(c);
    CGContextSetStrokeColorWithColor(c, [[UIColor colorWithWhite:1 alpha:.42] CGColor]); CGContextSetLineWidth(c, 2);
    for (NSInteger i=0; i<3; i++) { CGFloat y=h*(.72+i*.07); CGContextMoveToPoint(c, 0, y); CGContextAddCurveToPoint(c, w*.3, y-9, w*.55, y+10, w, y-4); CGContextStrokePath(c); }
}
@end

@interface IGPostView : UIView
- (instancetype)initWithUsername:(NSString *)username place:(NSString *)place caption:(NSString *)caption style:(NSInteger)style;
@end

@implementation IGPostView
- (instancetype)initWithUsername:(NSString *)username place:(NSString *)place caption:(NSString *)caption style:(NSInteger)style {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.backgroundColor = UIColor.whiteColor;
        CGFloat width = UIScreen.mainScreen.bounds.size.width;
        UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 56)];
        UIView *avatar = [[UIView alloc] initWithFrame:CGRectMake(12, 9, 38, 38)]; avatar.backgroundColor = IGColor(0x202020); avatar.layer.cornerRadius = 19;
        UILabel *avatarLetter = [[UILabel alloc] initWithFrame:avatar.bounds]; avatarLetter.text = [[username substringToIndex:1] uppercaseString]; avatarLetter.textColor = UIColor.whiteColor; avatarLetter.font = [UIFont boldSystemFontOfSize:14]; avatarLetter.textAlignment = NSTextAlignmentCenter; [avatar addSubview:avatarLetter];
        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(59, 7, width-110, 23)]; name.text = username; name.font = [UIFont boldSystemFontOfSize:15];
        UILabel *location = [[UILabel alloc] initWithFrame:CGRectMake(59, 29, width-110, 20)]; location.text = place; location.font = [UIFont systemFontOfSize:13]; location.textColor = IGMuted();
        UILabel *more = [[UILabel alloc] initWithFrame:CGRectMake(width-42, 12, 30, 28)]; more.text = @"•••"; more.font = [UIFont boldSystemFontOfSize:17]; more.textAlignment = NSTextAlignmentCenter;
        [head addSubview:avatar]; [head addSubview:name]; [head addSubview:location]; [head addSubview:more]; [self addSubview:head];
        CGFloat imageH = style == 0 ? width * 0.64 : width; IGArtworkView *image = [[IGArtworkView alloc] initWithFrame:CGRectMake(0, 56, width, imageH)]; image.style = style; [self addSubview:image];
        UIView *actions = [[UIView alloc] initWithFrame:CGRectMake(0, 56+imageH, width, 43)];
        NSArray *glyphs = @[@"♡", @"◯", @"↗"]; CGFloat x=12; for (NSUInteger i=0;i<glyphs.count;i++){ UILabel *g=[[UILabel alloc] initWithFrame:CGRectMake(x, 0, i==2?42:36, 42)]; g.text=glyphs[i]; g.font=[UIFont systemFontOfSize:i==1?27:34 weight:UIFontWeightLight]; g.textColor=UIColor.blackColor; [actions addSubview:g]; x+=i==1?46:43; }
        [self addSubview:actions];
        UILabel *likes = [[UILabel alloc] initWithFrame:CGRectMake(14, CGRectGetMaxY(actions.frame), width-28, 22)]; likes.text = @"♥  1,284 likes"; likes.font = [UIFont boldSystemFontOfSize:14]; [self addSubview:likes];
        UILabel *text = [[UILabel alloc] initWithFrame:CGRectMake(14, CGRectGetMaxY(likes.frame)+4, width-28, 40)]; text.numberOfLines=2; text.font=[UIFont systemFontOfSize:14]; text.text=[NSString stringWithFormat:@"%@  %@",username,caption]; [self addSubview:text];
        UIButton *comments = [UIButton buttonWithType:UIButtonTypeSystem]; comments.frame=CGRectMake(14, CGRectGetMaxY(text.frame)-2, width-28, 25); [comments setTitle:@"View all 38 comments" forState:UIControlStateNormal]; [comments setTitleColor:IGMuted() forState:UIControlStateNormal]; comments.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft; comments.titleLabel.font=[UIFont systemFontOfSize:13]; [comments addTarget:self action:@selector(openComments) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:comments];
        UILabel *time=[[UILabel alloc] initWithFrame:CGRectMake(14, CGRectGetMaxY(comments.frame), width-28, 22)]; time.text=@"2 HOURS AGO"; time.textColor=IGMuted(); time.font=[UIFont systemFontOfSize:10]; [self addSubview:time];
        self.frame=CGRectMake(0,0,width,CGRectGetMaxY(time.frame)+12);
    }
    return self;
}
- (void)openComments { [[NSNotificationCenter defaultCenter] postNotificationName:@"IGOpenComments" object:nil]; }
@end

@implementation IGNodeController
- (void)viewDidLoad { [super viewDidLoad]; self.view.backgroundColor=UIColor.whiteColor; self.navigationController.navigationBar.barTintColor=UIColor.whiteColor; self.navigationController.navigationBar.tintColor=UIColor.blackColor; self.navigationController.navigationBar.titleTextAttributes=@{NSForegroundColorAttributeName:UIColor.blackColor,NSFontAttributeName:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]}; self.navigationController.navigationBar.translucent=NO; }
- (void)openNode:(NSString *)name { UIViewController *next=nil; if ([name isEqual:@"Comments"]) next=[[IGCommentsNode alloc]init]; else if ([name isEqual:@"Video"]) next=[[IGVideoNode alloc]init]; else if ([name isEqual:@"Options"]) next=[[IGSettingsNode alloc]init]; else next=[[IGPlaceholderNode alloc]init]; next.title=name; [self.navigationController pushViewController:next animated:YES]; }
- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size color:(UIColor *)color bold:(BOOL)bold { UILabel *v=[[UILabel alloc]initWithFrame:frame]; v.text=text; v.font=bold?[UIFont boldSystemFontOfSize:size]:[UIFont systemFontOfSize:size]; v.textColor=color; return v; }
- (void)addDividerAtY:(CGFloat)y { UIView *line=[[UIView alloc]initWithFrame:CGRectMake(0,y,UIScreen.mainScreen.bounds.size.width,0.5)]; line.backgroundColor=IGLine(); [self.view addSubview:line]; }
@end

@implementation IGFeedNode
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Instagram"; self.navigationItem.titleView=[[UILabel alloc]init]; UILabel *logo=[[UILabel alloc]initWithFrame:CGRectMake(0,0,150,38)]; logo.text=@"Instagram"; logo.textAlignment=NSTextAlignmentCenter; logo.font=[UIFont fontWithName:@"Zapfino" size:20]?:[UIFont italicSystemFontOfSize:22]; logo.textColor=UIColor.blackColor; self.navigationItem.titleView=logo;
    UIButton *inbox=[UIButton buttonWithType:UIButtonTypeSystem]; [inbox setTitle:@"▣" forState:UIControlStateNormal]; inbox.titleLabel.font=[UIFont systemFontOfSize:24]; inbox.tintColor=UIColor.blackColor; inbox.frame=CGRectMake(0,0,38,36); [inbox addTarget:self action:@selector(openInbox) forControlEvents:UIControlEventTouchUpInside]; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithCustomView:inbox];
    UIScrollView *scroll=[[UIScrollView alloc]initWithFrame:self.view.bounds]; scroll.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.view addSubview:scroll]; CGFloat y=0; NSArray *users=@[@"oceanframes",@"fieldnotesdaily",@"slowmorning"]; NSArray *places=@[@"Gold Coast, Queensland",@"Kazakhstan",@"Big Sur, California"]; NSArray *caps=@[@"Chasing the last light over the water. #weekend",@"A quiet morning outside.",@"Somewhere along the coast."]; for (NSInteger i=0;i<users.count;i++){ IGPostView *post=[[IGPostView alloc]initWithUsername:users[i] place:places[i] caption:caps[i] style:i]; post.frame=CGRectMake(0,y,post.frame.size.width,post.frame.size.height); [scroll addSubview:post]; y+=post.frame.size.height; } scroll.contentSize=CGSizeMake(scroll.bounds.size.width,y);
    }
- (void)openInbox { [self openNode:@"Messages"]; }
- (void)showComments { [self openNode:@"Comments"]; }
@end

@implementation IGExploreNode
- (void)viewDidLoad { [super viewDidLoad]; UIView *search=[[UIView alloc]initWithFrame:CGRectMake(0,0,220,32)]; search.backgroundColor=IGColor(0xEFEFF1); search.layer.cornerRadius=5; UILabel *searchLabel=[self label:@"⌕  Search" frame:CGRectMake(10,0,search.bounds.size.width-20,32) size:15 color:IGMuted() bold:NO]; [search addSubview:searchLabel]; self.navigationItem.titleView=search; UIButton *people=[UIButton buttonWithType:UIButtonTypeSystem]; [people setTitle:@"♙" forState:UIControlStateNormal]; people.tintColor=IGMuted(); people.titleLabel.font=[UIFont systemFontOfSize:21]; people.frame=CGRectMake(0,0,34,34); self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithCustomView:people];
    UIScrollView *scroll=[[UIScrollView alloc]initWithFrame:self.view.bounds]; scroll.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.view addSubview:scroll]; CGFloat y=0;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"IGShowReels"]==nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"IGShowReels"]) { UIButton *reels=[UIButton buttonWithType:UIButtonTypeCustom]; reels.frame=CGRectMake(0,0,self.view.bounds.size.width,180); IGArtworkView *art=[[IGArtworkView alloc]initWithFrame:reels.bounds]; art.style=0; [reels addSubview:art]; UIView *shade=[[UIView alloc]initWithFrame:CGRectMake(0,100,reels.bounds.size.width,80)]; shade.backgroundColor=[UIColor colorWithWhite:0 alpha:.28]; [reels addSubview:shade]; UILabel *tag=[self label:@"▶  REELS" frame:CGRectMake(14,107,150,20) size:11 color:UIColor.whiteColor bold:YES]; UILabel *title=[self label:@"Videos you might like" frame:CGRectMake(14,127,280,36) size:20 color:UIColor.whiteColor bold:YES]; [reels addSubview:tag]; [reels addSubview:title]; [reels addTarget:self action:@selector(openReels) forControlEvents:UIControlEventTouchUpInside]; [scroll addSubview:reels]; y=180; }
    NSInteger count=15; CGFloat w=self.view.bounds.size.width/3.0; for (NSInteger i=0;i<count;i++){ NSInteger row=i/3,col=i%3; IGArtworkView *tile=[[IGArtworkView alloc]initWithFrame:CGRectMake(col*w+1,row*w+1+y,w-2,w-2)]; tile.style=i%4; [scroll addSubview:tile]; if (i%5==2){ UILabel *play=[[UILabel alloc]initWithFrame:CGRectMake(w-26,4,22,22)]; play.text=@"▶"; play.font=[UIFont systemFontOfSize:11]; play.textColor=UIColor.whiteColor; [tile addSubview:play]; } } scroll.contentSize=CGSizeMake(scroll.bounds.size.width,y+ceil(count/3.0)*w); }
- (void)openReels { [self openNode:@"Video"]; }
@end

@implementation IGActivityNode
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Activity"; UIScrollView *s=[[UIScrollView alloc]initWithFrame:self.view.bounds]; s.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.view addSubview:s]; NSArray *items=@[@"alex_morning liked your photo.",@"travelnotes started following you.",@"maria tagged you in a comment.",@"sam and 3 others liked your photo.",@"nina started following you.",@"cameraroll liked your photo.",@"tom mentioned you in a comment."]; CGFloat y=9; for(NSInteger i=0;i<items.count;i++){ UIView *row=[[UIView alloc]initWithFrame:CGRectMake(0,y,self.view.bounds.size.width,68)]; UIView *avatar=[[UIView alloc]initWithFrame:CGRectMake(14,10,46,46)]; avatar.backgroundColor=@[IGColor(0xD98A70),IGColor(0x678CA4),IGColor(0x7B9C72)][i%3]; avatar.layer.cornerRadius=23; [row addSubview:avatar]; UILabel *l=[self label:items[i] frame:CGRectMake(72,7,self.view.bounds.size.width-85,50) size:14 color:UIColor.blackColor bold:NO]; l.numberOfLines=2; [row addSubview:l]; [s addSubview:row]; y+=68; [self addDividerAtY:y]; } s.contentSize=CGSizeMake(s.bounds.size.width,y); }
@end

@implementation IGProfileNode
- (void)viewDidLoad { [super viewDidLoad]; self.navigationItem.title=@"fieldnotesdaily  ⌄"; UIButton *settings=[UIButton buttonWithType:UIButtonTypeSystem]; [settings setTitle:@"⚙" forState:UIControlStateNormal]; settings.tintColor=UIColor.blackColor; settings.titleLabel.font=[UIFont systemFontOfSize:25]; settings.frame=CGRectMake(0,0,36,36); [settings addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside]; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithCustomView:settings];
    CGFloat w=self.view.bounds.size.width; UIView *summary=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,144)]; UIView *avatar=[[UIView alloc]initWithFrame:CGRectMake(16,20,82,82)]; avatar.backgroundColor=IGColor(0x58A6A2); avatar.layer.cornerRadius=41; UILabel *initial=[[UILabel alloc]initWithFrame:avatar.bounds]; initial.text=@"F"; initial.textColor=UIColor.whiteColor; initial.font=[UIFont boldSystemFontOfSize:34]; initial.textAlignment=NSTextAlignmentCenter; [avatar addSubview:initial]; [summary addSubview:avatar]; NSArray *nums=@[@"542",@"17.5k",@"5"]; NSArray *names=@[@"posts",@"followers",@"following"]; CGFloat start=112, cell=(w-start)/3; for(NSInteger i=0;i<3;i++){ UILabel *n=[self label:nums[i] frame:CGRectMake(start+i*cell,26,cell,24) size:17 color:UIColor.blackColor bold:YES]; n.textAlignment=NSTextAlignmentCenter; UILabel *t=[self label:names[i] frame:CGRectMake(start+i*cell,50,cell,22) size:12 color:IGMuted() bold:NO]; t.textAlignment=NSTextAlignmentCenter; [summary addSubview:n]; [summary addSubview:t]; }
    UIButton *edit=[UIButton buttonWithType:UIButtonTypeSystem]; edit.frame=CGRectMake(start,78,w-start-14,30); [edit setTitle:@"Edit Profile" forState:UIControlStateNormal]; [edit setTitleColor:UIColor.blackColor forState:UIControlStateNormal]; edit.titleLabel.font=[UIFont boldSystemFontOfSize:13]; edit.backgroundColor=IGColor(0xF5F5F5); edit.layer.cornerRadius=3; [summary addSubview:edit]; [self.view addSubview:summary];
    UILabel *name=[self label:@"Field Notes" frame:CGRectMake(15,145,w-30,24) size:15 color:UIColor.blackColor bold:YES]; [self.view addSubview:name]; UILabel *bio=[self label:@"Small moments, open roads, and the occasional cup of coffee.\nBased near the coast." frame:CGRectMake(15,171,w-30,46) size:14 color:UIColor.blackColor bold:NO]; bio.numberOfLines=2; [self.view addSubview:bio];
    UIView *selector=[[UIView alloc]initWithFrame:CGRectMake(0,224,w,42)]; NSArray *syms=@[@"▦",@"☷",@"⌖",@"▣"]; for(NSInteger i=0;i<4;i++){ UILabel *l=[self label:syms[i] frame:CGRectMake(i*w/4,0,w/4,42) size:21 color:(i==0?IGBlue():IGMuted()) bold:NO]; l.textAlignment=NSTextAlignmentCenter; [selector addSubview:l]; } [self.view addSubview:selector]; [self addDividerAtY:266];
    UIScrollView *grid=[[UIScrollView alloc]initWithFrame:CGRectMake(0,267,w,self.view.bounds.size.height-267)]; grid.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.view addSubview:grid]; CGFloat tileW=w/3; for(NSInteger i=0;i<18;i++){ IGArtworkView *tile=[[IGArtworkView alloc]initWithFrame:CGRectMake((i%3)*tileW+1,(i/3)*tileW+1,tileW-2,tileW-2)]; tile.style=(i+1)%4; [grid addSubview:tile]; } grid.contentSize=CGSizeMake(w,6*tileW); }
- (void)openSettings { [self openNode:@"Options"]; }
@end

@implementation IGSettingsNode
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Options"; UIView *section=[[UIView alloc]initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,48)]; UILabel *heading=[self label:@"FEED" frame:CGRectMake(16,18,200,20) size:12 color:IGMuted() bold:YES]; [section addSubview:heading]; [self.view addSubview:section]; [self addDividerAtY:48]; UILabel *title=[self label:@"Show Reels in Explore" frame:CGRectMake(16,61,250,28) size:15 color:UIColor.blackColor bold:NO]; [self.view addSubview:title]; UISwitch *toggle=[[UISwitch alloc]initWithFrame:CGRectMake(self.view.bounds.size.width-66,58,51,31)]; toggle.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin; toggle.on=([[NSUserDefaults standardUserDefaults] objectForKey:@"IGShowReels"]==nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"IGShowReels"]); [toggle addTarget:self action:@selector(toggleReels:) forControlEvents:UIControlEventValueChanged]; [self.view addSubview:toggle]; [self addDividerAtY:100]; UILabel *hint=[self label:@"When off, the Reels shelf is hidden from Explore. Videos already in the photo grid remain visible." frame:CGRectMake(16,108,self.view.bounds.size.width-32,50) size:12 color:IGMuted() bold:NO]; hint.numberOfLines=3; [self.view addSubview:hint]; }
- (void)toggleReels:(UISwitch *)sender { [[NSUserDefaults standardUserDefaults]setBool:sender.on forKey:@"IGShowReels"]; [[NSUserDefaults standardUserDefaults]synchronize]; }
@end

@implementation IGCommentsNode
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Comments"; NSArray *rows=@[@"mzkymbella  @mosche1165 @ri_cardo_10 wonderful day",@"j_theodore_  @ffburk",@"vivianwinters  Haha @morayolivier",@"jon3mitchell  LOL!!!! @alilleslips",@"dasmig  @ymileni  ✨✨✨",@"alex_morning  This is beautiful!"]; CGFloat y=0; for(NSInteger i=0;i<rows.count;i++){ UIView *r=[[UIView alloc]initWithFrame:CGRectMake(0,y,self.view.bounds.size.width,64)]; UIView *av=[[UIView alloc]initWithFrame:CGRectMake(14,12,38,38)]; av.backgroundColor=IGColor(0x78949A); av.layer.cornerRadius=19; [r addSubview:av]; UILabel *l=[self label:rows[i] frame:CGRectMake(64,10,self.view.bounds.size.width-78,45) size:13 color:UIColor.darkGrayColor bold:NO]; l.numberOfLines=2; [r addSubview:l]; [self.view addSubview:r]; y+=64; [self addDividerAtY:y]; } }
@end

@implementation IGVideoNode
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"Reels"; IGArtworkView *art=[[IGArtworkView alloc]initWithFrame:self.view.bounds]; art.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; art.style=0; [self.view addSubview:art]; UILabel *play=[[UILabel alloc]initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,80)]; play.center=self.view.center; play.text=@"▶"; play.font=[UIFont systemFontOfSize:62 weight:UIFontWeightLight]; play.textColor=[UIColor colorWithWhite:1 alpha:.9]; play.textAlignment=NSTextAlignmentCenter; [self.view addSubview:play]; UILabel *caption=[[UILabel alloc]initWithFrame:CGRectMake(15,self.view.bounds.size.height-80,self.view.bounds.size.width-30,60)]; caption.autoresizingMask=UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleWidth; caption.text=@"oceanframes\nA little salt air goes a long way."; caption.textColor=UIColor.whiteColor; caption.font=[UIFont systemFontOfSize:14]; caption.numberOfLines=2; [self.view addSubview:caption]; }
@end

@implementation IGPlaceholderNode
- (void)viewDidLoad { [super viewDidLoad]; UILabel *l=[self label:@"This screen is ready for its own feature node." frame:CGRectMake(24,100,self.view.bounds.size.width-48,70) size:15 color:IGMuted() bold:NO]; l.textAlignment=NSTextAlignmentCenter; l.numberOfLines=2; [self.view addSubview:l]; }
@end

@implementation IGApplicationController
- (void)viewDidLoad { [super viewDidLoad]; self.viewControllers=@[[self nav:[IGFeedNode new] title:@"Home" image:@"⌂"],[self nav:[IGExploreNode new] title:@"Search" image:@"⌕"],[self nav:[IGPlaceholderNode new] title:@"Camera" image:@"◎"],[self nav:[IGActivityNode new] title:@"Activity" image:@"♡"],[self nav:[IGProfileNode new] title:@"Profile" image:@"●"]]; self.selectedIndex=0; self.tabBar.tintColor=UIColor.blackColor; self.tabBar.barTintColor=UIColor.whiteColor; self.tabBar.translucent=NO; [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(routeToComments) name:@"IGOpenComments" object:nil]; }
- (UINavigationController *)nav:(UIViewController *)root title:(NSString *)title image:(NSString *)image { root.title=title; UINavigationController *n=[[UINavigationController alloc]initWithRootViewController:root]; n.tabBarItem.title=@""; n.tabBarItem.image=[self icon:image selected:NO]; n.tabBarItem.selectedImage=[self icon:image selected:YES]; return n; }
- (UIImage *)icon:(NSString *)symbol selected:(BOOL)selected { CGSize size=CGSizeMake(26,26); UIGraphicsBeginImageContextWithOptions(size,NO,0); CGContextRef c=UIGraphicsGetCurrentContext(); CGContextSetStrokeColorWithColor(c,(selected?UIColor.blackColor:IGMuted()).CGColor); CGContextSetFillColorWithColor(c,(selected?UIColor.blackColor:IGMuted()).CGColor); CGContextSetLineWidth(c,1.8); if([symbol isEqual:@"⌂"]){ CGContextMoveToPoint(c,3,12); CGContextAddLineToPoint(c,13,3); CGContextAddLineToPoint(c,23,12); CGContextStrokePath(c); CGContextStrokeRect(c,CGRectMake(7,12,12,11)); } else if([symbol isEqual:@"⌕"]){ CGContextStrokeEllipseInRect(c,CGRectMake(3,3,15,15)); CGContextMoveToPoint(c,17,17); CGContextAddLineToPoint(c,24,24); CGContextStrokePath(c); } else if([symbol isEqual:@"◎"]){ CGContextStrokeEllipseInRect(c,CGRectMake(3,3,20,20)); CGContextStrokeEllipseInRect(c,CGRectMake(9,9,8,8)); CGContextFillEllipseInRect(c,CGRectMake(18,6,2,2)); } else if([symbol isEqual:@"♡"]){ UIBezierPath *p=[UIBezierPath bezierPath]; [p moveToPoint:CGPointMake(13,23)]; [p addCurveToPoint:CGPointMake(3,10) controlPoint1:CGPointMake(2,17) controlPoint2:CGPointMake(1,12)]; [p addCurveToPoint:CGPointMake(13,8) controlPoint1:CGPointMake(5,3) controlPoint2:CGPointMake(10,4)]; [p addCurveToPoint:CGPointMake(23,10) controlPoint1:CGPointMake(16,4) controlPoint2:CGPointMake(21,3)]; [p addCurveToPoint:CGPointMake(13,23) controlPoint1:CGPointMake(25,12) controlPoint2:CGPointMake(23,17)]; p.lineWidth=1.8; [(selected?UIColor.blackColor:IGMuted()) setStroke]; [p stroke]; } else { CGContextStrokeEllipseInRect(c,CGRectMake(3,3,20,20)); CGContextFillEllipseInRect(c,CGRectMake(9,9,8,8)); } UIImage *img=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return img; }
- (void)routeToComments { UINavigationController *n=(UINavigationController *)self.selectedViewController; if (![n.topViewController isKindOfClass:[IGCommentsNode class]]) { IGCommentsNode *c=[IGCommentsNode new]; c.title=@"Comments"; [n pushViewController:c animated:YES]; } }
@end
