#import "RMResource.h"/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2012 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
#import "MigrationLogger.h"

#import "ProjectSettings.h"
#import "NSString+RelativePath.h"
#import "HashValue.h"
#import "PlugInManager.h"
#import "PlugInExport.h"
#import "ResourceManager.h"
#import "AppDelegate.h"
#import "ResourceManagerOutlineHandler.h"
#import "CCBWarnings.h"
#import "Errors.h"
#import "ResourceTypes.h"
#import "NSError+SBErrors.h"
#import "MiscConstants.h"
#import "ResourceManagerUtil.h"
#import "RMDirectory.h"
#import "ResourcePropertyKeys.h"


NSString *const PROJECTSETTINGS_KEY_FILEVERSION = @"fileVersion";
NSString *const PROJECTSETTINGS_KEY_RESOURCEPROPERTIES = @"resourceProperties";
NSString *const PROJECTSETTINGS_KEY_PACKAGES = @"packages";
NSString *const PROJECTSETTINGS_KEY_PUBLISHDIR_IOS = @"publishDirectoryIOS";
NSString *const PROJECTSETTINGS_KEY_PUBLISHDIR_ANDROID = @"publishDirectoryAndroid";
NSString *const PROJECTSETTINGS_KEY_DEPRECATED_RESOURCESPATHS = @"resourcePaths";
NSString *const PROJECTSETTINGS_KEY_DEPRECATED_ONLYPUBLISHCCBS = @"onlyPublishCCBs";
NSString *const PROJECTSETTINGS_KEY_DEPRECATED_ENGINE = @"engine";
NSString *const PROJECTSETTINGS_KEY_DEPRECATED_PUBLISHDIR_IOS = @"publishDirectory";
NSString *const PROJECTSETTINGS_KEY_DEPRECATED_EXCLUDEFROMPACKAGEMIGRATION = @"excludedFromPackageMigration";

@interface ProjectSettings()

@property (nonatomic, strong) NSMutableDictionary* resourceProperties;
@property (nonatomic) BOOL storing;

@end


@implementation ProjectSettings

- (instancetype)initWithFilepath:(NSString *)filepath
{
    NSMutableDictionary *projectDict = [NSMutableDictionary dictionaryWithContentsOfFile:filepath];
    if (!projectDict)
    {
        return nil;
    }

    self = [self initWithSerialization:projectDict];

    if (self)
    {
        self.projectPath = filepath;
    }

    return self;
}

- (id) init
{
    self = [super init];
    if (!self)
    {
        return NULL;
    }

    self.packages = [[NSMutableArray alloc] init];
    self.publishDirectoryIOS = @"Published-iOS";
    self.publishDirectoryAndroid = @"Published-Android";

    self.publishToZipFile = NO;

    self.deviceOrientationLandscapeLeft = YES;
    self.deviceOrientationLandscapeRight = YES;

    self.publishEnabledIOS = YES;
    self.publishEnabledAndroid = YES;

    self.exporter = kCCBDefaultExportPlugIn;

    self.publishEnvironment = kCCBPublishEnvironmentDevelop;

    self.tabletPositionScaleFactor = 2.0f;

    self.canUpdateCocos2D = NO;
    self.cocos2dUpdateIgnoredVersions = [NSMutableArray array];
    
    self.resourceProperties = [NSMutableDictionary dictionary];
    
    // Load available exporters
    self.availableExporters = [NSMutableArray array];
    for (PlugInExport* plugIn in [[PlugInManager sharedManager] plugInsExporters])
    {
        [_availableExporters addObject: plugIn.extension];
    }

    self.versionStr = [self getVersion];
    self.needRepublish = NO;

    return self;
}

