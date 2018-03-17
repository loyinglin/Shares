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



@interface ViewController () <MCSessionDelegate, MCBrowserViewControllerDelegate, NSStreamDelegate>

@property (nonatomic, strong) MCSession *mSession;
@property (nonatomic, strong) MCBrowserViewController *mBrowserVC;

@property (nonatomic, strong) NSInputStream *mInputStream;
@property (nonatomic, strong) NSOutputStream *mOutputStream;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // ui
    UILabel *ipLabel = [[UILabel alloc] init];
    ipLabel.text = [NSString stringWithFormat:@"device: client"];
    [ipLabel sizeToFit];
    ipLabel.center = CGPointMake(200, 100);
    [self.view addSubview:ipLabel];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"start" forState:UIControlStateNormal];
    [btn sizeToFit];
    btn.center = CGPointMake(200, 150);
    [btn addTarget:self action:@selector(startServer) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    MCPeerID *peerId = [[MCPeerID alloc] initWithDisplayName:@"client"];
    self.mSession = [[MCSession alloc] initWithPeer:peerId];
    self.mSession.delegate = self;
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
                break;
        }
        NSLog(@"id:%@, changeState to:%@", peerID.displayName, str);
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    if (self.mSession == session) {
    }
}

- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID {
    if (self.mSession == session) {
        NSLog(@"didReceiveStream:%@, named:%@ from id:%@", [stream description], streamName, peerID.displayName);

        if (self.mInputStream) {
            [self.mInputStream close];
        }
        self.mInputStream = stream;
        self.mInputStream.delegate = self;
        [self.mInputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
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
                          withError:(nullable NSError *)error {
    if (self.mSession == session) {
        NSLog(@"didFinishReceivingResourceWithName:%@ from id:%@, localUrl:%@, error:%@", resourceName, peerID.displayName, localURL.absoluteString, [error description]);
    }
}

#pragma mark - MCBrowserViewControllerDelegate
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    NSLog(@"browserViewControllerDidFinish");
    [self.mBrowserVC dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    NSLog(@"browserViewControllerWasCancelled");
    [self.mBrowserVC dismissViewControllerAnimated:YES completion:nil];
}


- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController
      shouldPresentNearbyPeer:(MCPeerID *)peerID
            withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info{
    NSLog(@"shouldPresentNearbyPeer:%@", peerID.displayName);
    return YES;
}


#pragma mark -- NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:{ //打开输出数据流通道或者打开输入数据流通道就会走到这一步
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
            if (self.mOutputStream == aStream) {
            }
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
            [aStream close];
            [aStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            
        }
            break;
        case NSStreamEventErrorOccurred:{
            NSLog(@"NSStreamEventErrorOccurred");
            if (aStream == self.mInputStream) {
                self.mInputStream = nil;
            }
            if (aStream == self.mOutputStream) {
                self.mOutputStream = nil;
            }
            [aStream close];
            [aStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        }
            break;
        default:
            break;
    }
}

#pragma mark - ui

- (void)startServer {
    if (!self.mBrowserVC) {
        self.mBrowserVC = [[MCBrowserViewController alloc] initWithServiceType:@"connect" session:self.mSession];
        self.mBrowserVC.delegate = self;
    }
    [self presentViewController:self.mBrowserVC animated:YES completion:nil];
    
}

#pragma mark - data process

- (void)onInputDataReady {
    ProtocolType type = 0;
    [self.mInputStream read:(unsigned char *)&type maxLength:sizeof(type)];
    [self handleProtocolWithType:type];
}

- (void)handleProtocolWithType:(ProtocolType)type {
    if (!self.mOutputStream) {
        self.mOutputStream = [self.mSession startStreamWithName:@"delayTestClient" toPeer:[self.mSession.connectedPeers firstObject] error:nil];
        self.mOutputStream.delegate = self;
        [self.mOutputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.mOutputStream open];
    }
    if (type == ProtocolTypeDelayReq) {
        int32_t type = ProtocolTypeDelayRsp;
        [self.mOutputStream write:(uint8_t *)&type maxLength:4];
    }
}


@end
