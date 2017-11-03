//
//  do_VideoRecord_UI.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol do_VideoRecord_IView <NSObject>

@required
//属性方法

//同步或异步方法
- (void)start:(NSArray *)parms;
- (void)stop:(NSArray *)parms;


@end