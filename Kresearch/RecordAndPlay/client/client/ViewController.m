//
//  ViewController.m
//  server
//
//  Created by loyinglin on 2018/1/9.
//  Copyright © 2018年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>


typedef NS_ENUM(int32_t, ProtocolType) {
    ProtocolTypeNone = 0,
    ProtocolTypeDelay = 10, // A向B发送一条消息，B立刻返回，A接受到返回的消息，计算两次消息的延迟；
    ProtocolTypeDelayReq = 11,
    ProtocolTypeDelayRsp = 12,
    
    
    ProtocolTypeBps = 20, // A向B发送一条start消息，然后是10M数据，最后是一条end消息；B计算start到end消息直接的收包时间；
};

@interface ViewController () <MCSessionDelegate, MCBrowserViewControllerDelegate, NSStreamDelegate>

@property (nonatomic, strong) MCSession *mSession;
@property (nonatomic, strong) MCBrowserViewController *mBrowserVC;
@property (nonatomic, strong) AVAudioPlayer *mPlayer;

@property (nonatomic, strong) NSInputStream *mInputStream;
@property (nonatomic, strong) NSOutputStream *mOutputStream;

@property (nonatomic, assign) int mProtocolType;
@end

const int port = 51515;
static u_int8_t buffer[1024 * 10 * 8];

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
    
    // mc
    MCPeerID *peerId = [[MCPeerID alloc] initWithDisplayName:@"client"];
    self.mSession = [[MCSession alloc] initWithPeer:peerId];
    self.mSession.delegate = self;
}

#pragma mark - MCSessionDelegate

// Remote peer changed state.
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (session == self.mSession) {
        NSLog(@"id:%@, changeState to:%ld ", peerID.displayName, state);
        switch (state) {
            case MCSessionStateConnected:
                NSLog(@"连接成功.");
                break;
            case MCSessionStateConnecting:
                NSLog(@"正在连接...");
                break;
            default:
                NSLog(@"连接失败.");
                break;
        }
    }
}

// Received data from remote peer.
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    if (self.mSession == session) {
        NSLog(@"didReceiveData:%@ from id:%@", data, peerID.displayName);
        if (data) {
            NSError *error;
            if (self.mPlayer) {
                [self.mPlayer stop];
            }
            self.mPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
            if (error) {
                NSLog(@"AVAudioPlayer initWithData error:%@", [error description]);
            }
            else {
                [self.mPlayer play];
            }
        }
    }
}

// Received a byte stream from remote peer.
- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID {
    if (self.mSession == session) {
        NSLog(@"didReceiveStream:%@, named:%@ from id:%@", [stream description], streamName, peerID.displayName);
        
        self.mInputStream = stream;
        self.mInputStream.delegate = self;
        [self.mInputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.mInputStream open];
        
        self.mOutputStream = [self.mSession startStreamWithName:@"delayTestClient" toPeer:[self.mSession.connectedPeers firstObject] error:nil];
        self.mOutputStream.delegate = self;
        [self.mOutputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.mOutputStream open];
    }
}

// Start receiving a resource from remote peer.
- (void)                    session:(MCSession *)session
  didStartReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                       withProgress:(NSProgress *)progress {
    if (self.mSession == session) {
        NSLog(@"didStartReceivingResourceWithName:%@ from id:%@, total:%lld completion:%lld", resourceName, peerID.displayName, progress.totalUnitCount, progress.completedUnitCount);
    }
}

// Finished receiving a resource from remote peer and saved the content
// in a temporary location - the app is responsible for moving the file
// to a permanent location within its sandbox.
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
// Notifies the delegate, when the user taps the done button.
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    NSLog(@"browserViewControllerDidFinish");
    [self.mBrowserVC dismissViewControllerAnimated:YES completion:nil];
}

// Notifies delegate that the user taps the cancel button.
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
/**
 *  流数据操作
 *
 *  @param aStream   流数据
 *  @param eventCode 流数据获取事件
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:{ //打开输出数据流通道或者打开输入数据流通道就会走到这一步
            NSLog(@"NSStreamEventOpenCompleted");
        }
            break;
        case NSStreamEventHasBytesAvailable:{//监测到输入流通道中有数据流，就把数据一点一点的拼接起来
//            NSLog(@"NSStreamEventHasBytesAvailable");
            if (aStream == self.mInputStream) {
                NSInteger length = [self.mInputStream read:buffer maxLength:sizeof(buffer)];
                NSLog(@"read length: %ld", length);
                
                [self.mOutputStream write:buffer maxLength:length];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable: {//监测到有内存空间可用，就把输出流通道中的流写入到内存空间
//            NSLog(@"NSStreamEventHasSpaceAvailable");
            
        }
            break;
        case NSStreamEventEndEncountered: { //监测到输出流通道中的流数据写入内存空间完成或者输入流通道中的流数据获取完成
            NSLog(@"NSStreamEventEndEncountered");
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
        case NSStreamEventErrorOccurred:{
            //发生错误
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
    if (!self.mBrowserVC) {
        self.mBrowserVC = [[MCBrowserViewController alloc] initWithServiceType:@"connect" session:self.mSession];
        self.mBrowserVC.delegate = self;
    }
    [self presentViewController:self.mBrowserVC animated:YES completion:nil];
    
}


@end
