//
//  IAPManager.h
//  EvilCartoon
//
//  Created by willonboy zhang on 12-7-19.
//  Copyright (c) 2012年 willonboy.tk. All rights reserved.
//


typedef enum
{
    VerifyReceiptResult_NONE = 0,   //没有提供验证函数 不验证
    VerifyReceiptResult_SUCCESS,    //验证购买成功
    VerifyReceiptResult_FAILED      //验证购买失败(可能是IAP被破解)
}VerifyReceiptResult;

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>


@protocol IAPManagerDelegate <NSObject>

- (void)completeTransaction:(SKPaymentTransaction *)transaction;
- (void)failedTransaction:(SKPaymentTransaction *)transaction;
    //- (void)restoreTransaction:(SKPaymentTransaction *)transaction;
- (void)cancelTransaction: (SKPaymentTransaction *)transaction;
- (void)restoreBatchTransactions:(NSArray *)transactions;
- (void)downloadIAPDataFailed;

    //验证购买的IAP产品收据 向苹果app store确认是否真正购买过 (注意: 该验证必须是同步的验证, 必须及时返回验证结果)
- (VerifyReceiptResult)verifyReceipt:(SKPaymentTransaction *)transaction;

@end


@interface IAPManager : NSObject<SKPaymentTransactionObserver, SKProductsRequestDelegate>
{
    Class   delegateClass;
}
@property (nonatomic, assign) id<IAPManagerDelegate> delegate;

+ (IAPManager *)shareInstance;
+ (void)destroyShareInstance;
+ (BOOL)canMakePayments;

    //恢复曾经购买过的非消耗型店内付产品
- (void)restoreBatchTransactions;
- (void)buyIAPProductWithIndetifier:(NSString *)identifier;



@end
