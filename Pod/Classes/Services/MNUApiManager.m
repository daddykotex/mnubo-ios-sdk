//
//  MNUApiManager.m
//  APIv3
//
//  Created by Guillaume on 2015-10-18.
//  Copyright © 2015 mnubo. All rights reserved.
//

#import "MNUApiManager.h"
#import "MNUHTTPClient.h"
#import "NSString+mnubo.h"
#import "MNUConstants.h"
#import "PDKeychainBindings.h"
#import "MNUAccessToken.h"



@interface MNUApiManager()

@property (nonatomic, strong) NSString *clientId;
@property (nonatomic, strong) NSString *baseURL;

@property (nonatomic, strong) MNUAccessToken *accessToken;

@end

@implementation MNUApiManager


- (instancetype)initWithClientId:(NSString *)clientId andHostname:(NSString *)hostname {
    self = [super init];
    if (self) {
        _clientId = clientId;
        _baseURL = hostname;

        _accessToken = [[MNUAccessToken alloc] init];
    }
    return self;
}


// Private

- (void)getUserAccessTokenWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(NSError *error))completion {
    
    
    NSDictionary *headers = @{ @"Content-Type": @"application/x-www-form-urlencoded"};
    NSDictionary *parameters = @{ @"grant_type": @"password", @"client_id": _clientId, @"username": username, @"password": password};
    
    NSString *url = [NSString stringWithFormat:@"%@%@", _baseURL, kTokenPath];
    
    [MNUHTTPClient POST:url headers:headers parameters:parameters body:nil completion:^(id data, NSDictionary *responsesHeaderFields, NSError *error) {
        
         if(!error && [data isKindOfClass:[NSDictionary class]]) {
             NSDictionary *jsonData = data;
             
             _accessToken = [[MNUAccessToken alloc] initWithDictionary:jsonData];
             
             NSLog(@"User tokens fetched successfully with username/password");
         } else {
             
             NSLog(@"An error occured while fetching the user tokens with username/password...");
         }
        
         if(completion) completion(error);
     }];
}


- (void)getUserAccessTokenWithRefreshTokenCompletion:(void (^)(NSError *error))completion {
    
    NSDictionary *headers = @{ @"Content-Type": @"application/x-www-form-urlencoded"};
    //TODO Should validate if refreshtoken is not nil
    NSDictionary *parameters = @{ @"grant_type": @"refresh_token", @"client_id": _clientId, @"refresh_token": _accessToken.refreshToken};
    
    NSString *url = [NSString stringWithFormat:@"%@%@", _baseURL, kTokenPath];

    [MNUHTTPClient POST:url headers:headers parameters:parameters body:nil completion:^(id data, NSDictionary *responsesHeaderFields, NSError *error)
     {
         if(!error && [data isKindOfClass:[NSDictionary class]]) {
             NSDictionary *jsonData = data;
             
             _accessToken = [[MNUAccessToken alloc] initWithDictionary:jsonData];
             
             NSLog(@"User tokens fetched successfully with refresh token");
         } else {
             //Refresh Token expired
             //TODO Logout the user and redirect to login view
             [[NSNotificationCenter defaultCenter] postNotificationName:kMnuboLoginExpiredKey object:nil];
             
             NSLog(@"An error occured while fetching the user tokens with refresh token...");
         }
         if(completion) completion(error);
     }];
}


- (void)postWithPath:(NSString *)path body:(NSDictionary *)body completion:(void (^)(NSDictionary *data, NSError *error))completion {
    
    if (![_accessToken isValid]) {
        
        [self getUserAccessTokenWithRefreshTokenCompletion:^(NSError *error) {
            
            if (error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"Access Token Invalid, Logout" object:nil];

                if (completion) completion(nil, error);
            } else {
            
                [self postWithPath:path body:body completion:completion];
            }
        }];
    } else {
        
        NSDictionary *headers = @{@"Content-Type": @"application/json", @"Authorization": [NSString stringWithFormat:@"Bearer %@", _accessToken.accessToken]};
        NSString *url = [NSString stringWithFormat:@"%@%@", _baseURL, path];
        
        [MNUHTTPClient POST:url headers:headers parameters:nil body:body completion:^(id data, NSDictionary *responsesHeaderFields, NSError *error) {
            if(!error && [data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *jsonData = data;
                if (completion) completion(jsonData, error);
            } else {
                if (completion) completion(nil, error);
            }
            
        }];
    }
}

- (void)putWithPath:(NSString *)path body:(NSDictionary *)body completion:(void (^)(NSError *error))completion {
    
    if (![_accessToken isValid]) {
        
        [self getUserAccessTokenWithRefreshTokenCompletion:^(NSError *error) {
            
            if (error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"Access Token Invalid, Logout" object:nil];
                
                if (completion) completion(error);
            } else {
                
                [self putWithPath:path body:body completion:completion];
            }
        }];
    } else {
        
        NSDictionary *headers = @{@"Content-Type": @"application/json", @"Authorization": [NSString stringWithFormat:@"Bearer %@", _accessToken.accessToken]};
        NSString *url = [NSString stringWithFormat:@"%@%@", _baseURL, path];
        
        [MNUHTTPClient PUT:url headers:headers parameters:nil body:body completion:^(id data, NSDictionary *responsesHeaderFields, NSError *error) {
            if (completion) completion(error);
        }];
    }
}

- (BOOL)isUserAccessTokenPresent {
    if (_accessToken.accessToken) {
        return YES;
    } else {
        return NO;
    }
}

- (void)removeTokens {
    [_accessToken removeTokens];
}

//------------------------------------------------------------------------------
#pragma mark Helper methods
//------------------------------------------------------------------------------

- (NSDictionary *)generateAuthHeader:(NSString *)accessToken {
    return @{ @"Authorization" : [NSString stringWithFormat:@"Bearer %@", accessToken] };
}


@end
