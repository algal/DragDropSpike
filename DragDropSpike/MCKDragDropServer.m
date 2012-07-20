//
//  MCKDragDropServer.m
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-20.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import "MCKDragDropServer.h"


@interface MCKDragDropServer ()
@property (strong) NSMutableDictionary * donorViews;
@property (strong) NSMutableDictionary * absorberViews;
@end


@implementation MCKDragDropServer
/*
  Must handle clearing this dictionary as views are removed.
  Perhaps use associated references intead of a dict?
 */
@synthesize donorViews = _donorViews;
@synthesize absorberViews = _absorberViews;

#pragma mark - Singleton boilerplate

// singleton implementation
static MCKDragDropServer* sharedServer = nil;

+(MCKDragDropServer*)sharedServer
{
  @synchronized(self) {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{ sharedServer = [[self alloc] init]; });
  }
  return sharedServer;
}

#pragma mark -

-(id)init
{
  self = [super init];
  if (self) {
    _donorViews = [NSMutableDictionary dictionary];
    _absorberViews = [NSMutableDictionary dictionary];
  }
  return self;
}

@end