- (id) initWithSerialization:(id)dict
{
    self = [self init];
    if (!self
        || ![[dict objectForKey:@"fileType"] isEqualToString:@"CocosBuilderProject"])
    {
        return NULL;
    }

    self.packages = [dict objectForKey:PROJECTSETTINGS_KEY_PACKAGES];

    self.publishDirectoryIOS = [dict objectForKey:PROJECTSETTINGS_KEY_PUBLISHDIR_IOS];
    if (!_publishDirectoryIOS)
    {
        self.publishDirectoryIOS = @"";
    }

    self.publishDirectoryAndroid = [dict objectForKey:PROJECTSETTINGS_KEY_PUBLISHDIR_ANDROID];
    if (!_publishDirectoryAndroid)
    {
        self.publishDirectoryAndroid = @"";
    }

    self.publishEnabledIOS = [[dict objectForKey:@"publishEnablediPhone"] boolValue];
    self.publishEnabledAndroid = [[dict objectForKey:@"publishEnabledAndroid"] boolValue];

    self.publishToZipFile = [[dict objectForKey:@"publishToZipFile"] boolValue];

    self.exporter = [dict objectForKey:@"exporter"]
        ? [dict objectForKey:@"exporter"]
        : kCCBDefaultExportPlugIn;

    self.deviceOrientationPortrait = [[dict objectForKey:@"deviceOrientationPortrait"] boolValue];
    self.deviceOrientationUpsideDown = [[dict objectForKey:@"deviceOrientationUpsideDown"] boolValue];
    self.deviceOrientationLandscapeLeft = [[dict objectForKey:@"deviceOrientationLandscapeLeft"] boolValue];
    self.deviceOrientationLandscapeRight = [[dict objectForKey:@"deviceOrientationLandscapeRight"] boolValue];

    self.cocos2dUpdateIgnoredVersions = [[dict objectForKey:@"cocos2dUpdateIgnoredVersions"] mutableCopy];

    self.deviceScaling = [[dict objectForKey:@"deviceScaling"] intValue];
    self.defaultOrientation = [[dict objectForKey:@"defaultOrientation"] intValue];
    self.designTarget = (SBDesignTarget) [[dict objectForKey:@"designTarget"] intValue];
    
    self.tabletPositionScaleFactor = 2.0f;

    self.publishEnvironment = (CCBPublishEnvironment) [[dict objectForKey:@"publishEnvironment"] integerValue];

    self.resourceProperties = [[dict objectForKey:@"resourceProperties"] mutableCopy];

    [self initializeVersionStringWithProjectDict:dict];

    return self;
}

- (void)initializeVersionStringWithProjectDict:(NSDictionary *)projectDict
{
    // Check if we are running a new version of CocosBuilder
    // in which case the project needs to be republished
    NSString* oldVersionHash = projectDict[@"versionStr"];
    NSString* newVersionHash = [self getVersion];
    if (newVersionHash && ![newVersionHash isEqual:oldVersionHash])
    {
       self.versionStr = [self getVersion];
       self.needRepublish = YES;
    }
    else
    {
       self.needRepublish = NO;
    }
}

- (NSString*) exporter
{
    if (_exporter)
    {
        return _exporter;
    }
    return kCCBDefaultExportPlugIn;
}

- (id) serialize
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];

    dict[@"fileType"] = @"CocosBuilderProject";
    dict[PROJECTSETTINGS_KEY_FILEVERSION] = @kCCBProjectSettingsVersion;
    dict[PROJECTSETTINGS_KEY_PACKAGES] = _packages;
    
    dict[PROJECTSETTINGS_KEY_PUBLISHDIR_IOS] = _publishDirectoryIOS;
    dict[PROJECTSETTINGS_KEY_PUBLISHDIR_ANDROID] = _publishDirectoryAndroid;

    dict[@"publishEnablediPhone"] = @(_publishEnabledIOS);
    dict[@"publishEnabledAndroid"] = @(_publishEnabledAndroid);

    dict[@"publishToZipFile"] = @(_publishToZipFile);
    dict[@"exporter"] = self.exporter;
    
    dict[@"deviceOrientationPortrait"] = @(_deviceOrientationPortrait);
    dict[@"deviceOrientationUpsideDown"] = @(_deviceOrientationUpsideDown);
    dict[@"deviceOrientationLandscapeLeft"] = @(_deviceOrientationLandscapeLeft);
    dict[@"deviceOrientationLandscapeRight"] = @(_deviceOrientationLandscapeRight);

    dict[@"cocos2dUpdateIgnoredVersions"] = _cocos2dUpdateIgnoredVersions;

    dict[@"designTarget"] = @(_designTarget);
    dict[@"defaultOrientation"] = @(_defaultOrientation);
    dict[@"deviceScaling"] = @(_deviceScaling);

    dict[@"publishEnvironment"] = @(_publishEnvironment);

    if (_resourceProperties)
    {
        dict[@"resourceProperties"] = _resourceProperties;
    }
    else
    {
        dict[@"resourceProperties"] = [NSDictionary dictionary];
    }

    if (_versionStr)
    {
        dict[@"versionStr"] = _versionStr;
    }

    return dict;
}

