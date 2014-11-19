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

#define kCCBNullString @"<NULL>"

#import "ResourceManagerUtil.h"
#import "ResourceManager.h"
#import "RMDirectory.h"
#import "RMResource.h"
#import "ResourceTypes.h"
#import "RMSpriteFrame.h"
#import "RMAnimation.h"

@protocol ResourceManagerUtil_UndeclaredSelectors <NSObject>
@optional
- (void) selectedResource:(id)sender;
@end

@implementation ResourceManagerUtil

+ (void) setTitle:(NSString*)str forPopup:(NSPopUpButton*)popup forceMarker:(BOOL) forceMarker
{
    NSMenu* menu = [popup menu];
    if (!str) str = @"";
    
    // Remove items that contains a slash (/ or •)
    NSArray* items = [[menu itemArray] copy];
    for (NSMenuItem* item in items)
    {
        NSRange range0 = [item.title rangeOfString:@"/"];
        NSRange range1 = [item.title rangeOfString:@"•"];
        if (range0.location == NSNotFound && range1.location == NSNotFound) continue;
        
        [menu removeItem:item];
    }
    
    // Add a • in front of the name if multiple active directories are used
    if (forceMarker
        || [[[ResourceManager sharedManager] activeDirectories] count] > 1)
    {
        str = [NSString stringWithFormat:@"• %@",str];
    }
    
    // Set the title
    [popup setTitle:str];
}

+ (void) setTitle:(NSString *)str forPopup:(NSPopUpButton *)popup
{
    [self setTitle:str forPopup:popup forceMarker:NO];
}

+ (void) addDirectory: (RMDirectory*) dir ToMenu: (NSMenu*) menu target:(id)target resType:(int) resType allowSpriteFrames:(BOOL) allowSpriteFrames
{
    NSArray* arr = [dir resourcesForType:resType];
    
    for (id item in arr)
    {
        if ([item isKindOfClass:[RMResource class]])
        {
            RMResource* res = item;
            
            if (res.type == kCCBResTypeImage
                || res.type == kCCBResTypeBMFont
                || res.type == kCCBResTypeCCBFile
                || res.type == kCCBResTypeTTF
                || res.type == kCCBResTypeAudio)
            {
                
                NSString* itemName = [res.filePath lastPathComponent];
                NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:itemName action:@selector(selectedResource:) keyEquivalent:@""];
                [menuItem setTarget:target];
                
                [menu addItem:menuItem];
                
                menuItem.representedObject = res;

                if (res.type == kCCBResTypeTTF) { // for user fonts menu
                    // TODO: implement preview of user fonts
                    // set item title to match font name
                    // remove last 4 characters ".ttf"
//                    NSString *fontName = [itemName substringToIndex:[itemName length] - 4];
//                    [self setFont:fontName forMenuItem:menuItem];
                }
                
            }
            else if (res.type == kCCBResTypeSpriteSheet && allowSpriteFrames)
            {
                NSString* itemName = [res.filePath lastPathComponent];
                
                NSMenu* subMenu = [[NSMenu alloc] initWithTitle:itemName];
                
                NSArray* frames = res.data;
                for (RMSpriteFrame* frame in frames)
                {
                    NSMenuItem* subItem = [[NSMenuItem alloc] initWithTitle:frame.spriteFrameName action:@selector(selectedResource:) keyEquivalent:@""];
                    [subItem setTarget:target];
                    [subMenu addItem:subItem];
                    subItem.representedObject = frame;
                }
                
                NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:itemName action:NULL keyEquivalent:@""];
                [menu addItem:menuItem];
                [menu setSubmenu:subMenu forItem:menuItem];
            }
            else if (res.type == kCCBResTypeAnimation)
            {
                NSString* itemName = [res.filePath lastPathComponent];
                
                NSMenu* subMenu = [[NSMenu alloc] initWithTitle:itemName];
                
                NSArray* anims = res.data;
                for (RMAnimation* anim in anims)
                {
                    NSMenuItem* subItem = [[NSMenuItem alloc] initWithTitle:anim.animationName action:@selector(selectedResource:) keyEquivalent:@""];
                    [subItem setTarget:target];
                    [subMenu addItem:subItem];
                    subItem.representedObject = anim;
                }
                
                NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:itemName action:NULL keyEquivalent:@""];
                [menu addItem:menuItem];
                [menu setSubmenu:subMenu forItem:menuItem];
            }
            else if (res.type == kCCBResTypeDirectory)
            {
                RMDirectory* subDir = res.data;
                
                NSString* itemName = [subDir.dirPath lastPathComponent];
                
                NSMenu* subMenu = [[NSMenu alloc] initWithTitle:itemName];
                
                [ResourceManagerUtil addDirectory:subDir ToMenu:subMenu target:target resType:resType allowSpriteFrames:allowSpriteFrames];
                
                NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:itemName action:NULL keyEquivalent:@""];
                [menu addItem:menuItem];
                [menu setSubmenu:subMenu forItem:menuItem];
            }
        }
    }
}

