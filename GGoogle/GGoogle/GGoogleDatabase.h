//
//  GGoogleDatabase.h
//  GGoogle
//
//  Created by Rohan Varma on 9/13/14.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface GGoogleDatabase : NSObject {
    sqlite3 *_database;
}

+ (GGoogleDatabase*)retrieveDatabase;
+ (void) putPictureInDB:(double)latitude longitude:(double)longitude orientation:(double)orientation image:(NSData *)image url:(NSString *)theUrl;
- (NSArray *)getFirstPoint;

@end