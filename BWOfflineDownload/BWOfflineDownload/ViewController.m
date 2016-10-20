//
//  ViewController.m
//  BWOfflineDownload
//
//  Created by mortal on 16/10/20.
//  Copyright © 2016年 mortal. All rights reserved.
//

#import "ViewController.h"

#define totalLengthPath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"totalLength.txt"]
#define downloadPath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"download.png"]

@interface ViewController () <NSURLSessionDataDelegate>
@property (strong, nonatomic) NSURLSessionDataTask *dataTask;
@property (strong, nonatomic) NSURLSession *session;
/** 文件的总长度 */
@property (assign, nonatomic) NSInteger totalLength;
/** 已经下载的文件长度 */
@property (assign, nonatomic) NSInteger curLength;
/** 文件句柄 */
@property (strong, nonatomic) NSFileHandle *fileHandle;
/** 输出流 */
@property (strong, nonatomic) NSOutputStream *outStream;
/** 下载进度 */
@property (weak, nonatomic) IBOutlet UIProgressView *downProgress;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //首先获取之前已经下载的文件属性
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:downloadPath error:nil];
    NSLog(@"fileInfo --- %@", fileInfo);
    //得到之前下载的文件数据大小
    self.curLength = [fileInfo fileSize];
    NSLog(@"之前已经下载的数据大小curLength --- %zd", self.curLength);
    
    //显示文件的进度信息
    NSData *dataSize = [NSData dataWithContentsOfFile:totalLengthPath];
    self.totalLength = [[[NSString alloc] initWithData:dataSize encoding:NSUTF8StringEncoding] integerValue];
    if (self.totalLength != 0) {
        self.downProgress.progress = 1.0 * self.curLength / self.totalLength;
    }
    
}

//当控制器消失的时候
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    //使用 session 设置代理，会造成对 session 的强引用，需要进行解除
    //方式一：等请求任务结束之后释放代理对象
    [self.session finishTasksAndInvalidate];
    //方式二：立即释放
    //    [self.session invalidateAndCancel];
}

- (NSURLSession *)session {
    if (_session == nil) {
        //创建会话对象 设置代理
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return _session;
}

- (NSURLSessionDataTask *)dataTask {
    if (_dataTask == nil) {
        
        //确定请求路径
        NSURL *url = [NSURL URLWithString:@"http://sony.it168.com/data/attachment/forum/201410/20/2154195j037033ujs7cio0.jpg"];
        //创建可变的请求对象
        NSMutableURLRequest *requestM = [NSMutableURLRequest requestWithURL:url];
        //设置请求的数据范围：为已下载好的数据到文件结束
        /*
         bytes=0-100
         bytes=500-1000
         bytes=-100 请求文件的前100个字节
         bytes=500- q 请求500之后的所有数据
         */
        NSString *rangeStr = [NSString stringWithFormat:@"bytes=%zd-", self.curLength];
        [requestM setValue:rangeStr forHTTPHeaderField:@"Range"];
        
        //创建发送请求
        _dataTask = [self.session dataTaskWithRequest:requestM];
    }
    return _dataTask;
}

#pragma mark - 下载控制
- (IBAction)startBtnClick:(id)sender {
    //开始下载
    [self.dataTask resume];
}

- (IBAction)suspendBtnClick:(id)sender {
    //暂停下载
    [self.dataTask suspend];
}

- (IBAction)resumeBtnClick:(id)sender {
    //恢复下载
    [self.dataTask resume];
}

- (IBAction)cancelBtnClick:(id)sender {
    //取消下载
    [self.dataTask cancel];
    //设置取消之后还可以恢复
    self.dataTask = nil;
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    //接收到响应的时候，告诉系统如何处理服务器返回的数据
    completionHandler(NSURLSessionResponseAllow);
    
    //获取请求的数据大小 != 文件的总大小
    //文件的总大小 = 已经下载的数据大小 + 剩余部分的数据大小（本次请求的大小）
    self.totalLength = response.expectedContentLength + self.curLength;
    
    //将文件的总大小数据写入到磁盘
    [[[NSString stringWithFormat:@"%zd", self.totalLength] dataUsingEncoding:NSUTF8StringEncoding] writeToFile:totalLengthPath atomically:YES];
    
    //实现：边接收边写入磁盘
    //方式一：文件句柄 NSFileHandle【1】【2】【3】【4】
    //方式二：输出流 NSOutputStream（1）（2）（3）
    
    //    //在第一次接收到响应的时候创建一个空的文件
    //    if (self.curLength == 0) {
    //        //【1】在沙盒中创建一个空的文件
    //        [[NSFileManager defaultManager] createFileAtPath:downloadPath contents:nil attributes:nil];
    //    }
    //    //【2】创建一个文件句柄指针指向该文件，默认指向文件的开头
    //    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:downloadPath];
    //    //设置文件句柄指针指向文件末尾
    //    [self.fileHandle seekToEndOfFile];
    
    //（1）创建输出流，并打开
    self.outStream = [[NSOutputStream alloc] initToFileAtPath:downloadPath append:YES];
    [self.outStream open];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    //    //【3】使用文件句柄指针来写数据（边写边移动）
    //    [self.fileHandle writeData:data];
    
    //（2）使用输出流写数据
    [self.outStream write:data.bytes maxLength:data.length];
    
    //计算已经下载的文件数据大小
    self.curLength += data.length;
    
    //计算文件的下载进度
    NSLog(@"%f", 1.0 * self.curLength / self.totalLength);
    self.downProgress.progress = 1.0 * self.curLength / self.totalLength;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    //    //【4】关闭文件句柄
    //    [self.fileHandle closeFile];
    
    //（3）关闭输出流
    [self.outStream close];
    
    NSLog(@"%@", downloadPath);
}

@end
