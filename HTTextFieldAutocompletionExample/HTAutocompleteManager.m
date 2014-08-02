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
@property (nonatomic, strong) NSMutableOrderedSet *predictions;
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
        _predictions = [[NSMutableOrderedSet alloc] init];
    }
    return self;
}
#pragma mark - HTAutocompleteTextFieldDelegate
- (void)textField:(HTAutocompleteTextField *)textField asyncCompletionForPrefix:(NSString *)prefix ignoreCase:(BOOL)ignoreCase completionHandler:(void (^)(NSString *))completionHandler {
    if (prefix.length == 0) {
        return completionHandler(@"");
    }
    NSString *locallySavedAddress;
    if ([self.predictions count] > 0) {
        locallySavedAddress = [self checkLocalForAddress:prefix];
    }
    
    if (locallySavedAddress) {
        return completionHandler(locallySavedAddress);
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
                    NSString *address = @"";
                    if(predictions.count > 0){
                        address = predictions[0][@"description"];
                    }

                    [self addToCache:json forPrefix:prefix];
                    return completionHandler(address);
                }
            }];
            [self.fetchAddressSuggestionTask resume];
        }
    }
}
-(BOOL)textFieldShouldReplaceCompletionText:(HTAutocompleteTextField *)textField {
    return YES;
}
- (void) addToCache:(NSDictionary *)predictionsDictionary forPrefix:(NSString *)prefix{
    NSArray *addresses = predictionsDictionary[@"predictions"];
    for (int i = 0; i < addresses.count; i++) {
        NSDictionary *location = addresses[i];
        [self.predictions addObject:@{@"title":location[@"description"], @"rank":@(prefix.length*10 + i)}];
    }
    NSSortDescriptor *rankSort = [NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES];
    [self.predictions sortUsingDescriptors:@[rankSort]];
}

- (NSString *)checkLocalForAddress:(NSString *)prefix {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title BEGINSWITH %@", prefix];
    NSOrderedSet *completions = self.predictions.copy;

    completions = [completions filteredOrderedSetUsingPredicate:predicate];
    if(completions.count > 0 ){
        return completions[0][@"title"];
    }
    return nil;
}

@end