@dynamic absolutePackagePaths;
- (NSArray*)absolutePackagePaths
{
    NSString* projectDirectory = [self.projectPath stringByDeletingLastPathComponent];
    
    NSMutableArray* paths = [NSMutableArray array];
    
    for (NSDictionary* dict in _packages)
    {
        NSString* path = dict[@"path"];
        NSString* absPath = [path absolutePathFromBaseDirPath:projectDirectory];
        [paths addObject:absPath];
    }
    
    if ([paths count] == 0)
    {
        [paths addObject:projectDirectory];
    }
    
    return paths;
}

@dynamic projectPathHashed;
- (NSString*) projectPathHashed
{
    if (_projectPath)
    {
        HashValue* hash = [HashValue md5HashWithString:_projectPath];
        return [hash description];
    }
    else
    {
        return NULL;
    }
}

@dynamic displayCacheDirectory;
- (NSString*) displayCacheDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [[[paths[0] stringByAppendingPathComponent:PUBLISHER_CACHE_DIRECTORY_NAME] stringByAppendingPathComponent:@"display"]stringByAppendingPathComponent:self.projectPathHashed];
}

@dynamic tempSpriteSheetCacheDirectory;
- (NSString*) tempSpriteSheetCacheDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [[paths[0] stringByAppendingPathComponent:PUBLISHER_CACHE_DIRECTORY_NAME] stringByAppendingPathComponent:@"spritesheet"];
}

- (void) _storeDelayed
{
    [self store];
    self.storing = NO;
}

- (BOOL) store
{
    return [[self serialize] writeToFile:self.projectPath atomically:YES];
}

- (void) storeDelayed
{
    // Store the file after a short delay
    if (!_storing)
    {
        self.storing = YES;
        [self performSelector:@selector(_storeDelayed) withObject:NULL afterDelay:1];
    }
}

- (void) makeSmartSpriteSheet:(RMResource*) res
{
    NSAssert(res.type == kCCBResTypeDirectory, @"Resource must be directory");

    [self setProperty:@YES forResource:res andKey:RESOURCE_PROPERTY_IS_SMARTSHEET];
    
    [self store];
    [[ResourceManager sharedManager] notifyResourceObserversResourceListUpdated];
    [[AppDelegate appDelegate].projectOutlineHandler updateSelectionPreview];
}

- (void) removeSmartSpriteSheet:(RMResource*) res
{
    NSAssert(res.type == kCCBResTypeDirectory, @"Resource must be directory");

    [self removePropertyForResource:res andKey:RESOURCE_PROPERTY_IS_SMARTSHEET];

    [self removeIntermediateFileLookupFile:res];

    [self store];
    [[ResourceManager sharedManager] notifyResourceObserversResourceListUpdated];
    [[AppDelegate appDelegate].projectOutlineHandler updateSelectionPreview];
}

- (void)removeIntermediateFileLookupFile:(RMResource *)res
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *intermediateFileLookup = [res.filePath stringByAppendingPathComponent:INTERMEDIATE_FILE_LOOKUP_NAME];
    if ([fileManager fileExistsAtPath:intermediateFileLookup])
    {
        NSError *error;
        if (![fileManager removeItemAtPath:intermediateFileLookup error:&error])
        {
            NSLog(@"Error removing intermediate filelookup file %@ - %@", intermediateFileLookup, error);
        }
    }
}

- (void)setProperty:(id)newValue forResource:(RMResource *)res andKey:(id <NSCopying>) key
{
    NSString* relPath = res.relativePath;
    [self setProperty:newValue forRelPath:relPath andKey:key];
}

- (void)setProperty:(id)newValue forRelPath:(NSString *)relPath andKey:(id <NSCopying>)key
{
    NSMutableDictionary *props = [self resourcePropertiesForRelPath:relPath];

    id oldValue = props[key];
    if ([oldValue isEqual:newValue])
    {
        return;
    }

    [props setValue:newValue forKey:(NSString *)key];
    [self markAsDirtyRelPath:relPath];
    [self storeDelayed];
}

- (NSMutableDictionary *)resourcePropertiesForRelPath:(NSString *)relPath
{
    NSMutableDictionary* props = [_resourceProperties valueForKey:relPath];
    if (!props)
    {
        props = [NSMutableDictionary dictionary];
        [_resourceProperties setValue:props forKey:relPath];
    }
    return props;
}

- (id)propertyForResource:(RMResource *)res andKey:(id <NSCopying>) key
{
    NSString* relPath = [self findRelativePathInPackagesForAbsolutePath:res.filePath];
    return [self propertyForRelPath:relPath andKey:key];
}

