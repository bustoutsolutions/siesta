//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

public class Resource
    {
    public unowned let service: Service
    public let url: NSURL?
    
    init(service: Service, url: NSURL?)
        {
        self.service = service
        self.url = url?.absoluteURL;
        }
    }
