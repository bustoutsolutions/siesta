//
//  ObjcCompatibilitySpec.m
//  Siesta
//
//  Created by Paul on 2015/8/7.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

#import <Siesta/Siesta.h>
#import "SiestaTests-Swift.h"
#import <XCTest/XCTest.h>

@interface ObjcCompatibilitySpec : XCTestCase
    {
    TestService *service;
    BOSResource *resource;
    NSMutableArray *allRequests;
    id _;  // Fake version of Swift’s `_ = foo()` idiom for non-@discardableResult functions
    }
@end

@interface ObjcObserver : NSObject<BOSResourceObserver>
@property (nonatomic,strong) NSMutableArray *eventsReceived;
@end

@implementation ObjcCompatibilitySpec

- (void) setUp
    {
    [super setUp];

    service = [[TestService alloc] init];
    resource = [service resource:@"/foo"];
    allRequests = [NSMutableArray array];

    self.continueAfterFailure = false;
    }

- (void) tearDown
    {
    [service awaitAllRequests];  // because unlike the Swift specs, the individual specs here don't wait for them
    [NetworkStub clearAll];
    service = nil;
    resource = nil;
    _ = nil;
    }

// These specs are mostly just concerned with whether the code compiles.
// They don't make many assertions about behavior, which is tested elsewhere.

- (void) testHandlesResourcePaths
    {
    _ = [resource child:@"bar"];
    _ = [resource relative:@"../bar"];
    _ = [resource withParam:@"foo" value:@"bar"];
    _ = [resource withParams:@{@"foo": @"bar", @"baz": NSNull.null}];
    }

- (void) testHandlesBasicRequest
    {
    [NetworkStub addForMethod:@"GET" resource:resource returningStatusCode:200];
    XCTAssertNotNil([resource loadIfNeeded]);
    _ = [resource load];
    }

- (void) testHandlesRequestMutation
    {
    [NetworkStub addForMethod:@"POST" resource:resource returningStatusCode:200];
    _ = [resource requestWithMethod:@"DELETE" data:[[NSData alloc] init] contentType:@"foo/bar" requestMutation:
        ^(NSMutableURLRequest *req)
            { req.HTTPMethod = @"POST"; }];
    }

- (void) testHandlesJSONRequest
    {
    [NetworkStub addForMethod:@"POST" resource:resource headers:@{@"Content-Type": @"application/json"} body:@"{\"foo\":\"bar\"}" returningStatusCode:200];
    _ = [resource requestWithMethod:@"POST" json:@{@"foo": @"bar"}];
    }

- (void) testHandlesJSONRequestWithCustomContentType
    {
    [NetworkStub addForMethod:@"POST" resource:resource headers:@{@"Content-Type": @"foo/bar"} body:@"{\"foo\":\"bar\"}" returningStatusCode:200];
    _ = [resource requestWithMethod:@"POST" json:@{@"foo": @"bar"} contentType:@"foo/bar" requestMutation:nil];
    }

- (void) testHandlesTextRequest
    {
    [NetworkStub addForMethod:@"POST" resource:resource headers:@{@"Content-Type": @"text/plain; charset=utf-8"} body:@"Ahoy" returningStatusCode:200];
    _ = [resource requestWithMethod:@"POST" text:@"Ahoy"];
    }

- (void) testHandlesTestRequestWithCustomContentTypeAndEncoding
    {
    [NetworkStub addForMethod:@"POST" resource:resource headers:@{@"Content-Type": @"foo/bar; charset=us-ascii"} body:@"Ahoy" returningStatusCode:200];
    _ = [resource requestWithMethod:@"POST" text:@"Ahoy" contentType:@"foo/bar" encoding:NSASCIIStringEncoding requestMutation:nil];
    }

- (void) testHandlesURLEncodedRequest
    {
    [NetworkStub addForMethod:@"POST" resource:resource headers:@{@"Content-Type": @"application/x-www-form-urlencoded"} body:@"foo=bar" returningStatusCode:200];
    _ = [resource requestWithMethod:@"POST" urlEncoded:@{@"foo": @"bar"} requestMutation:nil];
    }

- (void) testHandlesLoadUsingRequest
    {
    [NetworkStub addForMethod:@"POST" resource:resource headers:@{} body:@"{\"foo\":\"bar\"}" returningStatusCode:200];
    _ = [resource loadUsingRequest:[resource requestWithMethod:@"POST" json:@{@"foo": @"bar"}]];
    }

