//
//  ViewController.m
//  server
//
//  Created by loyinglin on 2018/1/9.
//  Copyright © 2018年 loyinglin. All rights reserved.
//

#import "ViewController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "LYPlayer.h"


typedef NS_ENUM(int32_t, ProtocolType) {
    ProtocolTypeNone = 0,
    ProtocolTypeDelay = 10, // A向B发送一条消息，B立刻返回，A接受到返回的消息，计算两次消息的延迟；
    ProtocolTypeDelayReq = 11,
    ProtocolTypeDelayRsp = 12,
    
    
    ProtocolTypeBps = 20, // A向B发送一条start消息，然后是10M数据，最后是一条end消息；B计算start到end消息直接的收包时间；
};


@interface ViewController () <MCSessionDelegate, MCAdvertiserAssistantDelegate, MCBrowserViewControllerDelegate, NSStreamDelegate>

@property (nonatomic, strong) MCSession *mSession;
@property (nonatomic, strong) MCAdvertiserAssistant *mAdvertiserAssistant;
@property (nonatomic, strong) MCBrowserViewController *mBrowserVC;

@property (nonatomic, strong) NSInputStream *mInputStream;
@property (nonatomic, strong) NSOutputStream *mOutputStream;

@property (nonatomic, assign) int mProtocolType;
@property (nonatomic, strong) NSDate *mDelayStartDate;

@property (nonatomic, assign) int count;
@property (nonatomic, assign) NSTimeInterval averageDelayTime;

@end

static const int port = 51515;

@implementation ViewController
{
    AudioUnit audioUnit;
    AudioBufferList *buffList;
    
    NSInputStream *inputSteam;
    
    LYPlayer *player;
}

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
    [sendBtn setTitle:@"send data" forState:UIControlStateNormal];
    [sendBtn sizeToFit];
    sendBtn.center = CGPointMake(200, 250);
    [sendBtn addTarget:self action:@selector(sendData) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sendBtn];
    
    UIButton *delayBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [delayBtn setTitle:@"start delay test" forState:UIControlStateNormal];
    [delayBtn sizeToFit];
    delayBtn.center = CGPointMake(200, 300);
    [delayBtn addTarget:self action:@selector(startDelayTest) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:delayBtn];
    
    // mc
    MCPeerID *peerId = [[MCPeerID alloc] initWithDisplayName:@"server"];
    self.mSession = [[MCSession alloc] initWithPeer:peerId];
    self.mSession.delegate = self;
    
    self.mAdvertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:@"connect" discoveryInfo:nil session:self.mSession];
    self.mAdvertiserAssistant.delegate = self;
    

}

#pragma mark - MCSessionDelegate

// Remote peer changed state.
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (session == self.mSession) {
        NSLog(@"id%@, changeState to:%ld ", peerID.displayName, state);
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
        NSLog(@"didReceiveData:%@ from id:%@", [data description], peerID.displayName);
    }
}

// Received a byte stream from remote peer.
- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID {
    if (self.mSession == session) {
        NSLog(@"didReceiveStream:%@, named:%@ from id:%@", [stream description], streamName, peerID.displayName);
        
//        self.mInputStream = stream;
//        self.mInputStream.delegate = self;
//        [self.mInputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
//        [self.mInputStream open];
        
        player = [[LYPlayer alloc] init];
        player.mInputStream = stream;
        [stream open];
        //        [self.mInputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [player play];
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

#pragma mark - MCAdvertiserAssistantDelegate
// An invitation will be presented to the user.
- (void)advertiserAssistantWillPresentInvitation:(MCAdvertiserAssistant *)advertiserAssistant {
    NSLog(@"advertiserAssistantWillPresentInvitation");
}

// An invitation was dismissed from screen.
- (void)advertiserAssistantDidDismissInvitation:(MCAdvertiserAssistant *)advertiserAssistant {
    NSLog(@"advertiserAssistantDidDismissInvitation");
}


#pragma mark - MCBrowserViewControllerDelegate
// Notifies the delegate, when the user taps the done button.
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    NSLog(@"已选择");
    [self.mBrowserVC dismissViewControllerAnimated:YES completion:nil];
}

// Notifies delegate that the user taps the cancel button.
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    NSLog(@"取消.");
    [self.mBrowserVC dismissViewControllerAnimated:YES completion:nil];
}


- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController
      shouldPresentNearbyPeer:(MCPeerID *)peerID
            withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info{
    NSLog(@"shouldPresentNearbyPeer:%@", peerID.displayName);
    return YES;
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

- (void)sendData {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"chenli" ofType:@"mp3"];
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:nil];
    if (self.mSession.connectedPeers && self.mSession.connectedPeers.count > 0) {
        [self.mSession sendData:data toPeers:self.mSession.connectedPeers withMode:MCSessionSendDataUnreliable error:nil];
    }
}

- (void)startDelayTest {
    self.mDelayStartDate = [NSDate dateWithTimeIntervalSinceNow:0];
    
    if (!self.mOutputStream) {
        self.mOutputStream = [self.mSession startStreamWithName:@"delayTestServer" toPeer:[self.mSession.connectedPeers firstObject] error:nil];
//        [self.mOutputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [self.mOutputStream open];
    }
    
    [self play];
}


#pragma mark - player

static const uint32_t CONST_BUFFER_SIZE = 0x10000;

#define INPUT_BUS 1
#define OUTPUT_BUS 0

- (void)play {
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}


- (double)getCurrentTime {
    Float64 timeInterval = 0;
    if (inputSteam) {
        
    }
    
    return timeInterval;
}



- (void)initPlayer {
    player = [[LYPlayer alloc] init];
    [player play];
    
    // open pcm stream
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"pcm"];
    inputSteam = [NSInputStream inputStreamWithURL:url];
    if (!inputSteam) {
        NSLog(@"打开文件失败 %@", url);
    }
    else {
        [inputSteam open];
    }
    
    NSError *error = nil;
    OSStatus status = noErr;
    
    // set audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    // buffer
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    //audio property
    UInt32 flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status) {
        NSLog(@"AudioUnitSetProperty error with status:%d", status);
    }
    
    // format
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 44100;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBytesPerFrame    = 2;
    outputFormat.mBytesPerPacket   = 2;
    outputFormat.mBitsPerChannel   = 16;
    [self printAudioStreamBasicDescription:outputFormat];
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"AudioUnitSetProperty eror with status:%d", status);
    }
    
    
    // callback
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result %d", result);
}


static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    ViewController *player = (__bridge ViewController *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize = (UInt32)[player->inputSteam read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    [player->_mOutputStream write:ioData->mBuffers[0].mData maxLength:ioData->mBuffers[0].mDataByteSize];
    NSLog(@"out size local: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    return noErr;
}


- (void)stop {
    AudioOutputUnitStop(audioUnit);
    if (player) {
        [player stop];
        player = nil;
    }
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        free(buffList);
        buffList = NULL;
    }
    
    [inputSteam close];
}

- (void)dealloc {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    
    if (buffList != NULL) {
        free(buffList);
        buffList = NULL;
    }
}


- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}

@end
