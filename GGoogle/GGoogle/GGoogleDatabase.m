//
//  GGoogleDatabase.m
//  GGoogle
//
//  Created by Rohan Varma on 9/13/14.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "GGoogleDatabase.h"
#import "PictureRealLife.h"

@implementation GGoogleDatabase;

static GGoogleDatabase *_database;

- (GGoogleDatabase*)retrieveDatabase {
    if (_database == nil) {
        _database = (__bridge sqlite3 *)([[GGoogleDatabase alloc] init]);
    }
    return (__bridge GGoogleDatabase *)(_database);
}

+ (NSArray *)getFirstPoint {
    NSMutableArray *retrieval = [[NSMutableArray alloc] init];
    NSString *query = @"SELECT latitude, longitude, orientation, image, url FROM pictures_in_real_life";
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2((__bridge sqlite3 *)(_database), [query UTF8String], -1, &statement, nil)
        == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            double latitude = sqlite3_column_double(statement, 0);
            double longitude = sqlite3_column_double(statement, 1);
            double orientation = sqlite3_column_double(statement, 2);
            const void *ptr = sqlite3_column_blob(statement, 3);
            int size = sqlite3_column_bytes(statement, 3);
            NSData *image;
            image = [[NSData alloc] initWithBytes:ptr length:size];
            NSString *url;
            char *characterUrl = sqlite3_column_text(statement, 4);
            url = [NSString stringWithUTF8String:characterUrl];
            PictureRealLife *picture = [[PictureRealLife alloc] initPictureRealLife:latitude longitude:longitude orientation:orientation image:image url:url];
            [retrieval addObject:picture];
        }
        sqlite3_finalize(statement);
    }
    return retrieval;
}

+ (void) putPictureInDB:(double)latitude longitude:(double)longitude orientation:(double)orientation image:(NSData *)image {
    
}

- (id)init {
    if ((self = [super init])) {
        NSString *sqLiteDb = [[NSBundle mainBundle] pathForResource:@"GGoogle"
                                                             ofType:@"db"];
        
        if (sqlite3_open([sqLiteDb UTF8String], &_database) != SQLITE_OK) {
            NSLog(@"Failed to open database!");
        }
    }
    return self;
}

@end