//
//  do_VideoRecord_View.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "do_VideoRecord_IView.h"
#import "do_VideoRecord_UIModel.h"
#import "doIUIModuleView.h"

@interface do_VideoRecord_UIView : UIView<do_VideoRecord_IView, doIUIModuleView>
//可根据具体实现替换UIView
{
	@private
		__weak do_VideoRecord_UIModel *_model;
}

@end
