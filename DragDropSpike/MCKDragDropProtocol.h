//
//  MCKDragDropProtocol.h
//  discoveryboard
//
//  Created by Alexis Gallagher on 2012-07-14.
//
//

#import <Foundation/Foundation.h>

//
// delegate-based
//

@protocol MCKDnDDonorProtocol <NSObject>
// when view is picked up
-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview;
// if view is absorbed by dropped-on view.
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview;
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview;
// if view is rejected by the dropped-on view
-(void) donorView:(UIView*)donor didReclaimDraggingView:(UIView*)draggingSubview
@end

@protocol MCKDnDAbsorberProtocol <NSObject>
-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview;
-(void) absorberView:(UIView*)absorber absorbDraggingView:(UIView*)draggingSubview;
@end
