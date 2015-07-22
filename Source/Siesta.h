//
//  Siesta.h
//  Siesta
//
//  Created by Paul on 2015/6/14.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for Siesta.
FOUNDATION_EXPORT double SiestaVersionNumber;

//! Project version string for Siesta.
FOUNDATION_EXPORT const unsigned char SiestaVersionString[];

// Workaround for https://github.com/bustoutsolutions/siesta/issues/1
#define BOSService               Service
#define BOSResource              Resource
#define BOSResourceObserver      _objc_ResourceObserver
#define BOSResourceStatusOverlay ResourceStatusOverlay
