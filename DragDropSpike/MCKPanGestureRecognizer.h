//
//  MCKPanGestureRecognizer.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-16.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <UIKit/UIKit.h>

/*
 A UIPanGestureRecognizer, but with some additional properties that we need 
 to track over the extent of a DnD session.
 
 DESIGN NOTES:
 It is necessary to track certain info over the extent of a DnD session, such 
 as:
 - the being-dragged object's original position at pickup,
 - its original superview
 - its original Donor object
 - its visual properties before the application of a pickup animation
 
 Q: where to track these properties?
 
 One alternative is to define MCKDnDSession object, analagous to a
 NSDraggingSession. However, at present, the lifetime and visibility of that
 object would be exactly the same as the lifetime and visibility of the 
 pan gesture recognizer (GR) that enables dragging, so for now we just attach 
 these properties to the GR.
 
 We could attach them using associated object references, but for now it seems 
 simpler to define a custom subclass.
 
 */

@interface MCKPanGestureRecognizer : UIPanGestureRecognizer
@property (assign) CGRect initialViewFrame;
@property (strong) UIView * initialViewSuperview;
@property (assign) NSUInteger initialSubviewIndex;

/* (lowercase because a property, or uppercase because a function?) */
@property (strong) dispatch_block_t undoPickupEffectOnView;
           
@end