+ (void) populateResourceMenu:(NSMenu*)menu resType:(int)resType allowSpriteFrames:(BOOL)allowSpriteFrames selectedFile:(NSString*)file selectedSheet:(NSString*) sheetFile target:(id)target
{
    // Clear the menu and add items to it!
    [menu removeAllItems];
    
    // Sprite frames can be null
    if (resType == kCCBResTypeImage && allowSpriteFrames)
    {
        NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:kCCBNullString action:@selector(selectedResource:) keyEquivalent:@""];
        menuItem.target = target;
        menuItem.representedObject = NULL;
        [menu addItem:menuItem];
    }
    
    ResourceManager* rm = [ResourceManager sharedManager];
    
    if ([rm.activeDirectories count] == 0)
    {
        // No, active directory
        return;
    }
    else if ([rm.activeDirectories count] == 1)
    {
        // There is only a single active directory, make its contents the top level
        RMDirectory* activeDir = [rm.activeDirectories objectAtIndex:0];
    
        [ResourceManagerUtil addDirectory:activeDir ToMenu:menu target:target resType: resType allowSpriteFrames:allowSpriteFrames];
    }
    else
    {
        // There are more than one active directory, make a list of directories at
        // the top level
        for (RMDirectory* activeDir in rm.activeDirectories)
        {
            NSString* itemName = [activeDir.dirPath lastPathComponent];
            
            NSMenu* subMenu = [[NSMenu alloc] initWithTitle:itemName];
            
            [ResourceManagerUtil addDirectory:activeDir ToMenu:subMenu target:target resType:resType allowSpriteFrames:allowSpriteFrames];
            
            NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:itemName action:NULL keyEquivalent:@""];
            [menu addItem:menuItem];
            [menu setSubmenu:subMenu forItem:menuItem];
        }
    }
}

+ (void) populateResourcePopup:(NSPopUpButton*)popup resType:(int)resType allowSpriteFrames:(BOOL)allowSpriteFrames selectedFile:(NSString*)file selectedSheet:(NSString*) sheetFile target:(id)target
{
    NSMenu* menu = [popup menu];
    
    [self populateResourceMenu:menu resType:resType allowSpriteFrames:allowSpriteFrames selectedFile:file selectedSheet:sheetFile target:target];
    
    // Set the selected item
    NSString* selectedTitle = NULL;
    if (sheetFile)
    {
        selectedTitle = [NSString stringWithFormat:@"%@/%@",sheetFile,file];
    }
    else
    {
        selectedTitle = file;
    }
    if (!file || [file isEqualToString:@""])
    {
        selectedTitle = kCCBNullString;
    }
    
    [self setTitle:selectedTitle forPopup:popup];
}

+ (void) populateFontTTFPopup:(NSPopUpButton*)popup selectedFont:(NSString*)file target:(id)target
{
    NSMenu* menu = [popup menu];
    [menu removeAllItems];
    
    // System fonts submenu
    NSMenu* menuSubSystemFonts = [[NSMenu alloc] initWithTitle:@"System Fonts"];
    NSMenuItem* itemSystemFonts = [[NSMenuItem alloc] initWithTitle:@"System Fonts" action:NULL keyEquivalent:@""];
    [menu addItem:itemSystemFonts];
    
    [menu setSubmenu:menuSubSystemFonts forItem:itemSystemFonts];
    
    NSArray* systemFonts = [[ResourceManager sharedManager] systemFontList];
    for (NSString* fontName in systemFonts)
    {
        NSMenuItem* itemFont = [[NSMenuItem alloc] initWithTitle:fontName action:@selector(selectedResource:) keyEquivalent:@""];
        [itemFont setTarget:target];
        itemFont.representedObject = fontName;
        
        // set item title to match font name
        [self setFont:fontName forMenuItem:itemFont];
        
        [menuSubSystemFonts addItem:itemFont];
    }
    
    // User fonts submenu
    NSMenu* menuSubUserFonts = [[NSMenu alloc] initWithTitle:@"User Fonts"];
    NSMenuItem* itemUserFonts = [[NSMenuItem alloc] initWithTitle:@"User Fonts" action:NULL keyEquivalent:@""];
    [menu addItem:itemUserFonts];
    
    [menu setSubmenu:menuSubUserFonts forItem:itemUserFonts];
    
    [self populateResourceMenu:menuSubUserFonts resType:kCCBResTypeTTF allowSpriteFrames:NO selectedFile:file selectedSheet:NULL target:target];
    
    // Set title
    [self setTitle:file forPopup:popup forceMarker:YES];
}

