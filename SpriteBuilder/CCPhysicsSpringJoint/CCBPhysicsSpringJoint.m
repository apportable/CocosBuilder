//
//  CCBPPhysicsSpringJoint.m
//  SpriteBuilder
//
//  Created by John Twigg
//
//

#import "CCBPhysicsSpringJoint.h"
#import "AppDelegate.h"

@interface CCBPhysicsJoint()
-(void)updateSelectionUI;
@end

@implementation CCBPhysicsSpringJoint
{
    CCSprite9Slice  * jointBody;

    CCNode          * springNode;
    
    int               springPointsCount;
    float               bodyLength;

    CCSprite        * restLengthHandle;
    CCSprite9Slice  * restLengthHandleBody;

}


- (id) init
{
    self = [super init];
    if (self)
    {
        self.stiffness = 4.0f;
        self.damping = 1.0f;
    }
    
    return self;
}


-(void)setupBody
{
    [super setupBody];
    
    jointBody = [CCSprite9Slice spriteWithImageNamed:@"joint-distance.png"];
    jointBody.marginLeft = kMargin;
    jointBody.marginRight = kMargin;
    jointBody.marginBottom = 0.0;
    jointBody.marginTop = 0.0;
    jointBody.scale = 1.0;
    
    
    [scaleFreeNode addChild:jointBody];
    
    
    springNode = [CCNode node];
    [scaleFreeNode addChild:springNode];
    
    restLengthHandle = [CCSprite spriteWithImageNamed:@"joint-distance-handle-short.png"];
    restLengthHandle.anchorPoint = ccp(0.5f, 0.0f);
    [scaleFreeNode addChild:restLengthHandle];
 
    restLengthHandleBody = [CCSprite9Slice spriteWithImageNamed:@"joint-distance-slide.png"];
    restLengthHandleBody.marginLeft = 0.0f;
    restLengthHandleBody.marginRight = kMargin;
    restLengthHandleBody.marginBottom = 0.0;
    restLengthHandleBody.marginTop = 0.0;
    restLengthHandleBody.scale = 1.0;
    restLengthHandleBody.anchorPoint = ccp(0.0f,0.5f);
    [scaleFreeNode addChild:restLengthHandleBody];
    
}

-(void)updateRenderBody
{
    [super updateRenderBody];
    float length = [self worldLength];
    
    jointBody.contentSize = CGSizeMake(length + 2.0f * kEdgeRadius, kEdgeRadius * 2.0f);
    jointBody.anchorPoint = ccp(kEdgeRadius/jointBody.contentSize.width, 0.5f);
    self.rotation = [self rotation];
    
    
    restLengthHandle.position = ccpMult(ccp(length *  self.restLength / [self localLength], kEdgeRadius - 1.0f),1/[CCDirector sharedDirector].contentScaleFactor);
    
    restLengthHandleBody.contentSize = CGSizeMake(length *  self.restLength / [self localLength] + kEdgeRadius, kEdgeRadius * 2.0f);
    
    [self updateSprintBody];
   
}

const int kFlatPortion = 4.0f;

const int kSpringHeight = 64;
const int kSpringHeightHalf = kSpringHeight/2;
const int kSpringHeightTwoThirds = kSpringHeight + kSpringHeightHalf;


