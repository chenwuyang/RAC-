RAC 常用方法
1.代替代理 场景（A->B B向A传值）
B.h
@property (nonatomic,strong)RACSubject *subject;
B.m
- (RACSubject *)subject
{
    if (!_subject) {
        _subject = [[RACSubject alloc] init];
    }
    return _subject;
}

{
	[self.subject sendNext:@"向A传值"];
}

A.m
{
	B *vc = [[B alloc] init];
	[vc.subject subscribeNext:^(id  _Nullable x) {
		NSLog(@"替代代理点击了RACController中的按钮");
	}];
	[self presentViewController:vc animated:YES completion:nil];
}

2.监听UITextFiled字符变化
UItextFiled *tf = [[UItextFiled alloc] init];

[[tf rac_textSignal] subscribeNext:^(NSString * _Nullable x) {
        NSLog(@"监听textfiled输入字符的变化");
}];

3.按钮点击事件
UIButton *button = [[UIButton alloc]init];
[[button rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(__kindof UIControl * _Nullable x) {
        NSLog(@"按钮的点击");
}];

4.代替通知
[[[NSNotificationCenter defaultCenter] rac_addObserverForName:UIKeyboardDidShowNotification object:nil] subscribeNext:^(NSNotification * _Nullable x) {
        NSLog(@"替代通知");
}];

5.替代KVO监听属性变化（只能得到变化后的值，无法得到变化前的值）
[RACObserve(self.view, backgroundColor) subscribeNext:^(id  _Nullable x) {
        NSLog(@"替代KVO监听属性的变化");
}];

6.遍历
NSArray *array = @[@"2813",@"2231",@"9999"];
[array.rac_sequence.signal subscribeNext:^(id  _Nullable x) {
        NSLog(@"%@",x);
}];

7.[combineLatest]把多个信号聚合成需要的信号（把输入框输入值的信号聚合成按钮是否能点击的信号，多个输入框都有值时按钮才能点击）
{
	RACSignal *combinSignal = [RACSignal combineLatest:@[self.firstTF.rac_textSignal, self.secondTF.rac_textSignal] reduce:^id(NSString *account, NSString *pwd){
        //block: 只要源信号发送内容，就会调用，组合成一个新值。
        return @(account.length && pwd.length);
    }];
    RAC(self.loginButton, enabled) = combinSignal;
}

8.[zipWith]把两个信号压缩成一个信号，只有当两个信号同时发出信号内容时，就把两个信号合并成一个圆组，才会触发压缩流的next事件
- (void)zipWith
{
    RACSubject *signalA = [RACSubject subject];
    RACSubject *signalB = [RACSubject subject];
    //元组内元素的顺序跟压缩的顺序有关@[signalA,signalB]---先是A后是B
    RACSignal *zipSignal = [RACSignal zip:@[signalA,signalB]];
    [zipSignal subscribeNext:^(id x) {
        NSLog(@"%@", x); //所有的值都被包装成了元组
    }];
    [signalA sendNext:@1];
    [signalB sendNext:@2];
    [signalA sendNext:@3];
    [signalA sendNext:@4];
    [signalB sendNext:@5];
}
控制台输出：
2019-12-28 14:14:03.981411+0800 Test[1119:251645] <RACTwoTuple: 0x17001d790> (
    1,
    2
)
2019-12-28 14:14:03.981950+0800 Test[1119:251645] <RACTwoTuple: 0x17001d7a0> (
    3,
    5
)

9.[merge]多个信号合成一个新信号，任何一个子信号改变都会，都会调用新信号值
- (void)merge
{
    RACSubject *signalA = [RACSubject subject];
    RACSubject *signalB = [RACSubject subject];
    RACSubject *signalC = [RACSubject subject];
    //组合信号
    RACSignal *mergeSignal = [RACSignal merge:@[signalA,signalB,signalC]];
    // 订阅信号
    [mergeSignal subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
    // 发送信号---交换位置则数据结果顺序也会交换
    [signalA sendNext:@"A"];
    [signalB sendNext:@"B"];
    [signalC sendNext:@"C"];
}
控制台输入：
2019-12-28 14:12:32.831771+0800 Test[1117:251238] A
2019-12-28 14:12:32.832083+0800 Test[1117:251238] B
2019-12-28 14:12:32.832185+0800 Test[1117:251238] C

10.[then]A,B两个信号A发送完毕忽略A信号，只接收B的数据
- (void)then
{
    RACSignal *signalA = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"A"];
        //关闭当前信号A否则B信号就无法触发
        [subscriber sendCompleted];
        return nil;
    }];

    RACSignal *signalB = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"B"];
        [subscriber sendCompleted];
        return nil;
    }];
    //A发送完毕 忽略前面A这个信号  只接收B的数据（A发送完毕 B在回来）
    RACSignal *thenSignal = [signalA then:^RACSignal *{
        // 返回的信号就是要组合的信号
        return signalB;
    }];

    // 订阅信号
    [thenSignal subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
}
控制台输出：
2019-12-28 14:57:21.053351+0800 Test[1171:261670] B

11.[concat]A,B两个信号，先执行A信号，再执行B信号
- (void)concat
{
    RACSignal *signalA = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"A"];
        [subscriber sendCompleted];
        return nil;
    }];
    RACSignal *signalsB = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"B"];
        [subscriber sendCompleted];
        return nil;
    }];
    // 创建组合信号
    RACSignal *concatSignal = [signalA concat:signalsB];
    // 订阅组合信号
    [concatSignal subscribeNext:^(id x) {
        NSLog(@"%@",x);
    }];
}
控制台输出：
2019-12-28 15:08:53.894278+0800 Test[1174:263300] A
2019-12-28 15:08:53.894516+0800 Test[1174:263300] B

12.处理界面有多次请求时，需要都获取到数据时，才能展示界面
{
	RACSignal *requestHot = [RACSignal createSignal:^RACDisposable *(id subscriber) {
		NSLog(@“请求最热商品”);
		[subscriber sendNext:@“获取最热商品”];
		[subscriber sendCompleted];
		return nil;
	}];
	RACSignal *requestNew = [RACSignal createSignal:^RACDisposable *(id subscriber) {
		NSLog(@“请求最新商品”);
		//下面这一语句一定要有
		[subscriber sendNext:@“获取最新商品”];
		[subscriber sendCompleted];
		return nil;
	}];
	[self rac_liftSelector:@selector(updateUIWithData1:data2:) withSignalsFromArray:@[requestHot,requestNew]];
}

13.MVVM网络请求
ViewModel.h
//command处理实际事务  网络请求
@property (nonatomic,strong)RACCommand *command;

ViewModel.m
- (void)initViewModel
{
    self.command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
            [self getDoubanList:^(NSArray<MovieModel *> *array) {
                [subscriber sendNext:array];
                [subscriber sendCompleted];
            }];
            return [RACDisposable disposableWithBlock:^{
                NSLog(@"销毁了---");
            }];
        }];
    }];
}


Controller.m
- (void)bindViewModel {
    @weakify(self);
    //将命令执行后的数据交给controller
    RACSignal *signal = [self.viewModel.command execute:nil];
    [signal subscribeNext:^(id x) {
        @strongify(self);
        [SVProgressHUD showSuccessWithStatus:@"加载成功"];
    }];
    [SVProgressHUD showWithStatus:@"加载中..."];
}