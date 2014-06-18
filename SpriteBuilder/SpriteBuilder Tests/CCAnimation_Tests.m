//
//  CCAnimation_Tests.m
//  SpriteBuilder
//
//  Created by John Twigg on 6/9/14.
//
//

#import <XCTest/XCTest.h>
#import "cocos2d.h"
#import "CCBXCocos2diPhone.h"
#import "PlugInManager.h"
#import "PlugInExport.h"
#import "CCBReader.h"
#import "CCAnimationManager.h"
#import "CCAnimationManager_Private.h"
#import "CCBSequence.h"

#define IS_NEAR(a,b,accuracy) (fabsf(a - b) < kAccuracy)


@implementation CCAnimationManager (Test)

-(CCBSequence*)runningSequence
{
	return _runningSequence;
}

@end

typedef void (^CallbackBlock) ();
@interface CCAnimationDelegateTester : NSObject<CCBAnimationManagerDelegate>
{
	CallbackBlock _sequenceFinished;
}


@end




@implementation CCAnimationDelegateTester
{
	NSMutableDictionary * methodBlocks;
	
}

-(void)setSequenceFinishedCallback:(CallbackBlock)sequenceFinished
{
	_sequenceFinished = [sequenceFinished copy];
}

-(void)registerMethod:(NSString*)callback block:(CallbackBlock)block
{
	if(methodBlocks == nil)
	{
		methodBlocks = [NSMutableDictionary dictionary];
	}
	
	methodBlocks[callback] = [block copy];
}

void dynamicMethodIMP(CCAnimationDelegateTester * self, SEL _cmd)
{
	NSString * selectorName = NSStringFromSelector(_cmd);
	if(self->methodBlocks[selectorName])
	{
		CallbackBlock block =self->methodBlocks[selectorName];
		block();
	}
}

+(BOOL)resolveInstanceMethod:(SEL)sel
{
	if(![super resolveInstanceMethod:sel])
	{
		class_addMethod([self class], sel, (IMP) dynamicMethodIMP, "v@:");
		return YES;
	}

			
	return YES;
}


- (void) completedAnimationSequenceNamed:(NSString*)name
{
	if(_sequenceFinished)
		_sequenceFinished();
}

@end

@interface CCAnimation_Tests : XCTestCase

@end

@implementation CCAnimation_Tests

-(NSData*)readCCB:(NSString*)srcFileName
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForResource:srcFileName ofType:@"ccb"];
	NSDictionary *  doc  = [NSDictionary dictionaryWithContentsOfFile:path];
	
	PlugInExport *plugIn = [[PlugInManager sharedManager] plugInExportForExtension:@"ccbi"];
	NSData *data = [plugIn exportDocument:doc];
	return data;
}

- (void)setUp
{
    [super setUp];
	

	
	
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}



- (void)testAnimationSync1
{
	
	CCAnimationDelegateTester * callbackTest = [[CCAnimationDelegateTester alloc] init];

	
	
	NSData * animData = [self readCCB:@"AnimationTest1"];
	XCTAssertNotNil(animData, @"Can't find ccb File");

	CCBReader * reader = [CCBReader reader];
	CCNode * rootNode = [reader loadWithData:animData owner:callbackTest];
	
	CCNode * node0 = rootNode.children[0];
	CCNode * node1 = rootNode.children[1];
	CCNode * node2 = rootNode.children[2];
	
	
	XCTAssertTrue([node0.name isEqualToString:@"node0"]);
	XCTAssertTrue([node1.name isEqualToString:@"node1"]);
	XCTAssertTrue([node2.name isEqualToString:@"node2"]);
	 
	
	const float kDelta = 0.1f;//100ms;
	const CGFloat kAccuracy = 0.01f;
	const CGFloat kTranslation = 500.0f;
	
	
	float totalElapsed = 0.0f;
	__block float currentAnimElapsed = 0.0f;
	
	CCBSequence * seq = rootNode.animationManager.sequences[0];
	
	[rootNode.animationManager setCompletedAnimationCallbackBlock:^(CCAnimationManager * manager) {
		XCTAssertTrue(fabsf(currentAnimElapsed - seq.duration) < kAccuracy, @"The animation should have taken 4 seconds. Possible divergenc.");

		currentAnimElapsed = 0.0f;
	}];
	
	while(totalElapsed <= seq.duration * 20)
	{
		[rootNode.animationManager update:kDelta];
		
		totalElapsed += kDelta;
		currentAnimElapsed += kDelta;

		float timeIntoSeq = rootNode.animationManager.runningSequence.time;

		//This animation specifcally see's all three nodes translate after three seconds back to the root pos.
		if(timeIntoSeq >= 3.0f)
		{
			//All final translations go from x=500 -> x=0 over 1 second.
			float perentageIntroSyncedTranlation = 1.0f - (seq.duration - timeIntoSeq);
			float desiredXCoord = (1.0f - perentageIntroSyncedTranlation) * kTranslation;
			
			XCTAssertTrue(fabsf(node0.position.x - node1.position.x) < kAccuracy, @"They should all equal each other");
			XCTAssertTrue(fabsf(node0.position.x - node2.position.x) < kAccuracy, @"They should all equal each other");
			XCTAssertTrue(fabsf(node0.position.x - desiredXCoord) < kAccuracy,	  @"They should all equal each desiredXCoord. Possible divergenc. XPos:%0.2f DesiredPos:%0.2f totalElapsed:%0.2f", node0.position.x,desiredXCoord, totalElapsed);
			
		}
	}
}

