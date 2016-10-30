//
//  Siesta+NetworkActivityIndicator.swift
//  Siesta
//
//  Created by Andrew Reed on 30/10/2016.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import UIKit

private var requestsInProgress = 0 {
    didSet {
        UIApplication.shared.isNetworkActivityIndicatorVisible =
        requestsInProgress > 0
    }
}

extension Service {
    
    private func requestStarted() {
        requestsInProgress += 1
    }
    
    private func requestCompleted() {
        requestsInProgress -= 1
    }

    public func showRequestsWithNetworkActivityIndicator() {
        configure {
            $0.decorateRequests {
                res, req in
                
                self.requestStarted()
                req.onCompletion { _ in self.requestCompleted() }
                
                return req
            }
        }
    }
}
