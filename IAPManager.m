//
//  IAPManager.m
//  EvilCartoon
//
//  Created by willonboy zhang on 12-7-19.
//  Copyright (c) 2012年 willonboy.tk. All rights reserved.
//


    //向苹果验证IAP的地址有两个, 一个是测试账号用的验证地址, 另一个是实际发布后的验证地址
#if DEBUG
    #define VAILDATING_RECEIPTS_URL @"https://sandbox.itunes.apple.com/verifyReceipt"
#else
    #define VAILDATING_RECEIPTS_URL @"https://buy.itunes.apple.com/verifyReceipt"
#endif





#import "IAPManager.h"

@interface IAPManager()

- (void)addStoreObserver;

    //向苹果app store确认是否真正购买过
- (VerifyReceiptResult)verifyReceipt:(SKPaymentTransaction *)transaction;

@end






Class object_getClass(id object);
@implementation IAPManager
@synthesize delegate = _delegate;
static IAPManager *_instance = nil;



- (id)init
{
    self = [super init];
    if (self) 
    {
        [self addStoreObserver];
    }
    
    return self;
}


- (void)dealloc 
{
    self.delegate = nil;
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    [super dealloc];
}

- (void)setDelegate:(id)delegate_
{
    delegateClass = object_getClass(delegate_);
    _delegate = delegate_;
}


+ (IAPManager *)shareInstance
{
    if (!_instance) 
    {
        return _instance = [[IAPManager alloc] init];
    }
    
    return _instance;
}

+ (void)destroyShareInstance
{
    if (_instance)
    {
        _instance.delegate = nil;
        [_instance release];
        _instance = nil;
    }
}

+ (BOOL)canMakePayments;
{
    return [SKPaymentQueue canMakePayments];
}

- (void)addStoreObserver;
{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

    //恢复店内付
- (void)restoreBatchTransactions;
{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}


- (void)buyIAPProductWithIndetifier:(NSString *)identifier;
{
    if (![SKPaymentQueue canMakePayments])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"当前设备不支持店内付购买" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alert show];
        [alert release];
        alert = nil;
        
        return;
    } 
    
    SKProductsRequest *request = [[[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:identifier]] autorelease];
    request.delegate = self;
    [request start];
}


    //向苹果app store确认是否真正购买过
- (VerifyReceiptResult)verifyReceipt:(SKPaymentTransaction *)transaction;
{
    if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(verifyReceipt:)])
    {
        return [_delegate verifyReceipt:transaction];
    }
    
    return VerifyReceiptResult_NONE;
}





#pragma mark - 
#pragma mark - SKPaymentTransactionObserver

    // Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"进入购买流程");
                break;
                
            case SKPaymentTransactionStatePurchased:
            {
                NSLog(@"成功购买");
                if ([self verifyReceipt:transaction] != VerifyReceiptResult_FAILED)
                {
                    
                    if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(completeTransaction:)])
                    {
                        [_delegate completeTransaction:transaction];
                    }
                }  
                else
                {
                    if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(failedTransaction:)])
                    {
                        [_delegate failedTransaction:transaction];
                    }
                }
                
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
                
            case SKPaymentTransactionStateFailed:
            {
                NSLog(@"购买失败");
                if(transaction.error.code != SKErrorPaymentCancelled)
                {
                    if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(failedTransaction:)])
                    {
                        [_delegate failedTransaction:transaction];
                    }
                }
                else
                {
                    if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(cancelTransaction:)])
                    {
                        [_delegate cancelTransaction:transaction];
                    }
                }
                
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
                
            case SKPaymentTransactionStateRestored:
            {
				NSLog(@"购买过的商品");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
                
            default:
                break;
        }
    }
}

    // Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    
    NSLog(@"paymentQueue - %@", error);
    
    if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(restoreBatchTransactions:)])
    {
        [_delegate restoreBatchTransactions:nil];
    }
}

    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSLog(@"待店内付恢复项: %i", queue.transactions.count);
    
    if (queue.transactions.count > 0)
    {
        NSMutableArray *tranArr = [[NSMutableArray alloc] init];
        for (SKPaymentTransaction *transaction in queue.transactions)
        {
            [tranArr addObject:transaction.payment.productIdentifier];
        }
        
        if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(restoreBatchTransactions:)])
        {
            [_delegate restoreBatchTransactions:tranArr];
        }
        
        [tranArr release];
    } 
}



#pragma mark -
#pragma mark SKProductsRequestDelegate
    // Sent immediately before -requestDidFinish:
    //处理返回的产品信息,将购买产品添加到购买队列
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *iapProducts = response.products;
    
        //请求交易数据失败
    if([iapProducts count] == 0)
    {
        if(_delegate && delegateClass == object_getClass(_delegate) && [_delegate respondsToSelector:@selector(downloadIAPDataFailed)])
        {
            [_delegate downloadIAPDataFailed];
        }
        
        return;
    }
    
    NSLog(@"[myProducts count] %u", [iapProducts count]);
  
    for(int i=0; i < [iapProducts count]; i++)
    {
        SKProduct *pro = [iapProducts objectAtIndex:i];
        NSLog(@"title:%@",pro.localizedTitle);
        NSLog(@"desp:%@",pro.localizedDescription);
        NSLog(@"price:%@",pro.price);
        NSLog(@"indefifier:%@",pro.productIdentifier);
            
            //添加进购买队列
        [[SKPaymentQueue defaultQueue] addPayment:[SKPayment paymentWithProductIdentifier:pro.productIdentifier]];
    }
}

@end






