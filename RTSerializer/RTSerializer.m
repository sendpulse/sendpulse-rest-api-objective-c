//
//  RTSerializer.m
//  RuvixTel
//
//  Created by Hasintha on 3/21/13.
//  Copyright (c) 2013 Tharindu Madushanka. All rights reserved.
//

#import "RTSerializer.h"
@interface RTSerializer(){
    int _pos;
}

@end
@implementation RTSerializer

-(NSString *)serialize:(id)object inString:(NSString *)str{
    if([object isKindOfClass:[NSArray class]]){
        NSArray *a = (NSArray *)object;
        str= [str stringByAppendingFormat:@"a:%lu:{",(unsigned long)[a count]];
        for (int i = 0; i < [a count]; i++){
           str = [self serialize:[NSNumber numberWithInt:i] inString:str];
           str = [self serialize:[a objectAtIndex:i] inString:str];
        }
        str = [str stringByAppendingString:@"}"];
        return str;
    }
    else if([object isKindOfClass:[NSNumber class]]){
        int i = [(NSNumber *)object intValue];
        return [str stringByAppendingFormat:@"i:%d;",i]; 
    }
    else if([object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSMutableDictionary class]]){
        NSDictionary *a = (NSDictionary *)object;
        str= [str stringByAppendingFormat:@"a:%lu:{",(unsigned long)[[a allKeys]count]];
        for (NSString *key in [a allKeys]){
            str = [self serialize:key inString:str];
            str = [self serialize:[a valueForKey:key] inString:str];
        }
        str = [str stringByAppendingFormat:@"}"];
        return str;
    }
    else if([object isKindOfClass:[NSString class]]){
        return [str stringByAppendingFormat:@"s:%lu:\"%@\";",(unsigned long)[(NSString *)object length],(NSString *)object];
    }
    else{
      return str;
    }
}

-(id)deserialize:(NSString *)str{
    if(str == nil || [str length]<=_pos)
        return nil;
    int start,end,length;
    NSString *strLen;
    switch ([str characterAtIndex:_pos]) {
        case 'N':
            break;
        case 's':{
            NSRange starRange=[str rangeOfString:@":" options:0 range:NSMakeRange(_pos, [str length]-_pos)];
            start=starRange.location+1;
            NSRange endRange =[str rangeOfString:@":" options:0 range:NSMakeRange(start, [str length]-start)];
            end=endRange.location;
            strLen = [str substringWithRange:NSMakeRange(start, end-start)];
            int bytelen = strLen.intValue;
            length = bytelen;
            if ((end + 2 + length) >= [str length]) length = [str length] - 2 - end;
            NSString *stRet = [str substringWithRange:NSMakeRange(end+2, length)];
            _pos+=6+strLen.length+length;
            return stRet;
        }
        case 'i':{
            NSString *stInt;
            NSRange starRange=[str rangeOfString:@":" options:0 range:NSMakeRange(_pos, [str length]-_pos)];
            start=starRange.location+1;
            NSRange endRange =[str rangeOfString:@";" options:0 range:NSMakeRange(start, [str length]-start)];
            end=endRange.location;
            stInt = [str substringWithRange:NSMakeRange(start, end -start)];
            _pos += 3 + [stInt length];
            return stInt;
        } 
        case 'a':{
            NSRange starRange=[str rangeOfString:@":" options:0 range:NSMakeRange(_pos, [str length]-_pos)];
            start=starRange.location+1;
            NSRange endRange =[str rangeOfString:@":" options:0 range:NSMakeRange(start, [str length]-start)];
            end=endRange.location;
            strLen=[str substringWithRange:NSMakeRange(start, end-start)];
            length=strLen.intValue;
            NSMutableArray *alRet=[[NSMutableArray alloc]initWithCapacity:length];
            NSMutableDictionary *htRect=[[NSMutableDictionary alloc]initWithCapacity:length];
            _pos+=4+strLen.length;
            for(int i=0;i<length;i++){
                id key=[self deserialize:str];
                id value = [self deserialize:str];
                
                if(alRet != nil){
                    if([key rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound && [key intValue]==alRet.count)                  
                        [alRet addObject:value];
                    else
                        alRet=nil;
                }
                
                [htRect setValue:value forKey:key];
            }
            _pos++;
            if (_pos < [str length] && [str characterAtIndex:_pos] == ';')
                _pos++;
            if (alRet != nil)
                return alRet;
            else
                return htRect;
        }
        
        default:
            return @"";
    }
    return @"";
}


@end
