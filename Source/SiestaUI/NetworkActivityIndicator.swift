//
//  NetworkActivityIndicator.swift
//  Siesta
//
//  Created by Andrew Reed on 30/10/2016.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import UIKit

/// Set a variable to count the requests and then we know when to show the network activity indicator.
private var requestsInProgress = 0
    {
    didSet
        {
        UIApplication.shared.isNetworkActivityIndicatorVisible =
            requestsInProgress > 0
        }
    }

extension Service
    {
    
    private func requestStarted()
        {
        requestsInProgress += 1
        }
    
    private func requestCompleted()
        {
        requestsInProgress -= 1
        }

    /**
     On each request we will show the network activity indicator.
     */
    public func showRequestsWithNetworkActivityIndicator()
        {
        configure
            {
            $0.decorateRequests
                {
                res, req in
                
                self.requestStarted()
                req.onCompletion { _ in self.requestCompleted() }
                
                return req
                }
            }
        }
    }

extension Configuration
    {
    /**
     On each request we will show the network activity indicator.
     */
    public func showRequestsWithNetworkActivityIndicator()
        {
            //configure
        }
    }
