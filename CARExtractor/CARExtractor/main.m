//
//  main.m
//  CARExtractor
//
//  Created by Brandon McQuilkin on 10/27/14.
//
//  Based on  by cartool Steven Troughton-Smith on 14/07/2013.
//  Copyright (c) 2013 High Caffeine Content. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma Private Frameworks

@interface CUICommonAssetStorage : NSObject

-(NSArray *)allAssetKeys;
-(NSArray *)allRenditionNames;

-(id)initWithPath:(NSString *)p;

-(NSString *)versionString;

@end

@interface CUINamedImage : NSObject

-(CGImageRef)image;
-(double)scale;
-(CGSize)size;

@end

@interface CUIRenditionKey : NSObject
@end

@interface CUIThemeFacet : NSObject

+(CUIThemeFacet *)themeWithContentsOfURL:(NSURL *)u error:(NSError **)e;
+ (void)_invalidateArtworkCaches;

@end

@interface CUICatalog : NSObject

-(id)initWithName:(NSString *)n fromBundle:(NSBundle *)b;
-(id)allKeys;
-(id)imagesWithName:(NSString *)imageName;
-(CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s;
-(CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s deviceIdiom:(int)idiom;

@end

#define kCoreThemeIdiomPhone 1
#define kCoreThemeIdiomPad 2

#pragma mark Export Image

void CGImageWriteToFile(CGImageRef image, NSString *path)
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path.stringByDeletingLastPathComponent])
        [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:true attributes:nil error:nil];
    
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, image, nil);
    
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to write image to %@", path);
    }
    
    CFRelease(destination);
}

#pragma mark Export CAR

/**
 For some reason, when -[CUICatalog imageWithName:scaleFactor:deviceIdiom:] is called with scaleFactor of 3.0 and iPhone idiom, it returns image with scale factor of 2.0 even through asset catalog contains image with scaleFactor of 3.0.
 Looping through all images in the catalog manually allows us to find the correct image with correct scale.
 
This loop doesn't check for device idiom and it has been only tested with assets for iPhone. It should be extended to work with other device idioms in the future.
 */
CUINamedImage* extractImageFromCatalog(NSString *name, CGFloat scaleFactor, int deviceIdiom, CUICatalog *catalog)
{
    NSArray *images = [catalog imagesWithName:name];
    for (CUINamedImage *image in images)
    {
        if(deviceIdiom == kCoreThemeIdiomPhone &&
           !CGSizeEqualToSize(image.size, CGSizeZero) &&
           (fabs([image scale] - scaleFactor) < 0.001))
        {
            return image;
        }
    }
    
    // Fallback to default functionality
    return [catalog imageWithName:name scaleFactor:scaleFactor deviceIdiom:deviceIdiom];
}

void exportCarFileAtPath(NSString * carPath, NSString *outputDirectoryPath)
{
    NSError *error = nil;
    
    CUIThemeFacet *facet = [CUIThemeFacet themeWithContentsOfURL:[NSURL fileURLWithPath:carPath] error:&error];
    CUICatalog *catalog = [[CUICatalog alloc] init];
    /* Override CUICatalog to point to a file rather than a bundle */
    [catalog setValue:facet forKey:@"_storageRef"];
    /* CUICommonAssetStorage won't link */
    CUICommonAssetStorage *storage = [[NSClassFromString(@"CUICommonAssetStorage") alloc] initWithPath:carPath];
    
    for (NSString *key in [storage allRenditionNames])
    {
        NSLog(@"    Writing Image: %@", key);
        
        CGImageRef iphone1X = [extractImageFromCatalog(key, 1.0, kCoreThemeIdiomPhone, catalog) image];
        CGImageRef iphone2X = [extractImageFromCatalog(key, 2.0, kCoreThemeIdiomPhone, catalog) image];
        CGImageRef iphone3X = [extractImageFromCatalog(key, 3.0, kCoreThemeIdiomPhone, catalog) image];
        CGImageRef ipad1X = [extractImageFromCatalog(key, 1.0, kCoreThemeIdiomPad, catalog) image];
        CGImageRef ipad2X = [extractImageFromCatalog(key, 2.0, kCoreThemeIdiomPad, catalog) image];
        
        if (iphone1X)
            CGImageWriteToFile(iphone1X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@~iphone.png", key]]);
        
        if (iphone2X && iphone2X != iphone1X)
            CGImageWriteToFile(iphone2X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@~iphone@2x.png", key]]);
        
        if (iphone3X && iphone3X != iphone2X)
            CGImageWriteToFile(iphone3X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@~iphone@3x.png", key]]);
        
        if (ipad1X && ipad1X != iphone1X)
            CGImageWriteToFile(ipad1X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@~ipad.png", key]]);
        
        if (ipad2X && ipad2X != iphone2X)
            CGImageWriteToFile(ipad2X, [outputDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@~ipad@2x.png", key]]);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        //Check inputs
        NSString *input = [[NSUserDefaults standardUserDefaults] stringForKey:@"i"];
        NSString *output = [[NSUserDefaults standardUserDefaults] stringForKey:@"o"];
        
        if (!input || !output) {
            NSLog(@"Invalid call, missing input or output.");
            return 1;
        }
        
        exportCarFileAtPath(input, output);
    }
    return 0;
}