-(void)testAnimationCallback1
{
	
	CCAnimationDelegateTester * callbackTest = [[CCAnimationDelegateTester alloc] init];

	NSData * animData = [self readCCB:@"AnimationTest1"];
	XCTAssertNotNil(animData, @"Can't find ccb File");
	
	CCBReader * reader = [CCBReader reader];
	CCNode * rootNode = [reader loadWithData:animData owner:callbackTest];
	
	CCBSequence * seq = rootNode.animationManager.sequences[0];
	rootNode.animationManager.delegate = callbackTest;
	
	const float kDelta = 0.1f;//100ms;
	const CGFloat kAccuracy = 0.01f;
	const CGFloat kTranslation = 500.0f;
	
	float totalElapsed = 0.0f;
	__block float currentAnimElapsed = 0.0f;
	
	[callbackTest setSequenceFinishedCallback:^{
		currentAnimElapsed = 0.0f;
	}];
	
	[callbackTest registerMethod:@"onMiddleOfAnimation" block:^{
		XCTAssertTrue(fabsf(currentAnimElapsed - seq.duration /2.0f) < kAccuracy, @"Not in the middle of the sequence");
	}];
	
	__block BOOL endCallbackWasCalled = NO;
	[callbackTest registerMethod:@"onEndOfAnim1" block:^{
		XCTAssertTrue(fabsf(currentAnimElapsed) < kAccuracy, @"Should be at the end of the frame, however its been looped so its Zero.");
		endCallbackWasCalled = YES;
	}];
	

	while(totalElapsed <= seq.duration * 20)
	{
		[rootNode.animationManager update:kDelta];
		
		totalElapsed += kDelta;
		currentAnimElapsed += kDelta;
		
	}
	
	XCTAssert(endCallbackWasCalled, @"Should be called");
		
}


