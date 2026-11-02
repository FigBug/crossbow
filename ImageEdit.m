//
//  ImageEdit.m
//  Crossbow
//

#import "ImageEdit.h"
#import "Preferences.h"
#import <ImageIO/ImageIO.h>

static NSString* const ImageEditErrorDomain = @"com.rabiensoftware.crossbow.ImageEdit";

static NSError* editError(NSString* path, NSString* message)
{
    NSString* desc = [NSString stringWithFormat:@"%@: %@", [path lastPathComponent], message];
    return [NSError errorWithDomain:ImageEditErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: desc}];
}

//==============================================================================
// Orientation maths
//
// Each EXIF orientation is a 2x2 matrix mapping stored pixel coordinates to
// displayed coordinates (y down). Composing the user's operation with the
// file's current orientation gives the new orientation for the lossless path,
// and the same matrix drives the pixel transform for everything else.

typedef struct { int m00, m01, m10, m11; } Mat;

static const Mat kOrientation[9] =
{
    { 1, 0, 0, 1 },     // 0: unused
    { 1, 0, 0, 1 },     // 1: normal
    {-1, 0, 0, 1 },     // 2: mirror horizontal
    {-1, 0, 0,-1 },     // 3: rotate 180
    { 1, 0, 0,-1 },     // 4: mirror vertical
    { 0, 1, 1, 0 },     // 5: transpose
    { 0,-1, 1, 0 },     // 6: rotate 90 CW
    { 0,-1,-1, 0 },     // 7: transverse
    { 0, 1,-1, 0 },     // 8: rotate 90 CCW
};

static Mat matMul(Mat a, Mat b)
{
    Mat r = { a.m00 * b.m00 + a.m01 * b.m10, a.m00 * b.m01 + a.m01 * b.m11,
              a.m10 * b.m00 + a.m11 * b.m10, a.m10 * b.m01 + a.m11 * b.m11 };
    return r;
}

static Mat matForOp(ImageEditOp op)
{
    switch (op)
    {
        case ImageEditRotateRight:    return kOrientation[6];
        case ImageEditRotateLeft:     return kOrientation[8];
        case ImageEditRotate180:      return kOrientation[3];
        case ImageEditFlipHorizontal: return kOrientation[2];
        case ImageEditFlipVertical:   return kOrientation[4];
    }
    return kOrientation[1];
}

static int orientationForMat(Mat m)
{
    for (int i = 1; i <= 8; i++)
        if (memcmp(&kOrientation[i], &m, sizeof (Mat)) == 0)
            return i;
    return 1;
}

// CG transform (y up) that draws a w x h image through matrix m, and the size of the result.
static CGAffineTransform transformForMat(Mat m, CGSize src, CGSize* outSize)
{
    CGFloat w = src.width, h = src.height;
    CGFloat tx = (m.m00 < 0 ? w : 0) + (m.m01 < 0 ? h : 0);
    CGFloat ty = (m.m10 < 0 ? w : 0) + (m.m11 < 0 ? h : 0);
    CGFloat W = abs(m.m00) * w + abs(m.m01) * h;
    CGFloat H = abs(m.m10) * w + abs(m.m11) * h;
    *outSize = CGSizeMake(W, H);

    CGAffineTransform flipSrc = CGAffineTransformMake(1, 0, 0, -1, 0, h);
    CGAffineTransform mat     = CGAffineTransformMake(m.m00, m.m10, m.m01, m.m11, tx, ty);
    CGAffineTransform flipDst = CGAffineTransformMake(1, 0, 0, -1, 0, H);
    return CGAffineTransformConcat(CGAffineTransformConcat(flipSrc, mat), flipDst);
}

//==============================================================================
// Reading

static CGImageSourceRef createSource(NSString* path, NSError** error)
{
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!src || CGImageSourceGetCount(src) == 0)
    {
        if (src) CFRelease(src);
        if (error) *error = editError(path, @"The file could not be read as an image.");
        return NULL;
    }
    return src;
}

static NSDictionary* sourceProperties(CGImageSourceRef src)
{
    return CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(src, 0, NULL));
}

static int sourceOrientation(CGImageSourceRef src)
{
    int o = [[sourceProperties(src) objectForKey:(NSString*)kCGImagePropertyOrientation] intValue];
    return (o >= 1 && o <= 8) ? o : 1;
}

