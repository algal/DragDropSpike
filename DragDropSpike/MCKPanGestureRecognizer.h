//
//  MCKPanGestureRecognizer.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-16.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <UIKit/UIKit.h>

/*
 A UIPanGestureRecognizer, but with some additional properties we need to track
 over the extent of a DnD session
 */
@interface MCKPanGestureRecognizer : UIPanGestureRecognizer
@property (assign) CGPoint initialViewFrameOrigin;
@end
