//
//  MCKDragDropServer.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-20.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCKDragDropProtocol.h"

@interface MCKDragDropServer : NSObject

+(MCKDragDropServer*)sharedServer;

-(void) registerDraggableView:(UIView*)draggableView;
-(void) registerDonorView:(UIView*)view delegate:(NSObject<MCKDnDDonorProtocol>*)delegate;
-(void) registerAbsorberView:(UIView*)view delegate:(NSObject<MCKDnDAbsorberProtocol>*)delegate;

@end