static UTType* sourceType(CGImageSourceRef src)
{
    CFStringRef t = CGImageSourceGetType(src);
    return t ? [UTType typeWithIdentifier:(__bridge NSString*)t] : nil;
}

static BOOL typeHasLosslessOrientation(UTType* type)
{
    return [type conformsToType:UTTypeJPEG] || [type conformsToType:UTTypeHEIC] || [type conformsToType:UTTypeHEIF];
}

static BOOL typeIsWritable(UTType* type)
{
    NSArray* writable = CFBridgingRelease(CGImageDestinationCopyTypeIdentifiers());
    return type && [writable containsObject:[type identifier]];
}

static BOOL typeSupportsAlpha(UTType* type)
{
    return !([type conformsToType:UTTypeJPEG] || [type conformsToType:UTTypeBMP] || [type conformsToType:[UTType typeWithIdentifier:@"public.jpeg-2000"]]);
}

//==============================================================================
// Drawing

static CGImageRef createImageByDrawing(CGImageRef src, CGSize outSize, CGAffineTransform transform, CGRect drawRect, BOOL flatten)
{
    size_t W = (size_t) llround(outSize.width);
    size_t H = (size_t) llround(outSize.height);
    if (W == 0 || H == 0)
        return NULL;

    CGColorSpaceRef cs = CGImageGetColorSpace(src);
    if (cs && CGColorSpaceGetModel(cs) == kCGColorSpaceModelRGB)
        CGColorSpaceRetain(cs);
    else
        cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

    CGBitmapInfo info = flatten ? (CGBitmapInfo) kCGImageAlphaNoneSkipLast : (CGBitmapInfo) kCGImageAlphaPremultipliedLast;
    CGContextRef ctx = CGBitmapContextCreate(NULL, W, H, 8, 0, cs, info);
    CGColorSpaceRelease(cs);
    if (!ctx)
        return NULL;

    if (flatten)
    {
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
        CGContextFillRect(ctx, CGRectMake(0, 0, W, H));
    }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextConcatCTM(ctx, transform);
    CGContextDrawImage(ctx, drawRect, src);

    CGImageRef result = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return result;
}

// The stored image with its EXIF orientation applied.
static CGImageRef createNormalizedImage(CGImageSourceRef src, BOOL flatten)
{
    CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
    if (!img)
        return NULL;

    CGSize size = CGSizeMake(CGImageGetWidth(img), CGImageGetHeight(img));
    CGSize outSize;
    CGAffineTransform t = transformForMat(kOrientation[sourceOrientation(src)], size, &outSize);

    CGImageRef result = createImageByDrawing(img, outSize, t, CGRectMake(0, 0, size.width, size.height), flatten);
    CGImageRelease(img);
    return result;
}

//==============================================================================
// Writing

// Metadata for a re-encoded file: the original's, minus anything describing
// the old pixels or orientation.
static NSDictionary* propertiesForWriting(CGImageSourceRef src, CGImageRef img, UTType* type, double quality)
{
    NSMutableDictionary* props = [sourceProperties(src) mutableCopy];
    [props removeObjectForKey:(NSString*)kCGImagePropertyOrientation];
    [props removeObjectForKey:(NSString*)kCGImagePropertyPixelWidth];
    [props removeObjectForKey:(NSString*)kCGImagePropertyPixelHeight];
    [props removeObjectForKey:(NSString*)kCGImagePropertyDepth];
    [props removeObjectForKey:(NSString*)kCGImagePropertyHasAlpha];
    [props removeObjectForKey:(NSString*)kCGImagePropertyColorModel];

    NSMutableDictionary* tiff = [[props objectForKey:(NSString*)kCGImagePropertyTIFFDictionary] mutableCopy];
    if (tiff)
    {
        [tiff setObject:@1 forKey:(NSString*)kCGImagePropertyTIFFOrientation];
        [props setObject:tiff forKey:(NSString*)kCGImagePropertyTIFFDictionary];
    }
    NSMutableDictionary* exif = [[props objectForKey:(NSString*)kCGImagePropertyExifDictionary] mutableCopy];
    if (exif)
    {
        [exif setObject:@(CGImageGetWidth(img))  forKey:(NSString*)kCGImagePropertyExifPixelXDimension];
        [exif setObject:@(CGImageGetHeight(img)) forKey:(NSString*)kCGImagePropertyExifPixelYDimension];
        [props setObject:exif forKey:(NSString*)kCGImagePropertyExifDictionary];
    }
    if ([ImageEdit typeIsLossy:type])
        [props setObject:@(quality) forKey:(NSString*)kCGImageDestinationLossyCompressionQuality];
    return props;
}

