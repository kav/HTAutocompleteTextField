//
//  HTAutocompleteManager.m
//  HotelTonight
//
//  Created by Jonathan Sibley on 12/6/12.
//  Copyright (c) 2012 Hotel Tonight. All rights reserved.
//
#import "HTAutocompleteManager.h"

static HTAutocompleteManager *sharedManager;

@interface HTAutocompleteManager ()
@property (nonatomic, strong) NSURLSessionDataTask *fetchAddressSuggestionTask;
@property (nonatomic, strong) NSOrderedSet *predictions;
@property (nonatomic, strong) NSTimer *fetchDelayTimer;
@end

@implementation HTAutocompleteManager

+ (HTAutocompleteManager *)sharedManager
{
	static dispatch_once_t done;
	dispatch_once(&done, ^{ sharedManager = [[HTAutocompleteManager alloc] init]; });
    
	return sharedManager;
}
@end
