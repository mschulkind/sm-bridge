#import <PhoneGap/PGPlugin.h>

#import "ASIHTTPRequest.h"

@interface HTTPPlugin : PGPlugin <ASIHTTPRequestDelegate> {
 @private
  // Maps requestID -> HTTPRequestMetadata (see HTTPPlugin.m).
  NSMutableDictionary* requestMap_;
}

@property (nonatomic, retain) NSMutableDictionary* requestMap;

@end
