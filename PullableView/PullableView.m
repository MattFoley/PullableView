
#import "PullableView.h"

/**
 @author Fabio Rodella fabio@crocodella.com.br
 */

@interface PullableView()
@property (readwrite, assign) CGPoint startPos;
@property (readwrite, assign) CGPoint minPos;
@property (readwrite, assign) CGPoint maxPos;
@property (readwrite, assign) BOOL verticalAxis;
@end

@implementation PullableView

@synthesize handleView = _handleView;
@synthesize closedCenter = _closedCenter;
@synthesize openedCenter = _openedCenter;
@synthesize dragRecognizer = _dragRecognizer;
@synthesize tapRecognizer = _tapRecognizer;
@synthesize animate = _animate;
@synthesize animationDuration = _animationDuration;
@synthesize delegate = _delegate;
@synthesize toggleOnTap = _toggleOnTap;
@synthesize opened = _opened;
@synthesize startPos = _startPos;
@synthesize minPos = _minPos;
@synthesize maxPos = _maxPos;
@synthesize verticalAxis = _verticalAxis;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.animate = YES;
        self.animationDuration = 0.2;
        
        self.toggleOnTap = YES;
        
        // Creates the handle view. Subclasses should resize, reposition and style this view
        _handleView = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 40, frame.size.width, 40)];
        [self addSubview:self.handleView];
        
        _dragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
        self.dragRecognizer.minimumNumberOfTouches = 1;
        self.dragRecognizer.maximumNumberOfTouches = 1;
        
        [self.handleView addGestureRecognizer:self.dragRecognizer];
        
        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        self.tapRecognizer.numberOfTapsRequired = 1;
        self.tapRecognizer.numberOfTouchesRequired = 1;
        
        [self.handleView addGestureRecognizer:self.tapRecognizer];
        
        _opened = NO;
    }
    return self;
}

- (void)handleDrag:(UIPanGestureRecognizer *)sender {
    
    if ([sender state] == UIGestureRecognizerStateBegan) {
        
        self.startPos = self.center;
        
        // Determines if the view can be pulled in the x or y axis
        self.verticalAxis = self.closedCenter.x == self.openedCenter.x;
        
        // Finds the minimum and maximum points in the axis
        if (self.verticalAxis) {
            self.minPos = self.closedCenter.y < self.openedCenter.y ? self.closedCenter :self.openedCenter;
            self.maxPos = self.closedCenter.y > self.openedCenter.y ? self.closedCenter : self.openedCenter;
        } else {
            self.minPos = self.closedCenter.x < self.openedCenter.x ? self.closedCenter : self.openedCenter;
            self.maxPos = self.closedCenter.x > self.openedCenter.x ? self.closedCenter : self.openedCenter;
        }
        
    } else if ([sender state] == UIGestureRecognizerStateChanged) {
        
        CGPoint translate = [sender translationInView:self.superview];
        
        CGPoint newPos;
        
        // Moves the view, keeping it constrained between openedCenter and closedCenter
        if (self.verticalAxis) {
            
            newPos = CGPointMake(self.startPos.x, self.startPos.y + translate.y);
            
            if (newPos.y < self.minPos.y) {
                newPos.y = self.minPos.y;
                translate = CGPointMake(0, newPos.y - self.startPos.y);
            }
            
            if (newPos.y > self.maxPos.y) {
                newPos.y = self.maxPos.y;
                translate = CGPointMake(0, newPos.y - self.startPos.y);
            }
        } else {
            
            newPos = CGPointMake(self.startPos.x + translate.x, self.startPos.y);
            
            if (newPos.x < self.minPos.x) {
                newPos.x = self.minPos.x;
                translate = CGPointMake(newPos.x - self.startPos.x, 0);
            }
            
            if (newPos.x > self.maxPos.x) {
                newPos.x = self.maxPos.x;
                translate = CGPointMake(newPos.x - self.startPos.x, 0);
            }
        }
        
        [sender setTranslation:translate inView:self.superview];
        
        self.center = newPos;
        
    } else if ([sender state] == UIGestureRecognizerStateEnded) {
        
        // Gets the velocity of the gesture in the axis, so it can be
        // determined to which endpoint the state should be set.
        
        CGPoint vectorVelocity = [sender velocityInView:self.superview];
        CGFloat axisVelocity = self.verticalAxis ? vectorVelocity.y : vectorVelocity.x;
        
        CGPoint target = axisVelocity < 0 ? self.minPos : self.maxPos;
        BOOL op = CGPointEqualToPoint(target, self.openedCenter);
        
        [self setOpened:op animated:self.animate];
    }
}

- (void)handleTap:(UITapGestureRecognizer *)sender {
    
    if ([sender state] == UIGestureRecognizerStateEnded) {
        [self setOpened:!self.opened animated:self.animate];
    }
}

- (void)setToggleOnTap:(BOOL)tap {
    _toggleOnTap = tap;
    self.tapRecognizer.enabled = tap;
}

- (BOOL)toggleOnTap {
    return _toggleOnTap;
}

- (void)setOpened:(BOOL)op animated:(BOOL)anim {
    _opened = op;
    
    if (anim) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:self.animationDuration];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    }
    
    self.center = self.opened ? self.openedCenter : self.closedCenter;
    
    if (anim) {
        
        // For the duration of the animation, no further interaction with the view is permitted
        self.dragRecognizer.enabled = NO;
        self.tapRecognizer.enabled = NO;
        
        [UIView commitAnimations];
        
    } else {
        
        if ([self.delegate respondsToSelector:@selector(pullableView:didChangeState:)]) {
            [self.delegate pullableView:self didChangeState:self.opened];
        }
    }
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    if (finished) {
        // Restores interaction after the animation is over
        self.dragRecognizer.enabled = YES;
        self.tapRecognizer.enabled = self.toggleOnTap;
        
        if ([self.delegate respondsToSelector:@selector(pullableView:didChangeState:)]) {
            [self.delegate pullableView:self didChangeState:self.opened];
        }
    }
}

@end
