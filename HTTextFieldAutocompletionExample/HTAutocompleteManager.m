//
//  HTAutocompleteManager.m
//  HotelTonight
//
//  Created by Jonathan Sibley on 12/6/12.
//  Copyright (c) 2012 Hotel Tonight. All rights reserved.
//
const NSString *kZipCode = @"97115";
#import "apiKeys.h"
#import "HTAutocompleteManager.h"

static HTAutocompleteManager *sharedManager;

@interface HTAutocompleteManager ()
@property (nonatomic, strong) NSURLSessionDataTask *fetchAddressSuggestionTask;
@property (nonatomic, strong) NSMutableSet *predictions;
@property (nonatomic, strong) NSString *locallySavedAddress;
@end

@implementation HTAutocompleteManager

+ (HTAutocompleteManager *)sharedManager
{
	static dispatch_once_t done;
	dispatch_once(&done, ^{ sharedManager = [[HTAutocompleteManager alloc] init]; });
    
	return sharedManager;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _predictions = [NSMutableSet new];
    }
    return self;
}
#pragma mark - HTAutocompleteTextFieldDelegate
- (void)textField:(HTAutocompleteTextField *)textField asyncCompletionForPrefix:(NSString *)prefix ignoreCase:(BOOL)ignoreCase completionHandler:(void (^)(NSString *))completionHandler {
    
    if ([self.predictions count] > 0) {
        self.locallySavedAddress = [self checkLocalForAddress:prefix];
    }
    
    if (self.locallySavedAddress) {
        NSString *formattedAddress = [self.locallySavedAddress substringFromIndex:prefix.length];
        return completionHandler(formattedAddress);
    } else {
        if (textField.autocompleteType == HTAutocompleteTypeAddress && prefix.length > 3) {
            if(self.fetchAddressSuggestionTask) {
                [self.fetchAddressSuggestionTask cancel];
                self.fetchAddressSuggestionTask = nil;
            }
            
            NSString *encodedPrefix = [prefix stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
            
            NSString *urlString = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/autocomplete/json?input=%@&types=geocode&components=country:US&key=%@", encodedPrefix, kGoogleKey];
            
            NSURL *url = [NSURL URLWithString:urlString];
            self.fetchAddressSuggestionTask = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if(!error) {
                    NSError *jsonError;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                    NSArray *predictions = json[@"predictions"];
                    //NSArray *predictions = [self addressesArray:json];
                    NSString *address = nil;
                    if(predictions.count > 0){
                        address = predictions[0][@"description"];
                    }
                    NSLog(@"%@", address);
                    address = [address substringFromIndex:prefix.length];
                    
                    [self addToCache:json];
                    return completionHandler(address);
                }
            }];
            [self.fetchAddressSuggestionTask resume];
        }
 
    }
    
    
}

- (void) addToCache:(NSDictionary *)predictionsDictionary {
    for (NSDictionary *location in predictionsDictionary[@"predictions"]) {
        [self.predictions addObject:location[@"description"]];
    }
}

- (NSString *)checkLocalForAddress:(NSString *)prefix {
    for (NSString *address in self.predictions) {
        NSRange atSignRange = [address rangeOfString:prefix];
        if (atSignRange.location != NSNotFound)
        {
            return address;
        }
    }
    
    return nil;
}

@end