- (void) testHandlesCallbacks
    {
    [NetworkStub addForMethod:@"GET" resource:resource returningStatusCode:200];
    XCTestExpectation *expectation = [self expectationWithDescription:@"callback called"];
    BOSRequest *req = [[[[[[resource load]
        onCompletion:
            ^(BOSEntity *entity, BOSError *error)
                { [expectation fulfill]; }]
        onSuccess: ^(BOSEntity *entity) { }]
        onNewData: ^(BOSEntity *entity) { }]
        onNotModified: ^{ }]
        onFailure: ^(BOSError *error) { }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    [req cancel];
    }

- (void) expectImmediateFailure: (BOSRequest*) request
    {
    XCTestExpectation *expectation = [self expectationWithDescription:@"failed request"];
    __block BOOL immediatelyFailed = false;
    _ = [request onFailure: ^(BOSError *error)
        {
        [expectation fulfill];
        immediatelyFailed = true;
        }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssert(immediatelyFailed);
    };

- (void) testHandlesInvalidRequestMethodStrings
    {
    [self expectImmediateFailure:
        [resource requestWithMethod:@"FLARGBLOTZ"]];
    }

- (void) testHandlesInvalidJSONObjects
    {
    [self expectImmediateFailure:
        [resource requestWithMethod:@"POST" json:[[NSData alloc] init]]];
    }

- (void) testHandlesResourceData
    {
    [NetworkStub addForMethod:@"GET" resource:resource returningStatusCode:200 headers:@{@"Content-type": @"application/json"} body:@"{\"foo\": \"bar\"}"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"network calls finished"];
    _ = [[resource load] onSuccess:^(BOSEntity *entity) { [expectation fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertEqualObjects(resource.jsonDict, @{ @"foo": @"bar" });
    XCTAssertEqualObjects(resource.jsonArray, @[]);
    XCTAssertEqualObjects(resource.text, @"");

    BOSEntity *entity = resource.latestData;
    XCTAssertEqualObjects(entity.content, @{ @"foo": @"bar" });
    XCTAssertEqualObjects(entity.contentType, @"application/json");
    XCTAssertEqualObjects([entity header:@"cOnTeNt-TyPe"], @"application/json");

    entity.content = @"Wild and wooly content";
    [resource overrideLocalData:entity];
    entity = [[BOSEntity alloc] initWithContent:@"Homespun" contentType:@"knick/knack"];
    entity = [[BOSEntity alloc] initWithContent:@"Homespun" contentType:@"knick/knack" headers: @{}];
    [resource overrideLocalData:entity];

    XCTAssertNil(resource.latestError);
    }

- (void) testHandlesHTTPErrors
    {
    [NetworkStub addForMethod:@"GET" resource:resource returningStatusCode:507];

    XCTestExpectation *expectation = [self expectationWithDescription:@"network calls finished"];
    _ = [[resource load] onFailure:^(BOSError *error) { [expectation fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    BOSError *error = resource.latestError;
    XCTAssertEqualObjects(error.userMessage, @"Server error");
    XCTAssertEqualObjects(@(error.httpStatusCode), @507);

    XCTAssertNil(resource.latestData);
    }

- (void) testHandlesOtherErrors
    {
    BOSRequest *req = [resource loadUsingRequest:
        [resource requestWithMethod:@"POST" json:@{@"Foo": [[NSData alloc] init]}]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"network calls finished"];
    _ = [req onFailure:^(BOSError *error) { [expectation fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    BOSError *error = resource.latestError;
    XCTAssertEqualObjects(error.userMessage, @"Cannot send request");
    XCTAssertEqualObjects(@(error.httpStatusCode), @-1);
    }

- (void) testDoesntAddObserversTwiceSpecialCaseBecauseGlueObjectObscuresIdentity
    {
    ObjcObserver *observer0 = [[ObjcObserver alloc] init],
                 *observer1 = [[ObjcObserver alloc] init];
    NSString *owner = [@"I am a big important owner string!" mutableCopy];  // copy b/c string literal never released!
    _ = [resource addObserver:observer0];
    _ = [resource addObserver:observer0];
    _ = [resource addObserver:observer1];
    _ = [resource addObserver:observer0 owner:owner];

    __block int blockObserverCalls = 0;
    _ = [resource addObserverWithOwner:owner callback:^(BOSResource *resource, NSString *event) {
        blockObserverCalls++;
    }];

    [NetworkStub addForMethod:@"GET" resource:resource returningStatusCode:200 headers:@{@"Content-type": @"application/json"} body:@"{\"foo\": \"bar\"}"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"network calls finished"];
    _ = [[resource load] onSuccess:^(BOSEntity *entity) { [expectation fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertEqualObjects(observer0.eventsReceived, (@[@"ObserverAdded", @"Requested", @"NewData(Network)"]));
    XCTAssertEqualObjects(observer1.eventsReceived, (@[@"ObserverAdded", @"Requested", @"NewData(Network)"]));
    XCTAssertEqualObjects(@(blockObserverCalls), @3);

    [resource removeObserversOwnedBy:observer1];
    [resource wipe];  // forces observer cleanup
    XCTAssertEqualObjects(observer0.eventsReceived, (@[@"ObserverAdded", @"Requested", @"NewData(Network)", @"NewData(Wipe)"]));
    XCTAssertEqualObjects(observer1.eventsReceived, (@[@"ObserverAdded", @"Requested", @"NewData(Network)", @"stoppedObserving"]));
    }

- (void) testHonorsObserverOwnership
    {
    ObjcObserver __weak *observerWeak = nil;
    @autoreleasepool {
        // Keep events array even after observer deallocated
        NSMutableArray *eventsReceived = [NSMutableArray array];
        ObjcObserver *observer = [[ObjcObserver alloc] init];
        observer.eventsReceived = eventsReceived;

        // Let Siesta ownership control observer lifecycle
        NSObject *owner = [[NSObject alloc] init];
        _ = [resource addObserver:observer owner:owner];
        observerWeak = observer;
        observer = nil;

        // Owner still around: we get events, observer lives on
        [resource wipe];
        XCTAssertNotNil(observerWeak);
        XCTAssertEqualObjects(eventsReceived, (@[@"ObserverAdded", @"NewData(Wipe)"]));

        // Owner still around: no more events, observer gone
        owner = nil;
        [resource wipe];
        XCTAssertEqualObjects(eventsReceived, (@[@"ObserverAdded", @"NewData(Wipe)", @"stoppedObserving"]));
    }
    XCTAssertNil(observerWeak);
    }

@end


@implementation ObjcObserver : NSObject

- (void) resourceChanged: (BOSResource*) resource
                   event: (NSString *) event
    {
    if(!self.eventsReceived)
        self.eventsReceived = [NSMutableArray array];
    [self.eventsReceived addObject:event];
    }

- (void) stoppedObservingResource: (BOSResource * _Nonnull) resource
    {
    [self.eventsReceived addObject:@"stoppedObserving"];
    }

@end
