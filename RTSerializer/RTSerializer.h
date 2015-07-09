//
//  RTSerializer.h
//  RuvixTel
//
//  Created by Hasintha on 3/21/13.
//  Copyright (c) 2013 Tharindu Madushanka. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RTSerializer : NSObject

-(id)deserialize:(NSString *)str;
-(NSString *)serialize:(id)object inString:(NSString *)str;
@end
