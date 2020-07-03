//
//  UITextField+PSInputLimit.m
//  PSInputLimitDemo
//
//  Created by 冯广勇 on 2017/9/1.
//  Copyright © 2017年 Passing. All rights reserved.
//

#import "UITextField+PSInputLimit.h"
#import <objc/runtime.h>

@implementation UITextField (PSInputLimit)

NSString *ps_oldStr;

/** 初始化 */
- (void)ps_setupLimit {
    // 默认值
    if (!objc_getAssociatedObject(self, &limitDigitKey)) {
        self.ps_limitDigit = 9;
    }
    if (!objc_getAssociatedObject(self, &ps_integerPrimacyZeroKey)) {
        self.ps_integerPrimacyZero = NO;
    }
    if (!objc_getAssociatedObject(self, &limitPointKey)) {
        self.ps_limitPoint = 2;
    }

    self.inputDelegate = (id)self;

    // 设置输入监听
    [self addTarget:self action:@selector(ps_textDidChange:) forControlEvents:UIControlEventEditingChanged];

    // 设置键盘样式
    switch (self.ps_limitType) {
        case PSInputLimitTypeNone:
        case PSInputLimitTypeEmail:
        case PSInputLimitTypeChinese:
            self.keyboardType = UIKeyboardTypeDefault;
            break;

        case PSInputLimitTypeFloat:
            self.keyboardType = UIKeyboardTypeDecimalPad;
            break;

        case PSInputLimitTypeInteger:
        case PSInputLimitTypePhone:
            self.keyboardType = UIKeyboardTypeNumberPad;
            break;

        default:
            self.keyboardType = UIKeyboardTypeDefault;
            break;
    }
}

- (void)ps_textDidChange:(UITextField *)tf {
    //    UITextPosition *position = [self positionFromPosition:[self markedTextRange].start offset:0];
    if (self.markedTextRange)
        return; // 输入汉字时, 高亮的拼音不算作字符

    if (tf.text.length < ps_oldStr.length) { // 删除时
        ps_oldStr = tf.text;
        return;
    }

    if ([self validateText:tf.text]) {
        ps_oldStr = tf.text;
    } else {
        tf.text = ps_oldStr;
        if (self.ps_tipTextForLimitType) {
            [self alertViewmessager:self.ps_tipTextForLimitType() ?: @"输入格式错误或超出限制长度"];
        } else {
            [self alertViewmessager:@"输入格式错误或超出限制长度"];
        }
    }
}

- (BOOL)validateText:(NSString *)text {
    NSString *number = @"";

    switch (self.ps_limitType) {
        case PSInputLimitTypeNone:
            return text.length <= self.ps_limitDigit;
            break;

        case PSInputLimitTypeFloat:
            if (self.ps_positive) { //正数
                //兼容实时输入的情况
                if (text.length == 1) { //单个字符的时候判断-或者单个数组
                    number = @"^(\\d{0,1})?$";
                } else { //二个以上以后
                    number = [NSString stringWithFormat:@"^([1-9][\\d]{0,%ld}|0)(\\.[\\d]{0,%ld})?$", (long)(self.ps_limitDigit - 1), (long)self.ps_limitPoint];
                }
            } else { //负数
                //兼容实时输入的情况
                if (text.length == 1) { //单个字符的时候判断-或者单个数组
                    number = @"^-?(\\d{0,1})?$";
                } else { //二个以上以后
                    number = [NSString stringWithFormat:@"^-?([1-9][\\d]{0,%ld}|0)(\\.[\\d]{0,%ld})?$", (long)(self.ps_limitDigit - 1), (long)self.ps_limitPoint];
                }
            }
            break;

        case PSInputLimitTypeInteger:
            if (self.ps_positive) {
                //兼容实时输入的情况
                if (text.length == 1) { //单个字符的时候判断-或者单个数组
                    number = @"^(\\d{0,1})?$";
                } else { //二个以上以后
                    if (self.ps_integerPrimacyZero) {
                        number = [NSString stringWithFormat:@"^\\d{0,%ld}$", (long)self.ps_limitDigit + 1];
                    } else {
                        number = [NSString stringWithFormat:@"^([1-9]\\d{0,%ld}|0)$", (long)self.ps_limitDigit - 1];
                    }
                }
            } else {
                //兼容实时输入的情况
                if (text.length == 1) { //单个字符的时候判断-或者单个数组
                    number = @"^-?(\\d{0,1})?$";
                } else { //二个以上以后
                    if (self.ps_integerPrimacyZero) {
                        number = [NSString stringWithFormat:@"^-?\\d{0,%ld}$", (long)self.ps_limitDigit + 1];
                    } else {
                        number = [NSString stringWithFormat:@"^-?([1-9]\\d{0,%ld}|0)$", (long)self.ps_limitDigit - 1];
                    }
                }
            }
            break;

        case PSInputLimitTypePhone:
            number = @"^\\d{0,11}$";
            break;

        case PSInputLimitTypeEmail:
            number = @"";
            break;

        case PSInputLimitTypeChinese:

            if (text.length > self.ps_limitDigit) {
                ps_oldStr = [self.text substringToIndex:self.ps_limitDigit];

                if (self.ps_didTriggerLimitationBlock) {
                    self.ps_didTriggerLimitationBlock();
                }
                return NO;
            }

            break;
        case PSInputLimitTypeMoney:
            if ([text isEqualToString:@"."]) { // 首位输入小数点
                self.text = @"0.";
                return YES;
            }
            // 首位是0时, 输入非小数点数字
            if (text.length == 2 && [text hasPrefix:@"0"]) {
                NSArray *textArr = [self getSubString:text];
                if (![textArr[1] isEqualToString:@"."]) {
                    self.text = textArr[1];
                    text = textArr[1];
                }
            }
            if (self.ps_positive) {
                //限制不能输入00这种,只兼容正常输入，如果不支持-.
                if (text.length == 1) { //单个字符的时候判断-或者单个数组
                    number = @"^(\\d{0,1})?$";
                } else {
                    number = [NSString stringWithFormat:@"([1-9]\\d{0,%ld}|0)(\\.\\d{0,%ld})?$", (long)(self.ps_limitDigit - 1), (long)self.ps_limitPoint];
                }
            } else {
                //限制不能输入00这种,只兼容正常输入，如果不支持-.
                if (text.length == 1) { //单个字符的时候判断-或者单个数组
                    number = @"^-?(\\d{0,1})?$";
                } else {
                    number = [NSString stringWithFormat:@"^-?([1-9]\\d{0,%ld}|0)(\\.\\d{0,%ld})?$", (long)(self.ps_limitDigit - 1), (long)self.ps_limitPoint];
                }
            }
            break;
        default:
            break;
    }

    if (self.ps_limitType != PSInputLimitTypeChinese &&
        self.ps_limitType != PSInputLimitTypeEmail) {
        if ([self IsChinese:text]) {
            [self alertViewmessager:@"请检查输入内容,只能输入数字."];
            return NO;
        }
    }

    if (number.length) {
        NSPredicate *numberPre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", number];
        return [numberPre evaluateWithObject:text];
    }
    return YES;
}

