//
//  MainViewController.m
//  sendpulse-rest-api
//
//  Copyright (c) 2015 sendpulse.com. All rights reserved.
//

#import "MainViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController
static NSString *userId = @"";
static NSString *secret = @"";
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doSomethingWithTheData:) name:@"SendPulseNotification" object:nil];
    sendpulse = [[Sendpulse alloc] initWithUserIdandSecret:userId :secret];
    [sendpulse listAddressBooks:2 :0];
}

- (void)doSomethingWithTheData:(NSNotification *)notification {
    NSMutableDictionary * result = [[notification userInfo] objectForKey:@"SendPulseData"];
    NSLog(@"Result: %@",result);
}
@end
