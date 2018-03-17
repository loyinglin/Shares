//
//  ProtocolType.h
//  server
//
//  Created by loyinglin on 2018/3/17.
//  Copyright © 2018年 loyinglin. All rights reserved.
//

#ifndef ProtocolType_h
#define ProtocolType_h

typedef NS_ENUM(int32_t, ProtocolType) {
    ProtocolTypeNone = 0,
    //ProtocolTypeDelay A向B发送一条消息，B立刻返回，A接受到返回的消息，计算两次消息的延迟；
    ProtocolTypeDelayReq = 11,
    ProtocolTypeDelayRsp = 12,
    
    
    //ProtocolTypeBps A向B发送一条start消息，然后是10M数据，B收到10M数据后返回end消息；
    ProtocolTypeBpsStart = 21,
    ProtocolTypeBpsEnd = 22,
    
};



#endif /* ProtocolType_h */