- (void)alertViewmessager:(NSString *)messager {
    //可以使用项目hub修改提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:messager preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self becomeFirstResponder];
    }];
    [alert addAction:cancelAction];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

//监听UITextFieldTextDidChangeNotification 状态
//- (void)textFieldDidChange:(NSNotification *)note{
//    UITextField *textField = note.object;
//    int bytes = [self stringConvertToInt:textField.text];
//    if (bytes > self.ps_limitDigit)
//    {
//        //获取高亮部分
//        UITextPosition *position = [textField positionFromPosition:[textField markedTextRange].start offset:0];
//        if (!position)
//        {
//            textField.text = [textField.text substringToIndex:self.ps_limitDigit];
//            if (self.ps_didTriggerLimitationBlock) {
//                self.ps_didTriggerLimitationBlock();
//            }
//        }
//    }
//}

//得到字节数函数
//-  (int)stringConvertToInt:(NSString*)strtemp
//{
//    int strlength = 0;
//    char* p = (char*)[strtemp cStringUsingEncoding:NSUnicodeStringEncoding];
//    for (int i=0 ; i<[strtemp lengthOfBytesUsingEncoding:NSUnicodeStringEncoding] ;i++)
//    {
//        if (*p) {
//            p++;
//            strlength++;
//        }
//        else {
//            p++;
//        }
//    }
//    return (strlength+1)/2;
//}

//检测当前输入的字符串是否是中文
- (BOOL)IsChinese:(NSString *)str {
    for (int i = 0; i < [str length]; i++) {
        int a = [str characterAtIndex:i];
        if (a > 0x4e00 && a < 0x9fff) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (self.ps_openMenu) {
        if ([UIMenuController sharedMenuController]) {
            [UIMenuController sharedMenuController].menuVisible = NO;
        }
        return NO;
    }

    return [super canPerformAction:action withSender:sender];
}

- (NSArray *)getSubString:(NSString *)str {

    NSMutableArray *textArray = [NSMutableArray array];
    for (NSInteger i = 0; i < str.length; i++) {
        NSRange range = NSMakeRange(i, 1);
        NSString *subStr = [str substringWithRange:range];
        [textArray addObject:subStr];
    }
    return textArray;
}

//-(void)dealloc
//{
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self];
//}

#pragma mark - SET & GET
static const char limitTypeKey = '\0';
static const char limitPointKey = '\0';
static const char limitDigitKey = '\0';
static const char tipTextForLimitTypeKey = '\0';
static const char ps_integerPrimacyZeroKey = '\0';
static const char ps_openMenuKey = '\0';
static const char ps_didTriggerLimitationBlockKey = '\0';
static const char ps_positiveKey = '\0';

