//
//  do_VideoRecord_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_VideoRecord_UIView.h"

#import "doInvokeResult.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doJsonHelper.h"
#import "doISourceFS.h"
#import "doIDataFS.h"
#import "doILogEngine.h"
#import "doIApp.h"
#import "doServiceContainer.h"
#import <AVFoundation/AVFoundation.h>

#define PFS 30

@interface do_VideoRecord_UIView()<AVCaptureFileOutputRecordingDelegate>
@property (strong,nonatomic) AVCaptureSession *captureSession;
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign,nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

@end

@implementation do_VideoRecord_UIView
{
    NSString *_outputFielPath;
    NSString *_quality;
    NSInteger _limit;
}
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    
    
    [self initialization];
}
//销毁所有的全局对象
- (void) OnDispose
{
    //自定义的全局属性,view-model(UIModel)类销毁时会递归调用<子view-model(UIModel)>的该方法，将上层的引用切断。所以如果self类有非原生扩展，需主动调用view-model(UIModel)的该方法。(App || Page)-->强引用-->view-model(UIModel)-->强引用-->view
    [self.captureMovieFileOutput stopRecording];//停止录制
    [self.captureSession stopRunning];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_captureVideoPreviewLayer removeFromSuperlayer];
    });
}
//实现布局
- (void) OnRedraw
{
    //实现布局相关的修改,如果添加了非原生的view需要主动调用该view的OnRedraw，递归完成布局。view(OnRedraw)<显示布局>-->调用-->view-model(UIModel)<OnRedraw>
    
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
    
    _captureVideoPreviewLayer.frame=self.layer.bounds;

}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */

#pragma mark -
#pragma mark - 同步异步方法的实现
//同步
- (void)start:(NSArray *)parms
{
    [self stopRecord];
    
    [self play:parms];
    
}
- (void)initialization
{
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];

    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    NSArray *presents = @[AVCaptureSessionPreset640x480,AVCaptureSessionPreset1280x720,AVCaptureSessionPreset1920x1080];
    NSString *resolution = AVCaptureSessionPreset640x480;
    for (NSString *present in presents) {
        if ([captureDevice supportsAVCaptureSessionPreset:present]) {
            resolution = present;
            break;
        }
    }
    if ([_captureSession canSetSessionPreset:resolution]) {//设置分辨率
        _captureSession.sessionPreset=resolution;
    }
    if (!captureDevice) {
        NSLog(@"取得后置摄像头时出现问题.");
        [self fireEvent:@"error" :@{@"error":@"取得后置摄像头时出现问题"}];
        return;
    }
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        [self fireEvent:@"error" :@{@"error":error.localizedDescription}];
        return;
    }
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        [self fireEvent:@"error" :@{@"error":error.localizedDescription}];
        return;
    }
    //初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported ]) {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer=self.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=layer.bounds;
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    //填充模式
    //将视频预览层添加到界面中
    dispatch_async(dispatch_get_main_queue(), ^{
        [layer addSublayer:_captureVideoPreviewLayer];
    });
    
    
    [self.captureSession startRunning];
}

- (void)play:(NSArray *)parms
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //参数字典_dictParas
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    //自己的代码实现
    
//    doInvokeResult *_invokeResult = [parms objectAtIndex:2];
    //_invokeResult设置返回值
    _quality = [doJsonHelper GetOneText:_dictParas :@"quality" :@"low"];
    
    if ([_quality isEqualToString:@"low"]) {
        _quality = AVAssetExportPreset640x480;
    }else if([_quality isEqualToString:@"normal"]){
        _quality = AVAssetExportPreset1280x720;
    }else if([_quality isEqualToString:@"high"]){
        _quality = AVAssetExportPreset1920x1080;
    }
    
    _limit = [doJsonHelper GetOneInteger:_dictParas :@"limit" :-1]/1000*PFS;
    if (_limit < 0) {
        _limit = MAXFLOAT;
    }

    AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    CMTime maxDuration = CMTimeMake(_limit, PFS);
    _captureMovieFileOutput.maxRecordedDuration = maxDuration;

    captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
    
    NSString * dataFSRootPath = _scritEngine.CurrentApp.DataFS.RootPath;
    NSString *timeStamp = [@((long long)([[NSDate date] timeIntervalSince1970]*1000)) stringValue];
    NSString *fileName = [NSString stringWithFormat:@"%@.mov",timeStamp];
    NSString *filePath = [NSString stringWithFormat:@"%@/temp/do_VideoRecord",dataFSRootPath];
    NSFileManager *manage = [NSFileManager defaultManager];
    if (![manage fileExistsAtPath:filePath]) {
        BOOL isCreate = [manage createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
        if (!isCreate) {
            [self fireEvent:@"error" :@{@"error":@"无法建立文件，可能是空间已满，请重试"}];
            [self stopRecord];
            return;
        }
    }
    NSString * fileFullName = [NSString stringWithFormat:@"%@/%@",filePath,fileName];

    _outputFielPath=fileFullName;
    NSURL *fileUrl=[NSURL fileURLWithPath:_outputFielPath];
    NSLog(@"fileUrl:%@",fileUrl);
    [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
}

- (void)convertToMP4
{
    NSURL *url = [NSURL fileURLWithPath:_outputFielPath];
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    NSArray *exports = @[AVAssetExportPreset640x480,AVAssetExportPreset1280x720,AVAssetExportPreset1920x1080];
    NSString *supportResolution = AVAssetExportPreset640x480;
    if (![compatiblePresets containsObject:_quality]) {
        for (NSString *export in exports) {
            if (supportResolution == export) {
                [[doServiceContainer Instance].LogEngine WriteError:nil :@"该设备不支持设置的分辨率，将自动按照该设备支持的最佳分辨率录制"];
                break;
            }
        }
    }
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]initWithAsset:avAsset presetName:supportResolution];
    NSString *mp4Path = [_outputFielPath stringByReplacingOccurrencesOfString:@".mov" withString:@".mp4"];
    
    exportSession.outputURL = [NSURL fileURLWithPath:mp4Path];
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.outputFileType = AVFileTypeMPEG4;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        switch ([exportSession status]) {
            case AVAssetExportSessionStatusFailed:
                [self fireEvent:@"error" :@{@"error":exportSession.error.localizedDescription}];
                break;
            case AVAssetExportSessionStatusCancelled:
                [self fireEvent:@"error" :@{@"error":exportSession.error.localizedDescription}];
                break;
            case AVAssetExportSessionStatusCompleted:
            {
                NSString *path = [NSString stringWithFormat:@"data://temp/do_VideoRecord/%@",[mp4Path lastPathComponent]];
                long long size = [[[NSFileManager defaultManager] attributesOfItemAtPath:mp4Path error:nil] fileSize]/1000;
                ;
                NSDictionary *dic = @{@"path":path,@"size":@(size)};
                [self fireEvent:@"finish" :dic];
            }
                break;
            default:
                break;
        }
    }];
}

- (void)stop:(NSArray *)parms
{
    [self stopRecord];
}

- (void)stopRecord
{
    [self.captureMovieFileOutput stopRecording];//停止录制
}

- (void) fireEvent:(NSString *)event :(NSDictionary *)error
{
    doInvokeResult * _invokeResult = [[doInvokeResult alloc]init:_model.UniqueKey];
    [_invokeResult SetResultNode:error];
    [_model.EventCenter FireEvent:event :_invokeResult];
}

#pragma mark - delegate
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSLog(@"视频录制完成.");
    [self stopRecord];
    [self convertToMP4];
}

#pragma mark - private
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}


#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}

@end
