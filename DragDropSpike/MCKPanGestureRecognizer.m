//
//  MCKPanGestureRecognizer.m
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-16.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import "MCKPanGestureRecognizer.h"

#import "MCKDragDropServer.h"
#import "MCKDragDropProtocol.h"

@implementation MCKPanGestureRecognizer
@synthesize initialViewFrame, initialViewSuperview, initialSubviewIndex,donorView;
@synthesize undoPickupEffectOnView;
@synthesize payload;

-(id)initWithTarget:(id)target action:(SEL)action {
  self = [super initWithTarget:target action:action];
  if ( self ) {
    [self setDelegate:self]; // naughty?
  }
  return self;
}

-(BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  UIView * dragView = gestureRecognizer.view;
  self.donorView = [[MCKDragDropServer sharedServer] donorViewOfView:dragView];
  if (! self.donorView) {
    PSLogError(@"drag aborted because no donor view was found");
    return NO;
  }
  else {
    NSObject <MCKDragDropDonorDelegate> * donorDelegate = [[MCKDragDropServer sharedServer] delegateForDonorView:self.donorView];
    if ( [donorDelegate respondsToSelector:@selector(donorView:shouldBeginDraggingView:)] )
      return [donorDelegate donorView:self.donorView shouldBeginDraggingView:dragView];
    else
      return YES;
  }
}

@end

