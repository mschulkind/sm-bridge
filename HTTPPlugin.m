#import "HTTPPlugin.h"

#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"

@interface HTTPRequestMetadata : NSObject {
 @private
  ASIHTTPRequest* request_;
  NSString* callbackID_;
}

@property (nonatomic, retain) ASIHTTPRequest* request;
@property (nonatomic, retain) NSString* callbackID;

@end

@implementation HTTPRequestMetadata

@synthesize request = request_;
@synthesize callbackID = callbackID_;

- (id)initWithRequest:(id)request
           callbackID:(NSString*)callbackID
{
  if ((self = [super init])) {
    self.request = request;
    self.callbackID = callbackID;
  }
  return self;
}

- (void)dealloc
{
  self.request = nil;
  self.callbackID = nil;
  [super dealloc];
}

@end

@implementation HTTPPlugin

@synthesize requestMap = requestMap_;

- (id)initWithWebView:(UIWebView*)webView
{
  if ((self = [super initWithWebView:webView])) {
    self.requestMap = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)dealloc
{
  self.requestMap = nil;
  [super dealloc];
}

- (void)fetch:(NSMutableArray*)arguments
     withDict:(NSMutableDictionary*)options
{
  NSString* requestID = [options objectForKey:@"requestID"];
  assert(requestID);
  NSString* url = [options objectForKey:@"url"];
  assert(url);
  NSString* verb = [options objectForKey:@"verb"];
  assert(verb);
  NSDictionary* params = [options objectForKey:@"params"];
  NSDictionary* data = [options objectForKey:@"data"];
  NSNumber* timeout = [options objectForKey:@"timeout"];

  // Construct the full query by adding the query string.
  NSMutableString* fullURL =
      [[[NSMutableString alloc] initWithString:url] autorelease];
  if ([params isKindOfClass:[NSDictionary class]] && [params count] > 0) {
    [fullURL appendString:@"?"];

    __block BOOL firstParam = YES;
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
      assert([key isKindOfClass:[NSString class]]);
      assert([value isKindOfClass:[NSString class]]);

      if (firstParam) {
        firstParam = NO;
      } else {
        [fullURL appendString:@"&"];
      }

      [fullURL appendFormat:@"%@=%@",
        [key stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding],
        [value 
            stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
    }];
  }
  NSURL* nsurl = [NSURL URLWithString:fullURL];
  assert(nsurl);

  // Create the request.
  ASIHTTPRequest* request;
  if ([data isKindOfClass:[NSDictionary class]]) {
    ASIFormDataRequest* dataRequest = [ASIFormDataRequest requestWithURL:nsurl];

    // Add any form data.
    [data enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
      [dataRequest addPostValue:value forKey:key];
    }];

    request = dataRequest;
  } else {
    request = [ASIHTTPRequest requestWithURL:nsurl];
  }

  // Register the request and save the metadata in the request's userInfo..
  assert([requestMap_ objectForKey:requestID] == nil);
  NSString* callbackID = [arguments objectAtIndex:0];
  HTTPRequestMetadata* metadata = 
      [[[HTTPRequestMetadata alloc] initWithRequest:request 
                                         callbackID:callbackID] autorelease];
  [requestMap_ setObject:metadata forKey:requestID];
  request.userInfo = 
      [NSDictionary dictionaryWithObject:metadata forKey:@"metadata"];

  // Setup the rest of the request.
  request.delegate = self;
  request.requestMethod = verb;
  if (timeout) {
    request.timeOutSeconds = [timeout intValue] / 1000.0;
  }

  // Finally, fire it off.
  [request startAsynchronous];
}

- (void)handleResponse:(ASIHTTPRequest*)request
             completed:(BOOL)completed
{
  HTTPRequestMetadata* metadata = [request.userInfo objectForKey:@"metadata"];
  assert(metadata);

  NSMutableDictionary* responseDict = [NSMutableDictionary dictionary];

  BOOL success = completed;
  if (completed) {
    [responseDict setObject:request.responseString forKey:@"data"];

    if (request.responseStatusCode != 200) {
      // Even though the request completed, it's still an error since we didn't
      // get back a 200.
      success = NO;

      // Include the status code for non-200.
      [responseDict 
          setObject:[NSNumber numberWithInt:request.responseStatusCode]
             forKey:@"statusCode"];
    }
  }
  PluginResult* result =
      [PluginResult 
          resultWithStatus: (success ? PGCommandStatus_OK 
                                     : PGCommandStatus_ERROR)
          messageAsDictionary:responseDict];
  NSString* javascript;
  if (success) {
    javascript = [result toSuccessCallbackString:metadata.callbackID];
  } else {
    javascript = [result toErrorCallbackString:metadata.callbackID];
  }
  [self writeJavascript:javascript];
}

- (void)requestFinished:(ASIHTTPRequest *)request
{
  [self handleResponse:request completed:YES];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
  [self handleResponse:request completed:NO];
}

- (void)abort:(NSMutableArray*)arguments
     withDict:(NSMutableDictionary*)options
{
  NSString* requestID = [options objectForKey:@"requestID"];
  assert(requestID);

  HTTPRequestMetadata* metadata = [requestMap_ objectForKey:requestID];
  assert(metadata);

  [metadata.request clearDelegatesAndCancel];
  [requestMap_ removeObjectForKey:requestID];
}

@end
