//
//  ViewController.m
//  server
//
//  Created by loyinglin on 2018/1/9.
//  Copyright © 2018年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import "ProtocolType.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>


@interface ViewController () <MCSessionDelegate, MCAdvertiserAssistantDelegate, MCBrowserViewControllerDelegate, NSStreamDelegate>

@property (nonatomic, strong) MCSession *mSession;
@property (nonatomic, strong) MCAdvertiserAssistant *mAdvertiserAssistant;
@property (nonatomic, strong) MCBrowserViewController *mBrowserVC;

@property (nonatomic, strong) NSInputStream *mInputStream;
@property (nonatomic, strong) NSOutputStream *mOutputStream;

@property (nonatomic, assign) int mProtocolType;
@property (nonatomic, assign) int mDelayCount;
@property (nonatomic, assign) float mAverageDelayTime;
@property (nonatomic, strong) NSDate *mDelayStartDate;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // ui
    UILabel *ipLabel = [[UILabel alloc] init];
    ipLabel.text = [NSString stringWithFormat:@"device: server"];
    [ipLabel sizeToFit];
    ipLabel.center = CGPointMake(200, 100);
    [self.view addSubview:ipLabel];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"start" forState:UIControlStateNormal];
    [btn sizeToFit];
    btn.center = CGPointMake(200, 150);
    [btn addTarget:self action:@selector(startServer) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    UIButton *showBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [showBtn setTitle:@"show nearby" forState:UIControlStateNormal];
    [showBtn sizeToFit];
    showBtn.center = CGPointMake(200, 200);
    [showBtn addTarget:self action:@selector(showNearbyPeer) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:showBtn];
    
    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [sendBtn setTitle:@"start delay test" forState:UIControlStateNormal];
    [sendBtn sizeToFit];
    sendBtn.center = CGPointMake(200, 250);
    [sendBtn addTarget:self action:@selector(startDelayTest) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sendBtn];
    
    UIButton *delayBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [delayBtn setTitle:@"start auto delay test" forState:UIControlStateNormal];
    [delayBtn sizeToFit];
    delayBtn.center = CGPointMake(200, 300);
    [delayBtn addTarget:self action:@selector(startAutoDelayTest) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:delayBtn];
    
    // mc
    MCPeerID *peerId = [[MCPeerID alloc] initWithDisplayName:@"server"];
    self.mSession = [[MCSession alloc] initWithPeer:peerId];
    self.mSession.delegate = self;
    
    self.mAdvertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:@"connect" discoveryInfo:nil session:self.mSession];
    self.mAdvertiserAssistant.delegate = self;
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (session == self.mSession) {
        NSString *str;
        switch (state) {
            case MCSessionStateConnected:
                str = @"连接成功.";
                break;
            case MCSessionStateConnecting:
                str = @"正在连接...";
                break;
            default:
                str = @"连接失败.";
                self.mOutputStream = nil;
                break;
        }
        NSLog(@"id%@, changeState to:%@", peerID.displayName, str);
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    if (self.mSession == session) {
        NSLog(@"didReceiveData:%@ from id:%@", data, peerID.displayName);
    }
}

- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID {
    if (self.mSession == session) {
        NSLog(@"didReceiveInputStream:%@, named:%@ from id:%@", stream, streamName, peerID.displayName);
        
        if (self.mInputStream) {
            [self.mInputStream close];
        }
        self.mInputStream = stream;
        self.mInputStream.delegate = self;
        [self.mInputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [self.mInputStream open];
    }
}

- (void)                    session:(MCSession *)session
  didStartReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                       withProgress:(NSProgress *)progress {
    if (self.mSession == session) {
        NSLog(@"didStartReceivingResourceWithName:%@ from id:%@, total:%lld completion:%lld", resourceName, peerID.displayName, progress.totalUnitCount, progress.completedUnitCount);
    }
}

- (void)                    session:(MCSession *)session
 didFinishReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                              atURL:(nullable NSURL *)localURL
                          withError:(nullable NSError *)error { // 收到文件，必须把文件从url对应的位置，复制到APP的沙盒中
    
    if (self.mSession == session) {
        NSLog(@"didFinishReceivingResourceWithName:%@ from id:%@, localUrl:%@, error:%@", resourceName, peerID.displayName, localURL.absoluteString, [error description]);
    }
}

#pragma mark - MCAdvertiserAssistantDelegate
- (void)advertiserAssistantWillPresentInvitation:(MCAdvertiserAssistant *)advertiserAssistant {
    NSLog(@"advertiserAssistantWillPresentInvitation");
}

- (void)advertiserAssistantDidDismissInvitation:(MCAdvertiserAssistant *)advertiserAssistant {
    NSLog(@"advertiserAssistantDidDismissInvitation");
}


#pragma mark - MCBrowserViewControllerDelegate
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    NSLog(@"browserViewControllerDidFinish 已选择");
    [self.mBrowserVC dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    NSLog(@"browserViewControllerWasCancelled 取消.");
    [self.mBrowserVC dismissViewControllerAnimated:YES completion:nil];
}


- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController
      shouldPresentNearbyPeer:(MCPeerID *)peerID
            withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info{
    NSLog(@"shouldPresentNearbyPeer:%@", peerID.displayName);
    return YES;
}

#pragma mark -- NSStreamDelegate
/**
 *  流数据操作
 *
 *  @param aStream   流数据
 *  @param eventCode 流数据获取事件
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:{
            NSLog(@"NSStreamEventOpenCompleted");
        }
            break;
        case NSStreamEventHasBytesAvailable:{
            NSLog(@"NSStreamEventHasBytesAvailable");
            if (aStream == self.mInputStream) {
                [self onInputDataReady];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable: {
            NSLog(@"NSStreamEventHasSpaceAvailable");
        }
            break;
        case NSStreamEventEndEncountered: {
            NSLog(@"NSStreamEventEndEncountered");
            if (aStream == self.mInputStream) {
                self.mInputStream = nil;
            }
            if (aStream == self.mOutputStream) {
                self.mOutputStream = nil;
            }
            [aStream close];//关闭输出流
            [aStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];//将输出流从runloop中清除
            break;
        }
        case NSStreamEventErrorOccurred:{
            NSLog(@"NSStreamEventErrorOccurred");
            if (aStream == self.mInputStream) {
                self.mInputStream = nil;
            }
            if (aStream == self.mOutputStream) {
                self.mOutputStream = nil;
            }
            [aStream close];//关闭输出流
            [aStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];//将输出流从runloop中清除

            
        }
            break;
        default:
            break;
    }
}

#pragma mark - ui
- (void)startServer {
    [self.mAdvertiserAssistant start];
}

- (void)showNearbyPeer {
    if (!self.mBrowserVC) {
        self.mBrowserVC = [[MCBrowserViewController alloc] initWithServiceType:@"connect" session:self.mSession];
        self.mBrowserVC.delegate = self;
    }
    [self presentViewController:self.mBrowserVC animated:YES completion:nil];
}


- (void)startDelayTest {
    if (!self.mOutputStream) {
        self.mOutputStream = [self.mSession startStreamWithName:@"delayTestServer" toPeer:[self.mSession.connectedPeers firstObject] error:nil];
        self.mOutputStream.delegate = self;
        [self.mOutputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [self.mOutputStream open];
    }

    int32_t type = ProtocolTypeDelayReq;
    self.mDelayStartDate = [NSDate dateWithTimeIntervalSinceNow:0];
    [self.mOutputStream write:(uint8_t *)&type maxLength:4];

}

- (void)startAutoDelayTest {
    static int autoTestCount = 0;
    [self startDelayTest];
    
    if (autoTestCount < 10) {
        autoTestCount++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startAutoDelayTest];
        });
    }
    else {
        autoTestCount = 0;
    }
}

#pragma mark - data process

- (void)onInputDataReady {
    ProtocolType type = 0;
    [self.mInputStream read:(unsigned char *)&type maxLength:sizeof(type)];
    [self handleProtocolWithType:type];
}

- (void)handleProtocolWithType:(ProtocolType)type {
    if (type == ProtocolTypeDelayRsp) {
        NSDate *rspDate = [ NSDate dateWithTimeIntervalSinceNow:0];
        NSTimeInterval delay = [rspDate timeIntervalSinceDate:self.mDelayStartDate];
        self.mAverageDelayTime += delay * 1000;
        ++self.mDelayCount;
        NSLog(@"delay test with %.2lfms,  average delay time:%.2lfms", delay * 1000, self.mAverageDelayTime / self.mDelayCount);
    }
}

@end