+ (NSString*) relativePathFromAbsolutePath: (NSString*) path
{
    NSArray* activeDirs = [[ResourceManager sharedManager] activeDirectories];
    
    for (RMDirectory* dir in activeDirs)
    {
        NSString* base = dir.dirPath;
        
        if ([path isEqualToString:base])
        {
            return @"";
        }
        if ([path hasPrefix:base])
        {
            NSString* relPath = [path substringFromIndex:[base length]+1];
            return relPath;
        }
    }
    
    NSLog(@"WARNING! ResourceManagerUtil: No relative path for %@",path);
    for (RMDirectory* dir in activeDirs)
    {
        NSString* base = dir.dirPath;
        NSLog(@"  base: %@", base);
    }
    return NULL;
}

#pragma mark File font attributes

+ (void)setFont:(NSString*)fontName forMenuItem:(NSMenuItem*)item {
    if (fontName && item) {
        NSDictionary *attributes = @{
                                     NSFontAttributeName: [NSFont fontWithName:fontName size:16.0],
                                     };
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:fontName attributes:attributes];
        [item setAttributedTitle:attributedTitle];
    }
}

+ (CTFontRef) fontFromBundle:(NSString*)fontName withHeight:(CGFloat)height {
    // Get the path to our custom font and create a data provider.
//    NSString* fontPath = [[NSBundle mainBundle] pathForResource : fontName ofType : @"ttf" ];
//    NSString *fontPath = [[ResourceManager sharedManager] toAbsolutePath:fontName];
    NSString *fontPath = fontName;
    if (nil==fontPath)
        return NULL;
    
    CGDataProviderRef dataProvider =
    CGDataProviderCreateWithFilename ([fontPath UTF8String]);
    if (NULL==dataProvider)
        return NULL;
    
    // Create the font with the data provider, then release the data provider.
    CGFontRef fontRef = CGFontCreateWithDataProvider ( dataProvider );
    if ( NULL == fontRef )
    {
        CGDataProviderRelease ( dataProvider );
        return NULL;
    }
    
    CTFontRef fontCore = CTFontCreateWithGraphicsFont(fontRef, height, NULL, NULL);
    CGDataProviderRelease (dataProvider);
    CGFontRelease(fontRef);
    
    return fontCore;
}

#pragma mark File icons

+ (NSImage*) smallIconForFile:(NSString*)file
{
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:file];
    [icon setScalesWhenResized:YES];
    icon.size = NSMakeSize(16, 16);
    return icon;
}

+ (NSImage*) smallIconForFileType:(NSString*)type
{
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFileType:type];
    [icon setScalesWhenResized:YES];
    icon.size = NSMakeSize(16, 16);
    return icon;
}

+ (NSImage*) iconForResource:(RMResource*) res
// TODO: Seems like this is never called?
{
    NSImage* icon = NULL;
    
	// FIXME: Do all images by type
    if (res.type == kCCBResTypeImage)
    {
        icon = [ResourceManagerUtil smallIconForFileType:@"png"];
    }
    else
    {
        if (res.type == kCCBResTypeDirectory)
        {
            RMDirectory* dir = res.data;
            if (dir.isDynamicSpriteSheet)
            {
                icon = [NSImage imageNamed:@"reshandler-spritesheet-folder.png"];
            }
            else
            {
                icon = [ResourceManagerUtil smallIconForFile:res.filePath];
            }
        }
        else
        {
            icon = [ResourceManagerUtil smallIconForFile:res.filePath];
        }
    }
    return icon;
}

@end