static NSURL* temporaryURLForType(UTType* type)
{
    NSString* name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:[type preferredFilenameExtension] ?: @"img"];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

static BOOL writeImage(CGImageRef img, NSURL* url, UTType* type, NSDictionary* props, NSString* path, NSError** error)
{
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, (__bridge CFStringRef)[type identifier], 1, NULL);
    if (!dest)
    {
        if (error) *error = editError(path, [NSString stringWithFormat:@"Images cannot be written as %@.", [type localizedDescription] ?: [type identifier]]);
        return NO;
    }
    CGImageDestinationAddImage(dest, img, (__bridge CFDictionaryRef)props);
    BOOL ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    if (!ok && error)
        *error = editError(path, @"The image could not be encoded.");
    return ok;
}

// Replaces the original with the newly written temporary file, keeping the
// original's creation date and other file metadata.
static BOOL replaceFile(NSString* path, NSURL* tempURL, NSError** error)
{
    NSFileManager* fm = [NSFileManager defaultManager];
    BOOL ok = [fm replaceItemAtURL:[NSURL fileURLWithPath:path] withItemAtURL:tempURL backupItemName:nil options:0 resultingItemURL:nil error:error];
    [fm removeItemAtURL:tempURL error:nil];
    return ok;
}

// Re-encodes `img` in the file's own format and swaps it into place.
static BOOL rewriteFile(NSString* path, CGImageSourceRef src, CGImageRef img, NSError** error)
{
    UTType* type = sourceType(src);
    if (!typeIsWritable(type))
    {
        if (error) *error = editError(path, @"This format cannot be re-encoded. Convert the image to another format first.");
        return NO;
    }
    NSURL* tmp = temporaryURLForType(type);
    if (!writeImage(img, tmp, type, propertiesForWriting(src, img, type, 0.9), path, error))
        return NO;
    return replaceFile(path, tmp, error);
}

//==============================================================================
@implementation ImageEdit

+ (BOOL)canEditFile:(NSString*)path
{
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!src)
        return NO;
    BOOL ok = CGImageSourceGetCount(src) > 0;
    CFRelease(src);
    return ok;
}

+ (NSSize)pixelSizeOfFile:(NSString*)path
{
    CGImageSourceRef src = createSource(path, NULL);
    if (!src)
        return NSZeroSize;
    NSDictionary* props = sourceProperties(src);
    NSSize size = NSMakeSize([[props objectForKey:(NSString*)kCGImagePropertyPixelWidth] doubleValue],
                             [[props objectForKey:(NSString*)kCGImagePropertyPixelHeight] doubleValue]);
    if (sourceOrientation(src) >= 5)
        size = NSMakeSize(size.height, size.width);
    CFRelease(src);
    return size;
}

+ (BOOL)applyOp:(ImageEditOp)op toFile:(NSString*)path error:(NSError**)error
{
    CGImageSourceRef src = createSource(path, error);
    if (!src)
        return NO;

    BOOL ok = NO;
    UTType* type = sourceType(src);
    Mat combined = matMul(matForOp(op), kOrientation[sourceOrientation(src)]);

    if (typeHasLosslessOrientation(type))
    {
        // Copy the compressed data as is and only rewrite the orientation tag.
        NSURL* tmp = temporaryURLForType(type);
        CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)tmp, (__bridge CFStringRef)[type identifier], 1, NULL);
        if (dest)
        {
            NSDictionary* opts = @{(NSString*)kCGImageDestinationOrientation: @(orientationForMat(combined))};
            CFErrorRef cfErr = NULL;
            ok = CGImageDestinationCopyImageSource(dest, src, (__bridge CFDictionaryRef)opts, &cfErr);
            CFRelease(dest);
            if (ok)
                ok = replaceFile(path, tmp, error);
            else if (error)
                *error = cfErr ? CFBridgingRelease(cfErr) : editError(path, @"The orientation could not be updated.");
            if (!ok)
                [[NSFileManager defaultManager] removeItemAtURL:tmp error:nil];
        }
        else if (error)
            *error = editError(path, @"The file could not be written.");
    }
    else
    {
        CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
        if (img)
        {
            CGSize size = CGSizeMake(CGImageGetWidth(img), CGImageGetHeight(img));
            CGSize outSize;
            CGAffineTransform t = transformForMat(combined, size, &outSize);
            CGImageRef result = createImageByDrawing(img, outSize, t, CGRectMake(0, 0, size.width, size.height), !typeSupportsAlpha(type));
            CGImageRelease(img);
            if (result)
            {
                ok = rewriteFile(path, src, result, error);
                CGImageRelease(result);
            }
        }
        if (!ok && error && !*error)
            *error = editError(path, @"The image could not be decoded.");
    }

    CFRelease(src);
    return ok;
}