//This test file  "AnimationTest2.ccb" has two animations. T1 and T2.
//The test ensures that when T1 ends, we launch T2 with a tween of 100ms.
-(void)testAnimationTween1
{
	
	CCAnimationDelegateTester * callbackTest = [[CCAnimationDelegateTester alloc] init];
	
	NSData * animData = [self readCCB:@"AnimationTest2"];
	XCTAssertNotNil(animData, @"Can't find ccb File");
	
	CCBReader * reader = [CCBReader reader];
	CCNode * rootNode = [reader loadWithData:animData owner:callbackTest];
	CCNode * node0 = rootNode.children[0];
	
	XCTAssertTrue([node0.name isEqualToString:@"node0"]);
	
	CCBSequence * seq = rootNode.animationManager.sequences[0];
	rootNode.animationManager.delegate = callbackTest;
	
	const float kDelta = 0.1f;//100ms;
	const CGFloat kAccuracy = 0.01f;
	const CGFloat kXTranslation = 500.0f;
	const CGFloat kYTranslation = 200.0f;
	const CGFloat kTween = 1.0f;
	
	float totalElapsed = 0.0f;
	__block BOOL firstTime = YES;
	__block float currentAnimElapsed = 0.0f;
	__block BOOL playingDefaultAnimToggle = YES;
	
	[callbackTest setSequenceFinishedCallback:^{
		
		//When the animation finished, Toggle over to the next T1/T2 animation.
		firstTime = NO;
		playingDefaultAnimToggle = !playingDefaultAnimToggle;
		[rootNode.animationManager runAnimationsForSequenceNamed:playingDefaultAnimToggle ? @"T1" : @"T2" tweenDuration:kTween];

		//Reset clock.
		currentAnimElapsed = 0.0f;
	}];
	
	//
	
	typedef void (^ValidateAnimation) (float timeIntoAnimation);
	
	ValidateAnimation validationAnimBlock =^(float timeIntoAnimation)
	{
		//We're in T1 + tween. Ensure valid
		//Also, always skip frame 0.
		
		if(timeIntoAnimation < 0.0f || IS_NEAR(timeIntoAnimation,0.0f,kAccuracy))
		{
			return;
		}
		else if(timeIntoAnimation < 1.0f || IS_NEAR(timeIntoAnimation,1.0f,kAccuracy))
		{
			
			float percentage = (timeIntoAnimation - kDelta);
			float xCoord =  kXTranslation * (percentage);
			XCTAssertEqualWithAccuracy(node0.position.x, xCoord, kAccuracy, @"They should all equal each other");
		}
		else if(timeIntoAnimation < 3.0f || IS_NEAR(timeIntoAnimation,3.0f,kAccuracy))
		{
			int break_here = 1;
			
			XCTAssertEqualWithAccuracy(node0.position.x, kXTranslation, kAccuracy, @"Error: timeIntoAnim:%0.2f", timeIntoAnimation);
		}
		else if(timeIntoAnimation  < 4.0f || IS_NEAR(timeIntoAnimation,4.0f,kAccuracy))
		{
			
			float percentage = (timeIntoAnimation  - 3.0f);
			float xCoord = kXTranslation * (1.0f - percentage);
			XCTAssertEqualWithAccuracy(node0.position.x, xCoord, kAccuracy, @"They should all equal each other");
		}

	};
	
	bool alreadyDone = NO;
	
	while(totalElapsed <= (seq.duration + kTween) * 20)
	{
		totalElapsed += kDelta;
		currentAnimElapsed += kDelta;
		
		[rootNode.animationManager update:kDelta];
				
		if(firstTime)
		{
			validationAnimBlock(currentAnimElapsed);
			continue;
		}
		
		
		
		
		if(!playingDefaultAnimToggle)
		{
			//Playing T2 animation.
			
			//In tween and greather that the first frame, as the first frame stutters.
			if(currentAnimElapsed < kTween || IS_NEAR(currentAnimElapsed, kTween,kAccuracy))
			{
				//Skip first frame as it halts for one frme.
				if(currentAnimElapsed < kDelta)
					continue;

				
				//All final translations go from y=200 -> y=0
				float percentage = (currentAnimElapsed - kDelta)/ kTween;
				float yCoord = kYTranslation * (1.0f - percentage);
				
				XCTAssertEqualWithAccuracy(node0.position.y, yCoord, kAccuracy, @"They should all equal each other");
			}
			else
			{
				float timeIntoAnimation = currentAnimElapsed - kTween;
				validationAnimBlock(timeIntoAnimation);
			}

		}
		else //Playing T1 animation.
		{
			//Ensure tween from T2(end) -> T1(start)
			if(currentAnimElapsed < kTween)
			{
				//Skip first frame as it halts for one frme.
				if(currentAnimElapsed < kDelta)
					continue;
				
				//Should interpolate from y= 0 -> y = 200;
				float percentage = (currentAnimElapsed - kDelta)/ kTween;
				float yCoord = kYTranslation * (percentage);
				
				XCTAssertEqualWithAccuracy(node0.position.y, yCoord, kAccuracy, @"They should all equal each other");
			}
			else
			{
				float timeIntoAnimation = currentAnimElapsed - kTween;
				validationAnimBlock(timeIntoAnimation);
			}
		}
	}
		
	
}


@end