-(void)updateSprintBody
{
    float currentBodyLength = [self worldLength];
    if(bodyLength != currentBodyLength)
    {
        [springNode removeAllChildrenWithCleanup:YES];
        bodyLength = currentBodyLength;
        
        

        int wholeCounts = (bodyLength - kSpringHeight) / kSpringHeightHalf;
        if(wholeCounts % 2 == 0)
            wholeCounts--;


        float remainder = -1.0f;
        float padding = kSpringHeightHalf;
        float scale = 1.0f;
        if(wholeCounts > 1)
            remainder   = bodyLength - wholeCounts * kSpringHeightHalf - kSpringHeight;
        else
        {
            
            float remainingSpace = bodyLength - kSpringHeightHalf * 3;
            
            if(remainingSpace > 0)
            {
                wholeCounts = 3;
                padding = remainingSpace/2;
                remainder = 0;
            }
            else
            {
                wholeCounts = 3;
                padding = 0;
                remainder = 0;
                scale = bodyLength/(kSpringHeightHalf * 3);
            }
        }
        
        
        
        CGPoint * pt = malloc(sizeof(CGPoint) * (wholeCounts + 7));
        float sign = ((wholeCounts + 1)/2) %2 == 0 ? 1.0f : -1.0f;
        
        //Lead in Line
        pt[0] = ccp(0,0); //start
        pt[1] = ccp(padding,0); //padding.
        pt[2] = ccp(remainder/4.0f + padding, -sign * remainder/2);
        pt[3] = ccp(remainder/2.0f + padding, 0);
        pt[4] = ccp(pt[3].x + kSpringHeightHalf/2,sign * kSpringHeightHalf);
        


        float offset = pt[4].x + kSpringHeightHalf;
        
        NSLog(@"padding:%0.2f remainder:%0.2f wholecount:%i offset:%0.2f", padding, remainder, wholeCounts,offset);

        for(int i = 0; i < wholeCounts -1; i++)
        {
            pt[i+ 5] = ccp(offset + i * kSpringHeightHalf, -sign * kSpringHeightHalf);
            sign *= -1.0f;
        }
        
        pt[wholeCounts +4] = ccp(bodyLength/scale - pt[2].x, pt[2].y);
        pt[wholeCounts +5] = ccp(bodyLength/scale -  pt[1].x, 0);
        pt[wholeCounts +6] = ccp(bodyLength/scale, 0);
        
        CCColor * whiteColor = [CCColor colorWithWhite:1.0f alpha:0.3f];
        for(int i = 1; i < wholeCounts + 7; i++)
        {
            CCDrawNode * draw = [CCDrawNode node];
            [draw drawSegmentFrom:ccpMult(pt[i-1],scale) to:ccpMult(pt[i],scale) radius:1.0f color:whiteColor];
            [springNode addChild:draw];
        }
        
    }
}

-(void)visit
{
    [self updateRenderBody];
    [super visit];
}



-(JointHandleType)hitTestJointHandle:(CGPoint)worlPos
{
    {
        CGPoint pointMin = [restLengthHandle convertToNodeSpaceAR:worlPos];
        pointMin = ccpSub(pointMin, ccp(0,2.0f));
        if(ccpLength(pointMin) < 7.0f)
        {
            return RestLengthHandle;
        }
    }
    
    return [super hitTestJointHandle:worlPos];;
}

-(void)updateSelectionUI
{
    //If selected, display selected sprites.
    if(selectedBodyHandle & (1 << EntireJoint))
    {
        jointBody.spriteFrame = [CCSpriteFrame frameWithImageNamed:@"joint-distance-sel.png"];
        
        if(restLengthHandle.parent == nil)
            [scaleFreeNode addChild:restLengthHandle];
    }
    else //Unseleted
    {
        jointBody.spriteFrame = [CCSpriteFrame frameWithImageNamed:@"joint-distance.png"];
        
        if(restLengthHandle.parent != nil)
            [restLengthHandle removeFromParentAndCleanup:NO];
    }
    
    
    if(selectedBodyHandle & (1 << RestLengthHandle))
    {
        restLengthHandleBody.spriteFrame = [CCSpriteFrame frameWithImageNamed:@"joint-distance-slide-sel.png"];
    }
    else
    {
        restLengthHandleBody.spriteFrame = [CCSpriteFrame frameWithImageNamed:@"joint-distance-slide.png"];
    }
    
    [super updateSelectionUI];
}



#pragma mark - Properties -


-(void)setAnchorA:(CGPoint)lAnchorA
{
    [super setAnchorA:lAnchorA];
    //refresh max mins
    self.restLength = self.restLength;
    
}


-(void)setAnchorB:(CGPoint)lAnchorB
{
    [super setAnchorB:lAnchorB];
    //refresh max mins
    self.restLength = self.restLength;
}



-(void)setBodyHandle:(CGPoint)worldPos bodyType:(JointHandleType)bodyType
{
    if(bodyType == RestLengthHandle)
    {
        CGPoint localPoint = [self convertToNodeSpace:worldPos];
        self.restLength =  localPoint.x;
        [[AppDelegate appDelegate] refreshProperty:@"restLength"];
    }
    
    [super setBodyHandle:worldPos bodyType:bodyType];
}

-(void)setBodyA:(CCNode *)lBodyA
{
    [super setBodyA:lBodyA];
    self.restLength = [self worldLength];
    [[AppDelegate appDelegate] refreshProperty:@"restLength"];    
}

-(void)setBodyB:(CCNode *)lBodyB
{
    [super setBodyB:lBodyB];
    self.restLength = [self worldLength];
    [[AppDelegate appDelegate] refreshProperty:@"restLength"];
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == self.bodyB)
    {

    
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


@end