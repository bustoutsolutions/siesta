//
//  ObjcCompatibilitySpec.m
//  Siesta
//
//  Created by Paul on 2015/8/7.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

#import <Siesta/Siesta.h>
#import <Quick/Quick.h>
#import <Nimble/Nimble.h>
#import <Nocilla/Nocilla.h>
#import "SiestaTests-Swift.h"

@interface ObjcCompatibilitySpec : QuickSpec
@end

@implementation ObjcCompatibilitySpec

- (void) spec
    {
    // These specs are mostly just concerned with whether the code compiles.
    // They don't make many assertions about behavior, which is tested elsewhere.
    
    __block BOSService *service;
    __block BOSResource *resource;
    
    beforeEach(^
        {
        service = [[TestService alloc] init];
        resource = [service resourceWithPath:@"/foo"];
        });
    
    beforeSuite(^{ [LSNocilla.sharedInstance start]; });
    afterSuite( ^{ [LSNocilla.sharedInstance stop]; });
    afterEach(  ^{ [LSNocilla.sharedInstance clearStubs]; });
    
    it(@"handles resource paths", ^
        {
        [resource child:@"bar"];
        [resource relative:@"../bar"];
        [resource withParam:@"foo" value:@"bar"];
        });
    
    it(@"handles requests", ^
        {
        stubRequest(@"GET", @"http://example.api/foo").andReturn(200);
        stubRequest(@"POST", @"http://example.api/foo").andReturn(200);
        
        [resource load];
        [resource loadIfNeeded];
        [resource requestWithMethod:@"DELETE" data:[[NSData alloc] init] contentType:@"foo/bar" requestMutation:
            ^(NSMutableURLRequest *req)
                { req.HTTPMethod = @"POST"; }];
        [resource requestWithMethod:@"POST" json:@{@"foo": @"bar"}];
        [resource requestWithMethod:@"POST" json:@{@"foo": @"bar"} contentType:@"foo/bar" requestMutation:nil];
        [resource requestWithMethod:@"POST" text:@"Ahoy"];
        [resource requestWithMethod:@"POST" text:@"Ahoy" contentType:@"foo/bar" encoding:NSASCIIStringEncoding requestMutation:nil];
        [resource requestWithMethod:@"POST" urlEncoded:@{@"foo": @"bar"} requestMutation:nil];
        [resource loadUsingRequest:[resource requestWithMethod:@"POST" json:@{@"foo": @"bar"}]];
        
        XCTestExpectation *expectation = [[QuickSpec current] expectationWithDescription:@"network calls finished"];
        [resource load]
            .completion(
                ^(BOSEntity *entity, BOSError *error)
                    { [expectation fulfill]; })
            .success(^(BOSEntity *entity) { } )
            .newData(^(BOSEntity *entity) { } )
            .notModified(^{ } )
            .failure(^(BOSError *error) { } );
        [[QuickSpec current] waitForExpectationsWithTimeout:1 handler:nil];
        });
    
    it(@"handles resource data", ^
        {
        stubRequest(@"GET", @"http://example.api/foo")
            .andReturn(200)
            .withHeader(@"Content-type", @"application/json")
            .withBody(@"{\"foo\": \"bar\"}");
        
        XCTestExpectation *expectation = [[QuickSpec current] expectationWithDescription:@"network calls finished"];
        [resource load].success(^(BOSEntity *entity) { [expectation fulfill]; });
        [[QuickSpec current] waitForExpectationsWithTimeout:1 handler:nil];
        
        expect(resource.dictContent).to(equal(@{ @"foo": @"bar" }));
        expect(resource.arrayContent).to(equal(@[]));
        expect(resource.textContent).to(equal(@""));
        
        BOSEntity *entity = resource.latestData;
        expect(entity.content).to(equal(@{ @"foo": @"bar" }));
        expect(entity.contentType).to(equal(@"application/json"));
        expect([entity header:@"cOnTeNt-TyPe"]).to(equal(@"application/json"));
        });

    // TODO: BOSResourceObserver

    // TODO: BOSResourceStatusOverlay
    }

@end
