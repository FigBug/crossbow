//
//  ImageEdit.h
//  Crossbow
//
//  File based image edits used by the browser and the viewer.
//
//  Rotate and flip are lossless for JPEG and HEIC: only the EXIF orientation
//  tag is rewritten and the compressed image data is copied untouched. Every
//  other format, and every pixel edit (resize, crop), re-encodes the file in
//  its own format. Convert writes a new file next to the original.
//

#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef NS_ENUM(int, ImageEditOp)
{
    ImageEditRotateLeft,
    ImageEditRotateRight,
    ImageEditRotate180,
    ImageEditFlipHorizontal,
    ImageEditFlipVertical,
};

// The actions the browser and viewer implement for the editing menus
@protocol ImageEditActions <NSObject>
@optional
- (IBAction)rotateLeft:(id)sender;
- (IBAction)rotateRight:(id)sender;
- (IBAction)rotate180:(id)sender;
- (IBAction)flipHorizontal:(id)sender;
- (IBAction)flipVertical:(id)sender;
- (IBAction)resizeImage:(id)sender;
- (IBAction)cropImage:(id)sender;
- (IBAction)applyCrop:(id)sender;
- (IBAction)cancelCrop:(id)sender;
- (IBAction)convertImage:(id)sender;
@end

@interface ImageEdit : NSObject

// Edits that overwrite the file in place
+ (BOOL)applyOp:(ImageEditOp)op toFile:(NSString*)path error:(NSError**)error;
+ (BOOL)resizeFile:(NSString*)path toSize:(NSSize)size fit:(BOOL)fit error:(NSError**)error;
+ (BOOL)cropFile:(NSString*)path toRect:(NSRect)rect error:(NSError**)error; // pixels, origin top left, as displayed

// Writes a new file next to the original and returns its path
+ (NSString*)convertFile:(NSString*)path toType:(UTType*)type quality:(double)quality error:(NSError**)error;

+ (NSSize)pixelSizeOfFile:(NSString*)path; // as displayed, orientation applied
+ (BOOL)canEditFile:(NSString*)path;
+ (NSArray<UTType*>*)convertTypes;
+ (BOOL)typeIsLossy:(UTType*)type;

// Sheets shared by the browser and the viewer
+ (void)askResizeOnWindow:(NSWindow*)window size:(NSSize)size multiple:(BOOL)multiple completion:(void (^)(BOOL ok, NSSize size))completion;
+ (void)askConvertOnWindow:(NSWindow*)window completion:(void (^)(BOOL ok, UTType* type, double quality))completion;
+ (void)confirmEditOnWindow:(NSWindow*)window message:(NSString*)message completion:(void (^)(BOOL ok))completion;
+ (void)showErrors:(NSArray<NSError*>*)errors onWindow:(NSWindow*)window;

// Menu items for every edit, targeting the responder chain. Crop items only make sense in the viewer.
+ (NSArray<NSMenuItem*>*)menuItemsIncludingCrop:(BOOL)includeCrop;

@end
