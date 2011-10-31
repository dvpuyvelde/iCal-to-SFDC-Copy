//
//  Utils.h
//  Activity Tracker
//
//  Created by David Van Puyvelde on 18/06/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Utils : NSObject {
    
}

+(NSString*)formatDateAsString:(NSDate*)date;
+(NSDate*)startOfWeek;
+(NSDate*)endOfWeek;
+(NSString*)startOfWeekAsString;
+(NSString*)endOfWeekAsString;
+(NSDate*)addOneWeek:(NSDate*)date;
+(NSDate*)substractOneWeek:(NSDate*)date;
+(NSDate*)dateFromString:(NSString*)str;
+(NSString*)dayDescriptionFromDate:(NSDate*)date;
+(NSString*)descriptionFromString:(NSString*)datestring;

@end
