/*
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

#import "PlugInNode.h"
#import "AppDelegate.h"
#import "CCNode+NodeInfo.h"

@implementation PlugInNode

@synthesize nodeClassName;
@synthesize nodeEditorClassName;
@synthesize displayName;
@synthesize descr;
@synthesize ordering;
@synthesize supportsTemplates;
@synthesize nodeProperties;
@synthesize nodePropertiesDict;
@synthesize dropTargetSpriteFrameClass;
@synthesize dropTargetSpriteFrameProperty;
@synthesize canBeRoot;
@synthesize canHaveChildren;
@synthesize isAbstract;
@synthesize isJoint;
@synthesize requireParentClass;
@synthesize requireChildClass;
@synthesize icon;

- (void) loadPropertiesForBundle:(NSBundle*) b intoArray:(NSMutableArray*)arr
{
    NSURL* propsURL = [b URLForResource:@"CCBPProperties" withExtension:@"plist"];
    NSMutableDictionary* props = [NSMutableDictionary dictionaryWithContentsOfURL:propsURL];
    
    // Add properties from super classes
    NSString* inheritsFrom = [props objectForKey:@"inheritsFrom"];
    if (inheritsFrom)
    {
        NSBundle* appBundle = [NSBundle mainBundle];
        NSURL* plugInDir = [appBundle builtInPlugInsURL];
        
        NSURL* superBundleURL = [plugInDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.ccbPlugNode",inheritsFrom]];
        
        NSBundle* superBundle = [NSBundle bundleWithURL:superBundleURL];
        
        [self loadPropertiesForBundle:superBundle intoArray:arr];
    }
    
    [arr addObjectsFromArray:[props objectForKey:@"properties"]];
    
    // Handle overridden properties
    NSArray* overrides = [props objectForKey:@"propertiesOverridden"];
    if (overrides)
    {
        for (int i = 0; i < [overrides count]; i++)
        {
            NSDictionary* propInfo = [overrides objectAtIndex:i];
            NSString* propName = [propInfo objectForKey:@"name"];
            
            // Find the old property
            for (int oldPropIdx = 0; oldPropIdx < [arr count]; oldPropIdx++)
            {
                NSDictionary* oldPropInfo = [arr objectAtIndex:oldPropIdx];
                if ([[oldPropInfo objectForKey:@"name"] isEqualToString:propName])
                {
                    // This property should be replaced
                    [arr replaceObjectAtIndex:oldPropIdx withObject:propInfo];
                }
            }
        }
    }
}


- (void) setupNodePropsDict
{
    // Transform the nodes info array to a dictionary for quicker lookups of properties
    
    for (int i = 0; i < [nodeProperties count]; i++)
    {
        NSDictionary* propInfo = [nodeProperties objectAtIndex:i];
        
        NSString* propName = [propInfo objectForKey:@"name"];
        if (propName)
        {
            [nodePropertiesDict setObject:propInfo forKey:propName];
        }
    }
}

- (id) initWithBundle:(NSBundle*) b
{
    self = [super init];
    if (!self) return NULL;
    
    bundle = b;
    
    // Load properties
    NSURL* propsURL = [bundle URLForResource:@"CCBPProperties" withExtension:@"plist"];
    NSMutableDictionary* props = [NSMutableDictionary dictionaryWithContentsOfURL:propsURL];
    
	//_targetEngine = CCBTargetEngineCocos2d;
    
    NSMutableSet *engines = [NSMutableSet set];
    NSArray *targetEngines = [props objectForKey:@"targetEngines"];
    
    if(targetEngines && [targetEngines containsObject:@"Cocos2D"])
        [engines addObject:[NSNumber numberWithUnsignedChar:CCBTargetEngineCocos2d]];
    if(targetEngines && [targetEngines containsObject:@"Cocos2D-X"])
        [engines addObject:[NSNumber numberWithUnsignedChar:CCBTargetEngineCocos2dx]];
    if(targetEngines && [targetEngines containsObject:@"SpriteKit"])
        [engines addObject:[NSNumber numberWithUnsignedChar:CCBTargetEngineSpriteKit]];
    
    _targetEngines = engines;
	
    nodeClassName = [props objectForKey:@"className"];
    nodeEditorClassName = [props objectForKey:@"editorClassName"];
    
    displayName = [props objectForKey:@"displayName"];
    descr = [props objectForKey:@"description"];
    ordering = [[props objectForKey:@"ordering"] intValue];
    supportsTemplates = [[props objectForKey:@"supportsTemplates"] boolValue];
    
    _hidden = [[props objectForKey:@"hidden"] boolValue];
    
    if (!displayName) displayName = [nodeClassName copy];
    if (!ordering) ordering = 100000;
    if (!descr) descr = [@"" copy];
    
    nodeProperties = [[NSMutableArray alloc] init];
    nodePropertiesDict = [[NSMutableDictionary alloc] init];
    [self loadPropertiesForBundle:bundle intoArray:nodeProperties];
    [self setupNodePropsDict];
    
    // Support for spriteFrame drop targets
    NSDictionary* spriteFrameDrop = [props objectForKey:@"spriteFrameDrop"];
    if (spriteFrameDrop)
    {
        dropTargetSpriteFrameClass = [spriteFrameDrop objectForKey:@"className"];
        dropTargetSpriteFrameProperty = [spriteFrameDrop objectForKey:@"property"];
        
    }
    
    // Check if node type can be root node and which children are allowed
    canBeRoot = [[props objectForKey:@"canBeRootNode"] boolValue];
    canHaveChildren = [[props objectForKey:@"canHaveChildren"] boolValue];
    isAbstract = [[props objectForKey:@"isAbstract"] boolValue];
    isJoint = [[props objectForKey:@"isJoint"] boolValue];
    requireChildClass = [props objectForKey:@"requireChildClass"];
    requireParentClass = [props objectForKey:@"requireParentClass"];
    positionProperty = [props objectForKey:@"positionProperty"];
    
    return self;
}

- (BOOL) acceptsDroppedSpriteFrameChildren
{
    if (dropTargetSpriteFrameClass && dropTargetSpriteFrameProperty) return YES;
    return NO;
}

- (BOOL) dontSetInEditorProperty: (NSString*) prop
{
    NSDictionary* propInfo = [nodePropertiesDict objectForKey:prop];
    BOOL dontSetInEditor = [[propInfo objectForKey:@"dontSetInEditor"] boolValue];
    if ([[propInfo objectForKey:@"type"] isEqualToString:@"Separator"]
        || [[propInfo objectForKey:@"type"] isEqualToString:@"SeparatorSub"])
    {
        dontSetInEditor = YES;
    }
    
    return dontSetInEditor;
}

- (NSString*) positionProperty
{
    if (positionProperty) return positionProperty;
    return @"position";
}

- (NSArray*) readablePropertiesForType:(NSString*)type node:(CCNode*)node
{
    BOOL useFlashSkew = [node usesFlashSkew];
    
    NSMutableArray* props = [NSMutableArray array];
    for (NSDictionary* propInfo in nodeProperties)
    {
        if (useFlashSkew && [[propInfo objectForKey:@"name"] isEqualToString:@"rotation"]) continue;
        if (!useFlashSkew && [[propInfo objectForKey:@"name"] isEqualToString:@"rotationalSkewX"]) continue;
        if (!useFlashSkew && [[propInfo objectForKey:@"name"] isEqualToString:@"rotationalSkewY"]) continue;
        
        if ([[propInfo objectForKey:@"type"] isEqualToString:type] && ![[propInfo objectForKey:@"readOnly"] boolValue])
        {
            [props addObject:[propInfo objectForKey:@"name"]];
        }
    }
    return props;
}

- (NSArray*) animatablePropertiesForNode:(CCNode*)node
{
    BOOL useFlashSkew = [node usesFlashSkew];
    
    if (!useFlashSkew && cachedAnimatableProperties) return cachedAnimatableProperties;
    if (useFlashSkew && cachedAnimatablePropertiesFlashSkew) return cachedAnimatablePropertiesFlashSkew;
    
    NSMutableArray* props = [NSMutableArray array];
    
    for (NSDictionary* propInfo in nodeProperties)
    {
        if (useFlashSkew && [[propInfo objectForKey:@"name"] isEqualToString:@"rotation"]) continue;
        if (!useFlashSkew && [[propInfo objectForKey:@"name"] isEqualToString:@"rotationalSkewX"]) continue;
        if (!useFlashSkew && [[propInfo objectForKey:@"name"] isEqualToString:@"rotationalSkewY"]) continue;
        
        if ([[propInfo objectForKey:@"animatable"] boolValue])
        {
            [props addObject:[propInfo objectForKey:@"name"]];
        }
    }
    
    if (!useFlashSkew) cachedAnimatableProperties = props;
    else cachedAnimatablePropertiesFlashSkew = props;
    
    return props;
}

- (BOOL) isAnimatableProperty:(NSString*)prop node:(CCNode*)node
{
    for (NSString* animProp in [self animatablePropertiesForNode:node])
    {
        if ([animProp isEqualToString:prop])
        {
            return YES;
        }
    }
    return NO;
}

- (NSString*) propertyTypeForProperty:(NSString*)property
{
    return [[nodePropertiesDict objectForKey:property] objectForKey:@"type"];
}

#pragma mark Drag and Drop

- (id) pasteboardPropertyListForType:(NSString *)pbType
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    if ([pbType isEqualToString:@"com.cocosbuilder.PlugInNode"])
    {
        [dict setObject:self.nodeClassName forKey:@"nodeClassName"];
        return dict;
    }
    return NULL;
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    NSMutableArray* pbTypes = [NSMutableArray arrayWithObject: @"com.cocosbuilder.PlugInNode"];
    return pbTypes;
}

- (NSPasteboardWritingOptions)writingOptionsForType:(NSString *)pbType pasteboard:(NSPasteboard *)pasteboard
{
    if ([pbType isEqualToString:@"com.cocosbuilder.PlugInNode"]) return NSPasteboardWritingPromised;
    return 0;
}

#pragma mark Deallocation

-(void) dealloc
{
	SBLogSelf();
}

@end
