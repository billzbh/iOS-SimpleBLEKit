//
//  Typedef.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#ifndef Typedef_h_SimpleBLEKit
#define Typedef_h_SimpleBLEKit

#include <objc/runtime.h>

@class SimplePeripheral;


typedef void (^SearchBlock)(SimplePeripheral* _Nonnull peripheral);


/**
 调用connectDevice后的回调，得到是否正常通讯的标志。
 
 @param isPrepareToCommunicate YES，可以开始通讯；NO ，通讯通道未准备好，不能通讯
 */
typedef void (^BLEStatusBlock)(BOOL isPrepareToCommunicate);

/**
 调用scanAndConnected:callback:后的回调，得到外设对象以及是否正常通讯的标志。
 
 @param peripheral  外设对象
 @param isPrepareToCommunicate YES，可以开始通讯；NO ，通讯通道未准备好，不能通讯
 
 */
typedef void (^searchAndConnectBlock)(SimplePeripheral* _Nonnull peripheral,BOOL isPrepareToCommunicate);

/**
 发送数据后接受数据的结果回调
 @param outData 有值时表示收到的数据包
 @param error 这里有值表示超时
 */
typedef void (^receiveDataBlock)(NSData * _Nullable outData,NSError * _Nullable error);
typedef void (^updateDataBlock)(NSData * _Nullable updateData);
typedef void (^readDataBlock)(NSData * _Nullable readData);
typedef BOOL (^PacketVerifyEvaluator)(NSData * __nullable inputData);
typedef BOOL (^NeekAckEvaluator)(NSData * __nullable inputData);
typedef void (^setupAfterConnected)(void);



/**
 
 作者：编程小翁
 链接：http://www.jianshu.com/p/fed1dcb1ac9f
 */

#define WZLSERIALIZE_CODER_DECODER()     \
\
- (id)initWithCoder:(NSCoder *)coder    \
{   \
NSLog(@"%s",__func__);  \
Class cls = [self class];   \
while (cls != [NSObject class]) {   \
/*判断是自身类还是父类*/    \
BOOL bIsSelfClass = (cls == [self class]);  \
unsigned int iVarCount = 0; \
unsigned int propVarCount = 0;  \
unsigned int sharedVarCount = 0;    \
Ivar *ivarList = bIsSelfClass ? class_copyIvarList([cls class], &iVarCount) : NULL;/*变量列表，含属性以及私有变量*/   \
objc_property_t *propList = bIsSelfClass ? NULL : class_copyPropertyList(cls, &propVarCount);/*属性列表*/   \
sharedVarCount = bIsSelfClass ? iVarCount : propVarCount;   \
\
for (int i = 0; i < sharedVarCount; i++) {  \
const char *varName = bIsSelfClass ? ivar_getName(*(ivarList + i)) : property_getName(*(propList + i)); \
NSString *key = [NSString stringWithUTF8String:varName];   \
id varValue = [coder decodeObjectForKey:key];   \
NSArray *filters = @[@"superclass", @"description", @"debugDescription", @"hash"]; \
if (varValue && [filters containsObject:key] == NO) { \
[self setValue:varValue forKey:key];    \
}   \
}   \
free(ivarList); \
free(propList); \
cls = class_getSuperclass(cls); \
}   \
return self;    \
}   \
\
- (void)encodeWithCoder:(NSCoder *)coder    \
{   \
NSLog(@"%s",__func__);  \
Class cls = [self class];   \
while (cls != [NSObject class]) {   \
/*判断是自身类还是父类*/    \
BOOL bIsSelfClass = (cls == [self class]);  \
unsigned int iVarCount = 0; \
unsigned int propVarCount = 0;  \
unsigned int sharedVarCount = 0;    \
Ivar *ivarList = bIsSelfClass ? class_copyIvarList([cls class], &iVarCount) : NULL;/*变量列表，含属性以及私有变量*/   \
objc_property_t *propList = bIsSelfClass ? NULL : class_copyPropertyList(cls, &propVarCount);/*属性列表*/ \
sharedVarCount = bIsSelfClass ? iVarCount : propVarCount;   \
\
for (int i = 0; i < sharedVarCount; i++) {  \
const char *varName = bIsSelfClass ? ivar_getName(*(ivarList + i)) : property_getName(*(propList + i)); \
NSString *key = [NSString stringWithUTF8String:varName];    \
/*valueForKey只能获取本类所有变量以及所有层级父类的属性，不包含任何父类的私有变量(会崩溃)*/  \
id varValue = [self valueForKey:key];   \
NSArray *filters = @[@"superclass", @"description", @"debugDescription", @"hash"]; \
if (varValue && [filters containsObject:key] == NO) { \
[coder encodeObject:varValue forKey:key];   \
}   \
}   \
free(ivarList); \
free(propList); \
cls = class_getSuperclass(cls); \
}   \
}

#endif /* Typedef_h_SimpleBLEKit */