+ (BOOL)resizeFile:(NSString*)path toSize:(NSSize)size fit:(BOOL)fit error:(NSError**)error
{
    CGImageSourceRef src = createSource(path, error);
    if (!src)
        return NO;

    BOOL ok = NO;
    CGImageRef img = createNormalizedImage(src, !typeSupportsAlpha(sourceType(src)));
    if (img)
    {
        CGSize cur = CGSizeMake(CGImageGetWidth(img), CGImageGetHeight(img));
        CGSize target = size;
        if (fit)
        {
            double scale = MIN(size.width / cur.width, size.height / cur.height);
            target = CGSizeMake(MAX(1, round(cur.width * scale)), MAX(1, round(cur.height * scale)));
        }
        CGImageRef result = createImageByDrawing(img, target, CGAffineTransformIdentity, CGRectMake(0, 0, target.width, target.height), NO);
        CGImageRelease(img);
        if (result)
        {
            ok = rewriteFile(path, src, result, error);
            CGImageRelease(result);
        }
    }
    if (!ok && error && !*error)
        *error = editError(path, @"The image could not be decoded.");

    CFRelease(src);
    return ok;
}

+ (BOOL)cropFile:(NSString*)path toRect:(NSRect)rect error:(NSError**)error
{
    CGImageSourceRef src = createSource(path, error);
    if (!src)
        return NO;

    BOOL ok = NO;
    CGImageRef img = createNormalizedImage(src, !typeSupportsAlpha(sourceType(src)));
    if (img)
    {
        CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(img), CGImageGetHeight(img));
        CGRect crop = CGRectIntegral(CGRectIntersection(NSRectToCGRect(rect), bounds));
        CGImageRef result = CGRectIsEmpty(crop) ? NULL : CGImageCreateWithImageInRect(img, crop);
        CGImageRelease(img);
        if (result)
        {
            ok = rewriteFile(path, src, result, error);
            CGImageRelease(result);
        }
        else if (error)
            *error = editError(path, @"The crop area is empty.");
    }
    if (!ok && error && !*error)
        *error = editError(path, @"The image could not be decoded.");

    CFRelease(src);
    return ok;
}