- (id)propertyForRelPath:(NSString *)relPath andKey:(id <NSCopying>) key
{
    NSMutableDictionary* props = [_resourceProperties valueForKey:relPath];
    return [props valueForKey:(NSString *)key];
}

- (void)removePropertyForResource:(RMResource *)res andKey:(id <NSCopying>) key
{
    NSString* relPath = res.relativePath;
    [self removePropertyForRelPath:relPath andKey:key];
}

- (void)removePropertyForRelPath:(NSString *)relPath andKey:(id <NSCopying>) key
{
    NSMutableDictionary* props = [_resourceProperties valueForKey:relPath];
    [props removeObjectForKey:key];

    [self markAsDirtyRelPath:relPath];

    [self storeDelayed];
}

- (BOOL) isDirtyResource:(RMResource*) res
{
    return [self isDirtyRelPath:res.relativePath];
}

- (BOOL) isDirtyRelPath:(NSString*) relPath
{
    return [[self propertyForRelPath:relPath andKey:@"isDirty"] boolValue];
}

- (void) markAsDirtyResource:(RMResource*) res
{
    [self markAsDirtyRelPath:res.relativePath];
}

- (void) markAsDirtyRelPath:(NSString*) relPath
{
    if(!relPath)
    {
        return;
    }

    // NSLog(@"mark as dirty: %@", relPath);

    [self setProperty:@YES forRelPath:relPath andKey:@"isDirty"];
}

- (void)clearDirtyMarkerOfRelPath:(NSString *)relPath
{
    NSMutableDictionary *props = [_resourceProperties valueForKey:relPath];
    [props removeObjectForKey:@"isDirty"];
}

- (void)clearDirtyMarkerOfResource:(RMResource *)resource
{
    [self clearDirtyMarkerOfRelPath:resource.relativePath];
}

- (void) clearAllDirtyMarkers
{
    for (NSString* relPath in _resourceProperties)
    {
        [self clearDirtyMarkerOfRelPath:relPath];
    }
    
    [self storeDelayed];
}

- (void) removedResourceAt:(NSString*) relPath
{
    [_resourceProperties removeObjectForKey:relPath];

    [self markSpriteSheetDirtyForOldResourceRelPath:relPath];
}

- (void)movedResourceFrom:(NSString *)relPathOld to:(NSString *)relPathNew fromFullPath:(NSString *)fromFullPath toFullPath:(NSString *)toFullPath
{
    if ([relPathOld isEqualToString:relPathNew])
    {
        return;
    }

    // If a resource has been removed or moved to a sprite sheet it needs to be marked as dirty
    [self markSpriteSheetDirtyForOldResourceRelPath:relPathOld];
    [self markSpriteSheetDirtyForNewResourceFullPath:toFullPath];

    id props = _resourceProperties[relPathOld];
    if (props)
    {
        _resourceProperties[relPathNew] = props;
    }
    [_resourceProperties removeObjectForKey:relPathOld];

}

- (void)markSpriteSheetDirtyForOldResourceRelPath:(NSString *)oldRelPath
{
    RMResource *resource = [[ResourceManager sharedManager] resourceForRelPath:oldRelPath];
    if ([[ResourceManager sharedManager] isResourceInSpriteSheet:resource])
    {
        RMResource *spriteSheet = [[ResourceManager sharedManager] spriteSheetContainingResource:resource];
        [self markAsDirtyResource:spriteSheet];
    }
}

- (void)markSpriteSheetDirtyForNewResourceFullPath:(NSString *)newFullPath
{
    RMResource *resource = [[ResourceManager sharedManager] spriteSheetContainingFullPath:newFullPath];
    if (resource)
    {
        [self markAsDirtyResource:resource];
    }
}

- (BOOL)removePackageWithFullPath:(NSString *)fullPath error:(NSError **)error
{
    NSString *projectDir = [self.projectPath stringByDeletingLastPathComponent];
    NSString *relPackagePath = [fullPath relativePathFromBaseDirPath:projectDir];

    for (NSMutableDictionary *packageDict in [_packages copy])
    {
        NSString *relPath = packageDict[@"path"];
        if ([relPath isEqualToString:relPackagePath])
        {
            [_packages removeObject:packageDict];
            return YES;
        }
    }

    [NSError setNewErrorWithErrorPointer:error
                                    code:SBPackageNotInProjectError
                                 message:[NSString stringWithFormat:@"Cannot remove path \"%@\" does not exist in project.", relPackagePath]];
    return NO;
}

