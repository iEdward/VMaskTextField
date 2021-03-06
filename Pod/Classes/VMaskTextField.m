#import "VMaskTextField.h"

NSString * kVMaskTextFieldDefaultChar = @"#";

@interface VMaskTextField()

@property (strong, nonatomic) UIColor *defaultTextColor;

@end

@implementation VMaskTextField

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.defaultCharMask = kVMaskTextFieldDefaultChar;
        self.defaultTextColor = self.textColor;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.defaultCharMask = kVMaskTextFieldDefaultChar;
        self.defaultTextColor = self.textColor;
    }
    return self;
}

-(void) setTextWithMask:(NSString *) text{
    NSAssert(_mask!=nil, @"Mask is nil.");
    for (int i = 0; i < text.length; i++) {
        if (self.text.length == _mask.length) {
            break;
        }
        [self shouldChangeCharactersInRange:NSMakeRange(i, 0) replacementString:[NSString stringWithFormat:@"%c",[text characterAtIndex:i]]];
    }
}

- (void)setText:(NSString *)text {
    if (self.placeholderMask) {
        NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:[text copy]];
        [attrText addAttribute:NSForegroundColorAttributeName value:self.defaultTextColor range:NSMakeRange(0, self.lastMaskLocation)];
        [attrText addAttribute:NSForegroundColorAttributeName value:(self.placeholderColor ?: self.defaultTextColor) range:NSMakeRange(self.lastMaskLocation, self.placeholderMask.length - self.lastMaskLocation)];
        [self setAttributedText:attrText];
    } else {
        [super setText:text];
    }
}

- (void)setPlaceholderMask:(NSString *)placeholderMask {
    if (placeholderMask.length == _mask.length) {
        _placeholderMask = placeholderMask;
        self.attributedText = [[NSAttributedString alloc] initWithString:placeholderMask attributes:@{NSForegroundColorAttributeName: self.placeholderColor ?: self.defaultTextColor}];
    }
}

- (void)setTextColor:(UIColor *)textColor {
    [super setTextColor:textColor];
    self.defaultTextColor = textColor;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    self.defaultTextColor = self.textColor;
    _placeholderColor = placeholderColor;
}

- (BOOL)shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString * currentTextDigited = [self.text stringByReplacingCharactersInRange:range withString:string];

    if (self.placeholderMask.length) {
        currentTextDigited = [currentTextDigited stringByReplacingCharactersInRange:NSMakeRange(currentTextDigited.length - self.placeholderMask.length + self.lastMaskLocation, self.placeholderMask.length - self.lastMaskLocation) withString:@""];
    }

    // User deleted something
    if (string.length == 0) {
        while (currentTextDigited.length > 0 && !isnumber([currentTextDigited characterAtIndex:currentTextDigited.length-1])) {
            currentTextDigited = [currentTextDigited substringToIndex:[currentTextDigited length] - 1];
        }

        // Save the place we stopped so we can cut it off when we come back here
        self.lastMaskLocation = currentTextDigited.length;

        if (self.placeholderMask.length) {
            // Tack the rest of the mask on the end
            self.text = [currentTextDigited stringByAppendingString:[self.placeholderMask substringWithRange:NSMakeRange(self.lastMaskLocation, self.placeholderMask.length - self.lastMaskLocation)]];

            [self setSelectedRange:NSMakeRange(self.lastMaskLocation, 0)];
        } else {
            self.text = currentTextDigited;
        }

        return NO;
    }

    // User is trying to type more characters than the mask allows
    NSMutableString * returnText = [[NSMutableString alloc] init];
    if (currentTextDigited.length > _mask.length) {
        return NO;
    }

    // Build the return string using the mask
    int loc = 0;
    BOOL needAppend = NO;
    for (; loc < currentTextDigited.length; loc++) {
        unichar  currentCharMask = [_mask characterAtIndex:loc];
        unichar  currentChar = [currentTextDigited characterAtIndex:loc];

        if (isnumber(currentChar) && currentCharMask == '#') {
            [returnText appendString:[NSString stringWithFormat:@"%c",currentChar]];
        } else {
            if (currentCharMask == '#') {
                break;
            }
            if (isnumber(currentChar) && currentCharMask!= currentChar) {
                needAppend = YES;
            }
            [returnText appendString:[NSString stringWithFormat:@"%c",currentCharMask]];
        }
    }

    // Add any characters we need at the end (things that aren't a number)
    for (; loc < _mask.length; loc++) {
        unichar currentCharMask = [_mask characterAtIndex:loc];

        if (currentCharMask != '#') {
            [returnText appendString:[NSString stringWithFormat:@"%c",currentCharMask]];
        } else {
            break;
        }
    }

    // ???
    if (needAppend) {
        [returnText appendString:string];
    }

    // Save the place we stopped so we can cut it off when we come back here
    self.lastMaskLocation = loc;

    if (self.placeholderMask.length) {
        // Tack the rest of the mask on the end
        [returnText appendString:[self.placeholderMask substringWithRange:NSMakeRange(loc, self.placeholderMask.length - loc)]];

        self.text = returnText;
        [self setSelectedRange:NSMakeRange(loc, 0)];
    } else {
        self.text = returnText;
    }

    return NO;
}

-(double) rawToDouble{
    return [_raw doubleValue];
}

-(float) rawToFloat{
    return [_raw floatValue];
}

-(NSInteger) rawToInteger{
    return [_raw intValue];
}

-(NSDate *)rawToDate:(NSDateFormatter *)formatter{
    NSDate *date = [formatter dateFromString:_raw];
    return date;
}

- (BOOL)selectedRangeAcceptable:(UITextRange *)range {
    NSInteger pos = [self offsetFromPosition:[self beginningOfDocument] toPosition:range.start];
    return pos <= self.lastMaskLocation;
}

- (NSRange)endOfEnteredText {
    return NSMakeRange(self.lastMaskLocation, 0);
}

- (void)setSelectedRange:(NSRange)range {
    [self setSelectedTextRange:[self textRangeFromNSRange:range]];
}

- (UITextRange *)textRangeFromNSRange:(NSRange)range {
    UITextPosition *start = [self positionFromPosition:[self beginningOfDocument] offset:range.location];
    return [self textRangeFromPosition:start toPosition:[self positionFromPosition:start offset:range.length]];
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange {
    if (![self selectedRangeAcceptable:selectedTextRange]) {
        [super setSelectedTextRange:[self textRangeFromNSRange:[self endOfEnteredText]]];
    } else {
        [super setSelectedTextRange:selectedTextRange];
    }
}

@end