+ (NSString*)convertFile:(NSString*)path toType:(UTType*)type quality:(double)quality error:(NSError**)error
{
    CGImageSourceRef src = createSource(path, error);
    if (!src)
        return nil;

    NSString* result = nil;
    CGImageRef img = createNormalizedImage(src, !typeSupportsAlpha(type));
    if (img)
    {
        // Pick a name that does not clobber anything
        NSString* base = [[path stringByDeletingPathExtension] lastPathComponent];
        NSString* dir  = [path stringByDeletingLastPathComponent];
        NSString* ext  = [type preferredFilenameExtension];
        NSString* out  = [dir stringByAppendingPathComponent:[base stringByAppendingPathExtension:ext]];
        for (int n = 2; [[NSFileManager defaultManager] fileExistsAtPath:out]; n++)
            out = [dir stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@ %d", base, n] stringByAppendingPathExtension:ext]];

        if (writeImage(img, [NSURL fileURLWithPath:out], type, propertiesForWriting(src, img, type, quality), path, error))
            result = out;
        CGImageRelease(img);
    }
    else if (error)
        *error = editError(path, @"The image could not be decoded.");

    CFRelease(src);
    return result;
}

+ (NSArray<UTType*>*)convertTypes
{
    NSMutableArray* types = [NSMutableArray array];
    for (UTType* t in @[UTTypeJPEG, UTTypePNG, UTTypeHEIC, UTTypeTIFF, UTTypeGIF, UTTypeBMP, [UTType typeWithIdentifier:@"public.jpeg-2000"]])
        if (t && typeIsWritable(t))
            [types addObject:t];
    return types;
}

+ (BOOL)typeIsLossy:(UTType*)type
{
    return [type conformsToType:UTTypeJPEG] || [type conformsToType:UTTypeHEIC] || [type conformsToType:UTTypeHEIF]
        || [type conformsToType:[UTType typeWithIdentifier:@"public.jpeg-2000"]];
}

//==============================================================================
// Sheets

static NSTextField* makeLabel(NSString* text, NSRect frame)
{
    NSTextField* l = [NSTextField labelWithString:text];
    [l setFrame:frame];
    [l setAlignment:NSTextAlignmentRight];
    return l;
}

+ (void)askResizeOnWindow:(NSWindow*)window size:(NSSize)size multiple:(BOOL)multiple completion:(void (^)(BOOL ok, NSSize size))completion
{
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:multiple ? @"Resize Images" : @"Resize Image"];
    [alert setInformativeText:multiple ? @"Each image is scaled to fit within this size. The original files are overwritten."
                                       : @"The original file is overwritten."];
    [alert addButtonWithTitle:@"Resize"];
    [alert addButtonWithTitle:@"Cancel"];

    NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, 56)];
    NSTextField* width  = [[NSTextField alloc] initWithFrame:NSMakeRect(70, 30, 80, 22)];
    NSTextField* height = [[NSTextField alloc] initWithFrame:NSMakeRect(70, 4, 80, 22)];
    NSNumberFormatter* fmt = [[NSNumberFormatter alloc] init];
    [fmt setAllowsFloats:NO];
    [fmt setMinimum:@1];
    [fmt setMaximum:@65535];
    [width setFormatter:fmt];
    [height setFormatter:fmt];
    [width setIntValue:(int)size.width];
    [height setIntValue:(int)size.height];
    [view addSubview:makeLabel(@"Width:", NSMakeRect(0, 32, 64, 18))];
    [view addSubview:makeLabel(@"Height:", NSMakeRect(0, 6, 64, 18))];
    [view addSubview:width];
    [view addSubview:height];
    [view addSubview:makeLabel(@"px", NSMakeRect(154, 32, 24, 18))];
    [view addSubview:makeLabel(@"px", NSMakeRect(154, 6, 24, 18))];

    NSButton* keep = nil;
    if (!multiple && size.width > 0 && size.height > 0)
    {
        keep = [NSButton checkboxWithTitle:@"Keep aspect ratio" target:nil action:nil];
        [keep setFrame:NSMakeRect(70, 60, 170, 18)];
        [keep setState:NSControlStateValueOn];
        [view setFrame:NSMakeRect(0, 0, 240, 82)];
        [view addSubview:keep];

        // Keep the other field in step while typing
        double aspect = size.width / size.height;
        [[NSNotificationCenter defaultCenter] addObserverForName:NSControlTextDidChangeNotification object:width queue:nil usingBlock:^(NSNotification* n) {
            if ([keep state] == NSControlStateValueOn) [height setIntValue:MAX(1, (int)round([width doubleValue] / aspect))];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:NSControlTextDidChangeNotification object:height queue:nil usingBlock:^(NSNotification* n) {
            if ([keep state] == NSControlStateValueOn) [width setIntValue:MAX(1, (int)round([height doubleValue] * aspect))];
        }];
    }
    [alert setAccessoryView:view];
    [[alert window] setInitialFirstResponder:width];

    dispatch_async(dispatch_get_main_queue(), ^{
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
            [[NSNotificationCenter defaultCenter] removeObserver:width];
            [[NSNotificationCenter defaultCenter] removeObserver:height];
            completion(response == NSAlertFirstButtonReturn, NSMakeSize([width doubleValue], [height doubleValue]));
        }];
    });
}

