//
//  MIWCIViewController.m
//  MIWireSessioniOS
//
//  Created by BenArvin on 11/17/2020.
//  Copyright (c) 2020 BenArvin. All rights reserved.
//

#import "MIWCIViewController.h"
#import <MIWireSessioniOS/MIWireSessioniOS.h>

@interface MIWCIViewController() <MIWSLoggerReceiverProtocol>

@property (nonatomic) UITextView *resTextView;
@property (nonatomic) UITextView *logTextView;
@property (nonatomic) UITextView *inputTextView;
@property (nonatomic) UIButton *sendButton;
@property (nonatomic) MIWireSessioniOS *session;

@end

@implementation MIWCIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.session = [[MIWireSessioniOS alloc] initWithPort:2371];
    [self.session setLogReceiver:self];
    [self.session start];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPushReceived:) name:kMIWireSessioniOSNotificationPushReceived object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onConnected) name:kMIWireSessioniOSNotificationConnected object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDisconnected) name:kMIWireSessioniOSNotificationDisconnected object:nil];
    
    self.resTextView = [[UITextView alloc] init];
    self.resTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.resTextView.layer.borderWidth = 1;
    self.resTextView.textColor = [UIColor blackColor];
    self.resTextView.font = [UIFont systemFontOfSize:12];
    self.resTextView.textAlignment = NSTextAlignmentLeft;
    self.resTextView.editable = NO;
    
    self.logTextView = [[UITextView alloc] init];
    self.logTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.logTextView.layer.borderWidth = 1;
    self.logTextView.textColor = [UIColor blackColor];
    self.logTextView.font = [UIFont systemFontOfSize:12];
    self.logTextView.textAlignment = NSTextAlignmentLeft;
    self.logTextView.editable = NO;
    
    self.inputTextView = [[UITextView alloc] init];
    self.inputTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.inputTextView.layer.borderWidth = 1;
    self.inputTextView.textColor = [UIColor blackColor];
    self.inputTextView.font = [UIFont systemFontOfSize:18];
    self.inputTextView.textAlignment = NSTextAlignmentLeft;
    self.inputTextView.editable = YES;
    
    self.sendButton = [[UIButton alloc] init];
    self.sendButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.sendButton.layer.borderWidth = 1;
    [self.sendButton setTitle:@"send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.sendButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.sendButton addTarget:self action:@selector(sendBtnAction) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.resTextView];
    [self.view addSubview:self.logTextView];
    [self.view addSubview:self.inputTextView];
    [self.view addSubview:self.sendButton];
    
    UITapGestureRecognizer *tapGest = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBgTapped)];
    [self.view addGestureRecognizer:tapGest];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.inputTextView.frame = CGRectMake(10, 50, self.view.bounds.size.width - 20, 20);
    self.sendButton.frame = CGRectMake(floor((self.view.bounds.size.width - 50) / 2), CGRectGetMaxY(self.inputTextView.frame) + 20, 50, 30);
    CGFloat height = (self.view.bounds.size.height - CGRectGetMaxY(self.sendButton.frame) - 40 - 20) / 2;
    self.resTextView.frame = CGRectMake(10, CGRectGetMaxY(self.sendButton.frame) + 20, self.view.bounds.size.width - 20, height);
    self.logTextView.frame = CGRectMake(10, CGRectGetMaxY(self.resTextView.frame) + 20, self.view.bounds.size.width - 20, height);
}

- (void)sendBtnAction {
    if (!self.inputTextView.text || self.inputTextView.text.length == 0) {
        return;
    }
    NSString *text = self.inputTextView.text;
    self.inputTextView.text = nil;
    [self printResData:[NSString stringWithFormat:@"Send request: %@", text?:@"NULL"]];
    [self.session request:@"testReq" data:[text dataUsingEncoding:NSUTF8StringEncoding] completion:^(NSData *response, NSError *error) {
        if (error) {
            [self printResData:[NSString stringWithFormat:@"Response received: failed, %@", [error localizedDescription]]];
        } else {
            if (response) {
                NSString *resStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                [self printResData:[NSString stringWithFormat:@"Response received: %@", resStr]];
            } else {
                [self printResData:@"Response received: NULL"];
            }
        }
    }];
}

- (void)onWireSessionLog:(NSString *)log {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.logTextView.text) {
            self.logTextView.text = log?:@"NULL";
        } else {
            self.logTextView.text = [NSString stringWithFormat:@"%@\n%@", self.logTextView.text, log];
        }
    });
}

- (void)onPushReceived:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    if (!userInfo) {
        [self printResData:@"Push received, null"];
    } else {
        NSData *data = [userInfo objectForKey:kMIWireSessioniOSNotificationKeyData];
        if (!data) {
            [self printResData:@"Push received, null"];
            return;
        }
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self printResData:[NSString stringWithFormat:@"Push received: %@", str]];
    }

}

- (void)printResData:(NSString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.resTextView.text) {
            self.resTextView.text = str?:@"NULL";
        } else {
            self.resTextView.text = [NSString stringWithFormat:@"%@\n%@", self.resTextView.text, str];
            if(self.resTextView.text.length > 0 ) {
                NSRange bottom = NSMakeRange(self.resTextView.text.length -1, 1);
                [self.resTextView scrollRangeToVisible:bottom];
            }
        }
    });
}

- (void)onConnected {
    [self printResData:@"✅ Connected!"];
}

- (void)onDisconnected {
    [self printResData:@"❌ Disconnected!"];
}

- (void)onBgTapped {
    [self.inputTextView resignFirstResponder];
}

@end