- (void)setPs_positive:(BOOL)ps_positive {
    objc_setAssociatedObject(self, &ps_positiveKey, @(ps_positive), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)ps_positive {
    return [objc_getAssociatedObject(self, &ps_positiveKey) boolValue];
}

- (PSInputLimitType)ps_limitType {
    return [objc_getAssociatedObject(self, &limitTypeKey) integerValue];
}
- (void)setPs_limitType:(PSInputLimitType)ps_limitType {
    objc_setAssociatedObject(self, &limitTypeKey, @(ps_limitType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self ps_setupLimit];
}

- (void)setPs_limitPoint:(NSInteger)ps_limitPoint {
    return objc_setAssociatedObject(self, &limitPointKey, @(ps_limitPoint), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSInteger)ps_limitPoint {
    return [objc_getAssociatedObject(self, &limitPointKey) integerValue];
}

- (NSInteger)ps_limitDigit {
    return [objc_getAssociatedObject(self, &limitDigitKey) integerValue];
}
- (void)setPs_limitDigit:(NSInteger)ps_limitDigit {
    if (!objc_getAssociatedObject(self, &limitTypeKey)) {
        self.ps_limitType = 0;
    }
    objc_setAssociatedObject(self, &limitDigitKey, @(ps_limitDigit), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString * (^)(void))ps_tipTextForLimitType {
    return objc_getAssociatedObject(self, &tipTextForLimitTypeKey);
}
- (void)setPs_tipTextForLimitType:(NSString * (^)(void))tipTextForLimitType {
    objc_setAssociatedObject(self, &tipTextForLimitTypeKey, tipTextForLimitType, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)ps_integerPrimacyZero {
    return [objc_getAssociatedObject(self, &ps_integerPrimacyZeroKey) boolValue];
}
- (void)setPs_integerPrimacyZero:(BOOL)ps_integerPrimacyZero {
    objc_setAssociatedObject(self, &ps_integerPrimacyZeroKey, @(ps_integerPrimacyZero), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)ps_openMenu {
    return [objc_getAssociatedObject(self, &ps_openMenuKey) boolValue];
}
- (void)setPs_openMenu:(BOOL)ps_openMenu {
    objc_setAssociatedObject(self, &ps_openMenuKey, @(ps_openMenu), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(void))ps_didTriggerLimitationBlock {
    return objc_getAssociatedObject(self, &ps_didTriggerLimitationBlockKey);
}
- (void)setPs_didTriggerLimitationBlock:(void (^)(void))ps_didTriggerLimitationBlock {
    objc_setAssociatedObject(self, &ps_didTriggerLimitationBlockKey, ps_didTriggerLimitationBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 链式
#define weak_Self __weak typeof(self) weakSelf = self
#define strong_Self __strong typeof((weakSelf)) strongSelf = (weakSelf)

/**
 限制输入的字符个数, 默认9个
 */
- (UITextField * (^)(NSInteger))lt_limitLength {
    return ^id(NSInteger ps_limitDigit) {
        self.ps_limitDigit = ps_limitDigit;
        return self;
    };
}
/**
 限制小数点后几位, 默认2位
 */
- (UITextField * (^)(NSInteger))lt_limitPoint {
    return ^id(NSInteger ps_limitPoint) {
        self.ps_limitPoint = ps_limitPoint;
        return self;
    };
}
/** 首位是否可以为 0 (整型时), 默认NO */
- (UITextField * (^)(BOOL))lt_integerPrimacyZero {
    return ^id(BOOL ps_integerPrimacyZero) {
        self.ps_integerPrimacyZero = ps_integerPrimacyZero;
        return self;
    };
}
/** 首位是否可以为正数(数字类型时), 默认NO */
- (UITextField * (^)(BOOL))lt_positive {
    return ^id(BOOL ps_positive) {
        self.ps_positive = ps_positive;
        return self;
    };
}
/**
 是否可以粘贴复制, 默认NO
 */
- (UITextField * (^)(BOOL))lt_openMenu {
    return ^id(BOOL ps_openMenu) {
        self.ps_openMenu = ps_openMenu;
        return self;
    };
}

/** 触发限制操作时的提示信息 */
- (UITextField * (^)(NSString*))lt_showErrText {
    return ^id(NSString * tip) {
        if (tip.length) {
            self.ps_tipTextForLimitType = ^NSString *{
                return tip;
            };
        }
        return self;
    };
}
/** 触发限制操作时的提示信息 */
- (UITextField * (^)(void(^ps_didTriggerLimitationBlock)(void)))lt_didTriggerLimitationBlock {
    return ^id(void(^ps_didTriggerLimitationBlock)(void)) {
        self.ps_didTriggerLimitationBlock = ps_didTriggerLimitationBlock;
        return self;
    };
}

//设置类型
- (UITextField * (^)(PSInputLimitType))lt_startLimitWithType {
    return ^id(PSInputLimitType ty) {
        self.ps_limitType = ty;
        return self;
    };
}

@end
