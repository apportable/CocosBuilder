#import <Foundation/Foundation.h>
#import "CCBWarnings.h"

@class PublishRenamedFilesLookup;
@class PublishResolutions;


@interface CCBPublishingTarget : NSObject

@property (nonatomic) BOOL useMainProjectResolutionsOfInputPackages;

@property (nonatomic, copy) NSArray *inputPackages;
@property (nonatomic, copy) NSString *outputDirectory;
@property (nonatomic, copy) NSString *directoryToClean;
@property (nonatomic) CCBPublisherOSType osType;
@property (nonatomic, strong) PublishResolutions *resolutions;
@property (nonatomic) CCBPublishEnvironment publishEnvironment;

@property (nonatomic, copy) NSString *zipOutputPath;

@property (nonatomic, strong) NSMutableSet *publishedPNGFiles;
@property (nonatomic, strong) PublishRenamedFilesLookup *renamedFilesLookup;
@property (nonatomic, strong) NSMutableSet *publishedSpriteSheetFiles;

@end