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
#define Service                BOSService
#define Resource               BOSResource
#define _objc_ResourceObserver BOSResourceObserver
#define ResourceStatusOverlay  BOSResourceStatusOverlay
