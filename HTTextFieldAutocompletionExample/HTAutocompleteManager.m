//
//  HTAutocompleteManager.m
//  HotelTonight
//
//  Created by Jonathan Sibley on 12/6/12.
//  Copyright (c) 2012 Hotel Tonight. All rights reserved.
//
const NSString *kZipCode = @"97115";
const CGFloat kFetchDelay = 1;
#import "apiKeys.h"
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
- (instancetype)init
{
    self = [super init];
    if (self) {
        _predictions = [[NSMutableOrderedSet alloc] init];
        _fetchDelayTimer = [[NSTimer alloc] initWithFireDate:nil interval:0 target:self selector:@selector(fetchData) userInfo:nil repeats:NO];
    }
    return self;
}

-(void) fetchData{
    if(self.fetchAddressSuggestionTask.state == NSURLSessionTaskStateSuspended){
        NSLog(@"Interneting");
        [self.fetchAddressSuggestionTask resume];
    }
    _fetchDelayTimer = [[NSTimer alloc] initWithFireDate:nil interval:0 target:self selector:@selector(fetchData) userInfo:nil repeats:NO];
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
                        address = [address stringByReplacingOccurrencesOfString:@", United States" withString:@""];
                    }

                    [self addToCache:json forPrefix:prefix];

                    return completionHandler(address);
                }
            }];
            
            [self.fetchDelayTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:kFetchDelay]];
            [[NSRunLoop currentRunLoop] addTimer:self.fetchDelayTimer forMode:NSDefaultRunLoopMode];
        }
    }
}
-(BOOL)textFieldShouldReplaceCompletionText:(HTAutocompleteTextField *)textField {
    return YES;
}
- (void) addToCache:(NSDictionary *)predictionsDictionary forPrefix:(NSString *)prefix{
    NSArray *addresses = predictionsDictionary[@"predictions"];
    NSMutableOrderedSet *predictions = self.predictions.mutableCopy;
    for (int i = 0; i < addresses.count; i++) {

        NSDictionary *location = addresses[i];
        NSArray *locationTypes = location[@"types"];
        NSArray *matchedSubstrings = location[@"matched_substrings"];

        if(![locationTypes containsObject:@"street_address"]) break;
        if(![matchedSubstrings containsObject:@{@"length": @(prefix.length), @"offset": @(0)}]) break;

        NSString *title = location[@"description"];
        title = [title stringByReplacingOccurrencesOfString:@", United States" withString:@""];
        NSNumber *rank = @(prefix.length*10 + i);
        [predictions addObject:@{@"title":title, @"rank":rank}];
    }
    NSSortDescriptor *rankSort = [NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES];
    [predictions sortUsingDescriptors:@[rankSort]];
    self.predictions = predictions;
}

- (NSString *)checkLocalForAddress:(NSString *)prefix {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title BEGINSWITH %@", prefix];

    NSOrderedSet *completions = [self.predictions filteredOrderedSetUsingPredicate:predicate];
    if(completions.count > 0 ){
        return completions[0][@"title"];
    }
    return nil;
}

@end
