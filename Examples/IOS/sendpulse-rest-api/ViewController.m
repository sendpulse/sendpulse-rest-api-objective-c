//
//  ViewController.m
//  sendpulse-rest-api
//
//  Copyright (c) 2015 sendpulse.com. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController
static NSString *userId = @"";
static NSString *secret = @"";
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doSomethingWithTheData:) name:@"SendPulseNotification" object:nil];
    sendpulse = [[Sendpulse alloc] initWithUserIdandSecret:userId :secret];
    [sendpulse listAddressBooks:1 :0];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)doSomethingWithTheData:(NSNotification *)notification {
    NSMutableDictionary * result = [[notification userInfo] objectForKey:@"SendPulseData"];
    NSLog(@"Result: %@",result);
}
@end
