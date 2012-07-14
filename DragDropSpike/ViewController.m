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

@end