- (BOOL)addPackageWithFullPath:(NSString *)fullPath error:(NSError **)error
{
    if (![self isPackageWithFullPathInProject:fullPath])
    {
        NSString *relPackagePath = [fullPath relativePathFromBaseDirPath:self.projectPathDir];

        [_packages addObject:[@{@"path" : relPackagePath} mutableCopy]];
        return YES;
    }
    else
    {
        [NSError setNewErrorWithErrorPointer:error code:SBDuplicatePackageError message:[NSString stringWithFormat:@"Cannot create %@, already present.", [fullPath lastPathComponent]]];
        return NO;
    }
}

- (BOOL)isPackageWithFullPathInProject:(NSString *)fullPath
{
    NSString *relPackagePath = [fullPath relativePathFromBaseDirPath:self.projectPathDir];

    return [self packagePathForRelativePath:relPackagePath] != nil;
}

- (NSMutableDictionary *)packagePathForRelativePath:(NSString *)path
{
    for (NSMutableDictionary *packagePath in _packages)
    {
        NSString *aPackagePath = packagePath[@"path"];
        if ([aPackagePath isEqualToString:path])
        {
            return packagePath;
        }
    }
    return nil;
}

- (BOOL)movePackageWithFullPathFrom:(NSString *)fromPath toFullPath:(NSString *)toFullPath error:(NSError **)error
{
    if ([self isPackageWithFullPathInProject:toFullPath])
    {
        [NSError setNewErrorWithErrorPointer:error code:SBDuplicatePackageError message:@"Cannot move package, there's already one with the same name."];
        return NO;
    }

    NSString *relPackagePathOld = [fromPath relativePathFromBaseDirPath:self.projectPathDir];
    NSString *relPackagePathNew = [toFullPath relativePathFromBaseDirPath:self.projectPathDir];

    NSMutableDictionary *packageDict = [self packagePathForRelativePath:relPackagePathOld];
    packageDict[@"path"] = relPackagePathNew;

    [self movedResourceFrom:relPackagePathOld to:relPackagePathNew fromFullPath:fromPath toFullPath:toFullPath];
    return YES;
}

- (NSString *)fullPathForPackageDict:(NSMutableDictionary *)packageDict
{
    return [self.projectPathDir stringByAppendingPathComponent:packageDict[@"path"]];
}

- (NSString* ) getVersion
{
	NSDictionary * versionDict = [self getVersionDictionary];
	NSString * versionString = @"";
	
	for (NSString * key in versionDict) {
		versionString = [versionString stringByAppendingFormat:@"%@ : %@\n", key, versionDict[key]];
	}
    
    return versionString;
}

- (NSDictionary *)getVersionDictionary
{
	NSString* versionPath = [[NSBundle mainBundle] pathForResource:@"Version" ofType:@"txt" inDirectory:@"Generated"];
	
	NSError * error;
    NSString* version = [NSString stringWithContentsOfFile:versionPath encoding:NSUTF8StringEncoding error:&error];
	
	if(error)
	{
		NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
		NSString*bundleVersion = infoDict[@"CFBundleVersion"];

		NSMutableDictionary * versionDict = [NSMutableDictionary dictionaryWithDictionary:@{@"version" : bundleVersion}];
		versionDict[@"sku"] = @"default";
		return versionDict;
	}
	else
	{
		NSData* versionData = [version dataUsingEncoding:NSUTF8StringEncoding];
		NSDictionary * versionDict = [NSJSONSerialization JSONObjectWithData:versionData options:0x0 error:&error];
		return versionDict;
	}
}

- (void)setCocos2dUpdateIgnoredVersions:(NSMutableArray *)anArray
{
    _cocos2dUpdateIgnoredVersions = !anArray
        ? [NSMutableArray array]
        : anArray;
}

- (void)flagFilesDirtyWithWarnings:(CCBWarnings *)warnings
{
	for (CCBWarning *warning in warnings.warnings)
	{
		if (warning.relatedFile)
		{
			[self markAsDirtyRelPath:warning.relatedFile];
		}
	}
}

- (NSString *)projectPathDir
{
    return [_projectPath stringByDeletingLastPathComponent];
}

- (NSString *)findRelativePathInPackagesForAbsolutePath:(NSString *)absolutePath
{
    for (NSString *absolutePackagePath in self.absolutePackagePaths)
    {
        if ([absolutePath hasPrefix:absolutePackagePath])
        {
            return [absolutePath substringFromIndex:[absolutePackagePath length] + 1];
        }
    }

    return nil;
}

- (NSString *)projectName
{
    return [[self.projectPath lastPathComponent] stringByDeletingPathExtension];
}

@end
