//
//  ViewController.m
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-14.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController
@synthesize leftContainer;
@synthesize rightContainer;
@synthesize draggableButton;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [self setLeftContainer:nil];
    [self setRightContainer:nil];
    [self setDraggableButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return YES;
}


#pragma mark  MCKDnDDonorProtocol delegate

-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview {}
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview {}
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview {}
-(void) donorView:(UIView*)donor reclaimDraggingView:(UIView*)draggingSubview {}

#pragma mark MCKDnDAbsorberProtocol delegate

-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview
{
  return YES;
}

-(void) absorberView:(UIView*)absorber absorbDraggingView:(UIView*)draggingSubview
{
  return;
}


@end