+ (void)askConvertOnWindow:(NSWindow*)window completion:(void (^)(BOOL ok, UTType* type, double quality))completion
{
    NSArray<UTType*>* types = [self convertTypes];

    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Convert Format"];
    [alert setInformativeText:@"A new file is written next to the original."];
    [alert addButtonWithTitle:@"Convert"];
    [alert addButtonWithTitle:@"Cancel"];

    NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 260, 56)];
    NSPopUpButton* popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(70, 30, 180, 24) pullsDown:NO];
    for (UTType* t in types)
        [popup addItemWithTitle:[t localizedDescription] ?: [[t preferredFilenameExtension] uppercaseString]];
    NSSlider* quality = [NSSlider sliderWithValue:0.9 minValue:0.1 maxValue:1.0 target:nil action:nil];
    [quality setFrame:NSMakeRect(70, 4, 180, 20)];
    NSTextField* qualityLabel = makeLabel(@"Quality:", NSMakeRect(0, 6, 64, 18));
    [view addSubview:makeLabel(@"Format:", NSMakeRect(0, 34, 64, 18))];
    [view addSubview:popup];
    [view addSubview:qualityLabel];
    [view addSubview:quality];
    [alert setAccessoryView:view];

    void (^updateQuality)(void) = ^{
        BOOL lossy = [ImageEdit typeIsLossy:[types objectAtIndex:[popup indexOfSelectedItem]]];
        [quality setEnabled:lossy];
        [qualityLabel setTextColor:lossy ? [NSColor labelColor] : [NSColor disabledControlTextColor]];
    };
    [[NSNotificationCenter defaultCenter] addObserverForName:NSMenuDidSendActionNotification object:[popup menu] queue:nil usingBlock:^(NSNotification* n) { updateQuality(); }];
    updateQuality();

    dispatch_async(dispatch_get_main_queue(), ^{
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
            [[NSNotificationCenter defaultCenter] removeObserver:popup];
            completion(response == NSAlertFirstButtonReturn, [types objectAtIndex:[popup indexOfSelectedItem]], [quality doubleValue]);
        }];
    });
}

+ (void)confirmEditOnWindow:(NSWindow*)window message:(NSString*)message completion:(void (^)(BOOL ok))completion
{
    if (![prefsGet(PrefConfirmEdits) boolValue])
    {
        completion(YES);
        return;
    }
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:@"The original file is overwritten. This cannot be undone."];
    [alert addButtonWithTitle:@"Continue"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setShowsSuppressionButton:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
            if ([[alert suppressionButton] state] == NSControlStateValueOn)
                prefsSet(PrefConfirmEdits, @NO);
            completion(response == NSAlertFirstButtonReturn);
        }];
    });
}

+ (NSArray<NSMenuItem*>*)menuItemsIncludingCrop:(BOOL)includeCrop
{
    NSMutableArray* items = [NSMutableArray array];
    void (^add)(NSString*, SEL) = ^(NSString* title, SEL action) {
        if (title)
            [items addObject:[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""]];
        else
            [items addObject:[NSMenuItem separatorItem]];
    };
    add(@"Rotate Left", @selector(rotateLeft:));
    add(@"Rotate Right", @selector(rotateRight:));
    add(@"Rotate 180°", @selector(rotate180:));
    add(nil, NULL);
    add(@"Flip Horizontal", @selector(flipHorizontal:));
    add(@"Flip Vertical", @selector(flipVertical:));
    add(nil, NULL);
    add(@"Resize…", @selector(resizeImage:));
    if (includeCrop)
    {
        add(@"Crop", @selector(cropImage:));
        add(@"Apply Crop", @selector(applyCrop:));
    }
    add(nil, NULL);
    add(@"Convert Format…", @selector(convertImage:));
    return items;
}

+ (void)showErrors:(NSArray<NSError*>*)errors onWindow:(NSWindow*)window
{
    if ([errors count] == 0)
        return;
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setMessageText:[errors count] == 1 ? @"The image could not be edited" : [NSString stringWithFormat:@"%d images could not be edited", (int)[errors count]]];
    NSMutableArray* lines = [NSMutableArray array];
    for (NSError* e in [errors subarrayWithRange:NSMakeRange(0, MIN(8, [errors count]))])
        [lines addObject:[e localizedDescription]];
    if ([errors count] > 8)
        [lines addObject:@"…"];
    [alert setInformativeText:[lines componentsJoinedByString:@"\n"]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert beginSheetModalForWindow:window completionHandler:nil];
    });
}

@end
