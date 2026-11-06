#import "IGIcon.h"
#include <math.h>

UIImage *IGIconImage(NSString *name, UIColor *color, CGFloat size, BOOL selected) {
    CGSize canvas = CGSizeMake(size, size);
    UIGraphicsBeginImageContextWithOptions(canvas, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, size / 24.0, size / 24.0);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 1.7);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);

    UIBezierPath *path = [UIBezierPath bezierPath];
    path.lineWidth = 1.7;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;

    if ([name isEqualToString:@"home"]) {
        [path moveToPoint:CGPointMake(3, 11)]; [path addLineToPoint:CGPointMake(12, 3.5)]; [path addLineToPoint:CGPointMake(21, 11)];
        [path moveToPoint:CGPointMake(5.5, 10)]; [path addLineToPoint:CGPointMake(5.5, 20.5)]; [path addLineToPoint:CGPointMake(18.5, 20.5)]; [path addLineToPoint:CGPointMake(18.5, 10)];
        if (selected) {
            UIBezierPath *roof = [UIBezierPath bezierPath];
            [roof moveToPoint:CGPointMake(2, 11)]; [roof addLineToPoint:CGPointMake(12, 2.5)]; [roof addLineToPoint:CGPointMake(22, 11)]; [roof addLineToPoint:CGPointMake(19, 11)]; [roof addLineToPoint:CGPointMake(19, 21)]; [roof addLineToPoint:CGPointMake(5, 21)]; [roof addLineToPoint:CGPointMake(5, 11)]; [roof closePath];
            [roof fill];
            [[UIColor whiteColor] setFill]; [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(10, 14, 4, 7) cornerRadius:1] fill];
        } else { [path stroke]; }
    } else if ([name isEqualToString:@"search"]) {
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 13, 13)]];
        [path moveToPoint:CGPointMake(15.5, 15.5)]; [path addLineToPoint:CGPointMake(21, 21)]; [path stroke];
    } else if ([name isEqualToString:@"camera"]) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2.5, 6.5, 19, 14) cornerRadius:3] stroke];
        [path moveToPoint:CGPointMake(7, 6.5)]; [path addLineToPoint:CGPointMake(8.7, 4)]; [path addLineToPoint:CGPointMake(14.7, 4)]; [path addLineToPoint:CGPointMake(16.5, 6.5)]; [path stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.2, 9.7, 7.6, 7.6)] stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(17.5, 9, 1.5, 1.5)] fill];
    } else if ([name isEqualToString:@"heart"]) {
        [path moveToPoint:CGPointMake(12, 21)]; [path addCurveToPoint:CGPointMake(3.2, 10.2) controlPoint1:CGPointMake(7.2, 18.2) controlPoint2:CGPointMake(3.2, 14.1)];
        [path addCurveToPoint:CGPointMake(12, 7.8) controlPoint1:CGPointMake(3.2, 5.3) controlPoint2:CGPointMake(8.8, 5.5)];
        [path addCurveToPoint:CGPointMake(20.8, 10.2) controlPoint1:CGPointMake(15.2, 5.5) controlPoint2:CGPointMake(20.8, 5.3)];
        [path addCurveToPoint:CGPointMake(12, 21) controlPoint1:CGPointMake(20.8, 14.1) controlPoint2:CGPointMake(16.8, 18.2)]; [path closePath];
        if (selected) [path fill]; else [path stroke];
    } else if ([name isEqualToString:@"profile"]) {
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(2.5, 2.5, 19, 19)] stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 7, 6, 6)] fill];
        [path moveToPoint:CGPointMake(5.5, 18.5)]; [path addCurveToPoint:CGPointMake(18.5, 18.5) controlPoint1:CGPointMake(7, 13.8) controlPoint2:CGPointMake(17, 13.8)]; [path stroke];
    } else if ([name isEqualToString:@"comment"]) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 3.5, 18, 14) cornerRadius:4] stroke];
        [path moveToPoint:CGPointMake(7, 17.5)]; [path addLineToPoint:CGPointMake(5, 21)]; [path addLineToPoint:CGPointMake(11, 17.5)]; [path stroke];
    } else if ([name isEqualToString:@"share"]) {
        [path moveToPoint:CGPointMake(4, 12)]; [path addLineToPoint:CGPointMake(20, 12)]; [path addLineToPoint:CGPointMake(14, 6)];
        [path moveToPoint:CGPointMake(20, 12)]; [path addLineToPoint:CGPointMake(14, 18)]; [path stroke];
    } else if ([name isEqualToString:@"inbox"]) {
        [path moveToPoint:CGPointMake(3, 7)]; [path addLineToPoint:CGPointMake(21, 7)]; [path addLineToPoint:CGPointMake(22, 19)]; [path addLineToPoint:CGPointMake(2, 19)]; [path closePath]; [path stroke];
        [path moveToPoint:CGPointMake(3, 14)]; [path addLineToPoint:CGPointMake(8, 14)]; [path addCurveToPoint:CGPointMake(16, 14) controlPoint1:CGPointMake(9, 19) controlPoint2:CGPointMake(15, 19)]; [path addLineToPoint:CGPointMake(21, 14)]; [path stroke];
    } else if ([name isEqualToString:@"more"]) {
        for (NSInteger i=0; i<3; i++) [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(4 + i*7, 10, 2.5, 2.5)] fill];
    } else if ([name isEqualToString:@"grid"]) {
        for (NSInteger row=0; row<2; row++) for (NSInteger column=0; column<2; column++) {
            CGRect box = CGRectMake(3 + column*9.5, 3 + row*9.5, 7.5, 7.5);
            if (selected) [path appendPath:[UIBezierPath bezierPathWithRect:box]]; else [[UIBezierPath bezierPathWithRect:box] stroke];
        }
        if (selected) [path fill];
    } else if ([name isEqualToString:@"list"]) {
        for (NSInteger i=0; i<3; i++) { CGFloat y=5+i*7; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, y, 2, 2)] fill]; [path moveToPoint:CGPointMake(8, y+1)]; [path addLineToPoint:CGPointMake(21, y+1)]; }
        [path stroke];
    } else if ([name isEqualToString:@"pin"]) {
        [path moveToPoint:CGPointMake(12, 21)]; [path addCurveToPoint:CGPointMake(5, 9) controlPoint1:CGPointMake(7, 16) controlPoint2:CGPointMake(5, 13)];
        [path addCurveToPoint:CGPointMake(12, 3) controlPoint1:CGPointMake(5, 4) controlPoint2:CGPointMake(9, 3)]; [path addCurveToPoint:CGPointMake(19, 9) controlPoint1:CGPointMake(15, 3) controlPoint2:CGPointMake(19, 4)];
        [path addCurveToPoint:CGPointMake(12, 21) controlPoint1:CGPointMake(19, 13) controlPoint2:CGPointMake(17, 16)]; [path closePath]; [path stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 6.5, 5, 5)] stroke];
    } else if ([name isEqualToString:@"tagged"]) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 4, 18, 16) cornerRadius:2] stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 7, 6, 5)] stroke];
        [path moveToPoint:CGPointMake(7, 17)]; [path addCurveToPoint:CGPointMake(17, 17) controlPoint1:CGPointMake(8, 13) controlPoint2:CGPointMake(16, 13)]; [path stroke];
    } else if ([name isEqualToString:@"addPerson"]) {
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(4, 4, 7, 7)] stroke];
        [path moveToPoint:CGPointMake(2.5, 19)]; [path addCurveToPoint:CGPointMake(13, 19) controlPoint1:CGPointMake(3, 12) controlPoint2:CGPointMake(12, 12)]; [path stroke];
        [path moveToPoint:CGPointMake(18, 7)]; [path addLineToPoint:CGPointMake(18, 15)]; [path moveToPoint:CGPointMake(14, 11)]; [path addLineToPoint:CGPointMake(22, 11)]; [path stroke];
    } else if ([name isEqualToString:@"settings"]) {
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(5, 5, 14, 14)]];
        for (NSInteger i=0; i<8; i++) {
            CGFloat angle = (CGFloat)i * (CGFloat)M_PI / 4.0;
            [path moveToPoint:CGPointMake(12 + cos(angle)*9, 12 + sin(angle)*9)];
            [path addLineToPoint:CGPointMake(12 + cos(angle)*11, 12 + sin(angle)*11)];
        }
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 9.5, 5, 5)]];
        [path stroke];
    } else if ([name isEqualToString:@"play"]) {
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(2.5, 2.5, 19, 19)] stroke];
        [path moveToPoint:CGPointMake(10, 7.5)]; [path addLineToPoint:CGPointMake(16.5, 12)]; [path addLineToPoint:CGPointMake(10, 16.5)]; [path closePath]; [path fill];
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}
