//
//  hmudqpro-Bridging-Header.h
//  百度统计为静态库 pod（无 Swift module），经桥接头暴露给 Swift。
//
#ifndef hmudqpro_Bridging_Header_h
#define hmudqpro_Bridging_Header_h

// 百度统计只有真机切片，模拟器构建不引入（对应 SDKBootstrap 的 targetEnvironment(simulator) 分支）
#if !TARGET_OS_SIMULATOR
#import <BaiduMobStatCodeless/BaiduMobStat.h>
#endif

#endif
