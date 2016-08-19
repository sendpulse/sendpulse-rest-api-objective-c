//
//  Sendpulse.m
//  sendpulse-rest-api
//
//  Copyright (c) 2016 sendpulse.com. All rights reserved.
//

#import "Sendpulse.h"
#import <CommonCrypto/CommonDigest.h>
@implementation Sendpulse
@synthesize userId;
@synthesize secret;
@synthesize tokenName;
@synthesize jsonData;
@synthesize acceptedtokenName;
static NSString* apiUrl = @"https://api.sendpulse.com";
static int refreshToken = 0;
static int responsecode = 0;

- (id)initWithUserIdandSecret:(NSString *) _userId :(NSString *) _secret {
    if ( self = [super init] ) {
        if (_userId.length!=0 && _secret.length!=0) {
            userId = _userId;
            secret = _secret;
            d_group = dispatch_group_create();
            bg_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            tokenName = [self md5:[NSString stringWithFormat:@"%@::%@",userId,secret]];
            if( tokenName!=nil && tokenName.length>0) [self getToken];
            return self;
        } else {
            NSLog(@"Empty ID or SECRET");
            return nil;
        }
        

    } else
        return nil;
}
-(NSString *) md5:(NSString *) input{
    const char *cStr = [input UTF8String];
    unsigned char digest[16];
    CC_MD5( cStr, strlen(cStr), digest ); // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return  output;
}
/**
 * Get token and store it
 *
 * @return bool
 */
-(void) getToken {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:@"client_credentials" forKey:@"grant_type"];
    [data setObject:userId forKey:@"client_id"];
    [data setObject:secret forKey:@"client_secret"];
    [self sendrequest:@"oauth/access_token" :@"POST" :data :NO];
}
-(NSString*) geturlstringfromdata:(NSMutableDictionary*) data{
    NSString *url = [[NSString alloc] init];
    int i=0;
    for (NSString* key in data) {
        NSString *item = [data objectForKey:key];
        if(i==0)
            url = [url stringByAppendingString:[NSString stringWithFormat:@"%@=%@",key,item]];
        else
            url = [url stringByAppendingString:[NSString stringWithFormat:@"&%@=%@",key,item]];
        i++;
    }
    return url;
}
-(void) sendrequest:(NSString*)path :(NSString*)method : (NSMutableDictionary*) data :(BOOL) useToken{
    NSString *requestUrl = [NSString stringWithFormat:@"%@/%@",apiUrl,path];
    NSString *postpatams = @"";
    if(data!=nil) postpatams = [self geturlstringfromdata:data];
    if([[method uppercaseString] isEqualToString:@"GET"] && [postpatams length]>0)
        requestUrl = [NSString stringWithFormat:@"%@?%@",requestUrl,postpatams];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0];
    if(useToken && tokenName!=nil && refreshToken==0) {
       if(acceptedtokenName!=nil)
           [request setValue:[NSString stringWithFormat:@"Bearer %@",tokenName] forHTTPHeaderField:@"Authorization"];
       else{
           dispatch_group_notify(d_group, dispatch_get_main_queue(), ^{
               [self sendrequest:path :method :data :useToken];
           });
           return;
       }
    }
    request.HTTPMethod = [method uppercaseString];
    if([[method uppercaseString] isEqualToString:@"PUT"] || [[method uppercaseString] isEqualToString:@"DELETE"]){
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    if(![[method uppercaseString] isEqualToString:@"GET"])
        request.HTTPBody = [postpatams dataUsingEncoding:NSUTF8StringEncoding];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (connection) {
        jsonData = [NSMutableData data];
    }
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [jsonData setLength:0];
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    responsecode = [httpResponse statusCode];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{[jsonData appendData:data];}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
   NSLog( @"Could not connect to api, check your ID and SECRET %d",responsecode );
    NSString *dataString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"%@",dataString);
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (responsecode == 401 && refreshToken == 0){
        [connection cancel];
        refreshToken += 1;
        [self getToken];
        [connection start];
    }else if (responsecode!=200 && refreshToken>0){
        [self handleError:@"Could not connect to api, check your ID and SECRET"];
    }else{
        [self getResults:connection];
    }
}
-(void) getResults:(NSURLConnection *)connection{
    NSMutableURLRequest* request = [connection currentRequest];
    NSString *requestpath = [[request URL] absoluteString];
    NSString *dataString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    SBJsonParser *jsonParser = [[SBJsonParser alloc] init];
    NSArray *jsonObjects = [jsonParser objectWithString:dataString];
    if([requestpath rangeOfString:@"oauth/access_token"].location != NSNotFound){
        if(responsecode!=200 && refreshToken>0)
            [self handleError:@"Could not connect to api, check your ID and SECRET"];
        else{
            refreshToken = 0;
            if([jsonObjects count]>0){
                tokenName = [jsonObjects valueForKey:@"access_token"];
                acceptedtokenName = tokenName;
            }
        }
    }else{
        NSMutableDictionary* resultdata = [[NSMutableDictionary alloc] init];
        [resultdata setValue:[NSString stringWithFormat:@"%d",responsecode] forKey:@"http_code"];
        if([jsonObjects count]>0){
            [resultdata setValue:jsonObjects forKey:@"data"];
        }else{
            [resultdata setValue:nil forKey:@"data"];
        }
        if(responsecode!=200) [resultdata setValue:@"1" forKey:@"is_error"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SendPulseNotification" object:nil userInfo:@{@"SendPulseData" : resultdata}];
    }
}
-(void) handleError:(NSString*) message{
    NSMutableDictionary* resultdata = [[NSMutableDictionary alloc] init];
    [resultdata setValue:message forKey:@"message"];
    [resultdata setValue:@"1" forKey:@"is_error"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SendPulseNotification" object:nil userInfo:@{@"SendPulseData" : resultdata}];
}
/**
 * Create new address book
 *
 * @param NSString bookName
 */
-(void) createAddressBook:(NSString*) bookName {
    if([bookName length]==0){
        [self handleError:@"Empty book name"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:bookName forKey:@"bookName"];
    [self sendrequest:@"addressbooks" :@"POST" :data :YES];
}

/**
 * Edit address book name
 *
 * @param int bookId
 * @param NSString newName
 */
-(void) editAddressBook:(int) bookId :(NSString*) newname{
    if([newname length]==0 || bookId<=0){
        [self handleError:@"Empty new name or book id"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:newname forKey:@"name"];
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d",bookId] :@"PUT" :data :YES];
}

/**
 * Remove address book
 *
 * @param int bookId
 */
-(void) removeAddressBook:(int) bookId{
    if(bookId<=0){
        [self handleError:@"Empty book id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d",bookId] :@"DELETE" :nil :YES];
}

/**
 * Get list of address books
 *
 * @param int limit
 * @param int offset
 */
-(void) listAddressBooks:(int) limit :(int) offset{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[NSString stringWithFormat:@"%d",limit] forKey:@"limit"];
    [data setObject:[NSString stringWithFormat:@"%d",offset] forKey:@"offset"];
    [self sendrequest:@"addressbooks" :@"GET" :data :YES];
}

/**
 * Get book info
 *
 * @param int bookId
 */
-(void) getBookInfo:(int) bookId{
    if(bookId<=0) {
        [self handleError:@"Empty book id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d",bookId] :@"GET" :nil :YES];
}

/**
 * Get list pf emails from book
 *
 * @param int bookId
 */
-(void) getEmailsFromBook:(int) bookId{
    if(bookId<=0) {
        [self handleError:@"Empty book id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d/emails",bookId] :@"GET" :nil :YES];
}

/**
 * Add new emails to book
 *
 * @param int bookId
 * @param int emails
 */
-(void) addEmails:(int) bookId :(NSString*) emails{
    if(bookId<=0 || [emails length]==0){
        [self handleError:@"Empty book id or emails"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:emails forKey:@"emails"];
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d/emails",bookId] :@"POST" :data :YES];
}

/**
 * Remove emails from book
 *
 * @param int bookId
 * @param int emails
 */
-(void) removeEmails:(int) bookId : (NSString*) emails{
    if(bookId<=0 || [emails length]==0){
        [self handleError:@"Empty book id or emails"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:emails forKey:@"emails"];
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d/emails",bookId] :@"DELETE" :data :YES];
}

/**
 * Get information about email from book
 *
 * @param int bookId
 * @param int email
 */
-(void) getEmailInfo:(int) bookId :(NSString*) email{
    if(bookId<=0 || [email length]==0){
        [self handleError:@"Empty book id or email"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d/emails/%@",bookId,email] :@"GET" :nil :YES];
}

/**
 * Calculate cost of the campaign based on address book
 *
 * @param int bookId
 */
-(void) campaignCost:(int) bookId{
    if(bookId<=0){
        [self handleError:@"Empty book id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"addressbooks/%d/cost",bookId] :@"GET" :nil :YES];
}

/**
 * Get list of campaigns
 *
 * @param int limit
 * @param int offset
 */
-(void) listCampaigns:(int) limit :(int) offset{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[NSString stringWithFormat:@"%d",limit] forKey:@"limit"];
    [data setObject:[NSString stringWithFormat:@"%d",offset] forKey:@"offset"];
    [self sendrequest:@"campaigns" :@"GET" :data :YES];
}

/**
 * Get information about campaign
 *
 * @param int camaignId
 */
-(void) getCampaignInfo:(int) camaignId {
    if(camaignId<=0){
        [self handleError:@"Empty campaign id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"campaigns/%d",camaignId] :@"GET" :nil :YES];
}

/**
 * Get campaign statistic by countries
 *
 * @param int camaignId
 */
-(void) campaignStatByCountries:(int) camaignId {
    if(camaignId<=0){
        [self handleError:@"Empty campaign id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"campaigns/%d/countries",camaignId] :@"GET" :nil :YES];
}

/**
 * Get campaign statistic by referrals
 *
 * @param int camaignId
 */
-(void) campaignStatByReferrals:(int) camaignId {
    if(camaignId<=0){
        [self handleError:@"Empty campaign id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"campaigns/%d/referrals",camaignId] :@"GET" :nil :YES];
}

/**
 * Create new campaign
 *
 * @param NSString senderName
 * @param NSString senderEmail
 * @param NSString subject
 * @param NSString body
 * @param NSString bookId
 * @param NSString name
 * @param NSString attachments
 */
-(void) createCampaign:(NSString*) senderName  :(NSString*) senderEmail  :(NSString*) subject :(NSString*) body :(int) bookId  :(NSString*) name  :(NSString*) attachments{
    if( [senderName length]==0 || [senderEmail length]==0 || [subject length]==0 || [body length]==0 || bookId<=0 ){
        [self handleError:@"Not all data."];
        return;
    }
    NSData *plainData = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString * encodedbody = [plainData base64EncodedStringWithOptions:0];
    encodedbody = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)encodedbody,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8 ));
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    if([attachments length]>0) [data setObject:attachments forKey:@"attachments"];
    [data setObject:senderName forKey:@"sender_name"];
    [data setObject:senderEmail forKey:@"sender_email"];
    [data setObject:attachments forKey:@"attachments"];
    [data setObject:subject forKey:@"subject"];
    [data setObject:[NSString stringWithFormat:@"%d",bookId] forKey:@"list_id"];
    if([encodedbody length]>0) [data setObject:[NSString stringWithFormat:@"%@",encodedbody] forKey:@"body"];
    [data setObject:name forKey:@"name"];
    [self sendrequest:@"campaigns" :@"POST" :data :YES];
}

/**
 * Cancel campaign
 *
 * @param int id
 */
-(void) cancelCampaign:(int) camaignId {
    if(camaignId<=0){
        [self handleError:@"Empty campaign id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"campaigns/%d",camaignId] :@"DELETE" :nil :YES];
}

/**
 * Get list of allowed senders
 */
-(void) listSenders{
    [self sendrequest:@"senders" :@"GET" :nil :YES];
}

/**
 * Add new sender
 *
 * @param NSString senderName
 * @param NSString senderEmail
 */
-(void) addSender:(NSString*) senderName :(NSString*) senderEmail{
    if([senderName length]==0 || [senderEmail length]==0){
        [self handleError:@"Empty sender name or email"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:senderName forKey:@"name"];
    [data setObject:senderEmail forKey:@"email"];
    [self sendrequest:@"senders" :@"POST" :data :YES];
}

/**
 * Remove sender
 *
 * @param NSString email
 */
-(void) removeSender:(NSString*) email{
    if([email length]==0){
        [self handleError:@"Empty email"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:email forKey:@"email"];
    [self sendrequest:@"senders" :@"DELETE" :data :YES];
}

/**
 * Activate sender using code from mail
 *
 * @param NSString email
 * @param NSString code
 */
-(void) activateSender:(NSString*) email :(NSString*) code{
    if([email length]==0 || [code length]==0){
        [self handleError:@"Empty email or activation code"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:code forKey:@"code"];
    [self sendrequest:[NSString stringWithFormat:@"senders/%@/code",email] :@"POST" :data :YES];
}

/**
 * Send mail with activation code on sender email
 *
 * @param NSString email
 */
-(void) getSenderActivationMail:(NSString*) email{
    if([email length]==0){
        [self handleError:@"Empty email"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"senders/%@/code",email] :@"GET" :nil :YES];
}

/**
 * Get global information about email
 *
 * @param NSString email
 */
-(void) getEmailGlobalInfo:(NSString*) email{
    if([email length]==0){
        [self handleError:@"Empty email"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"emails/%@",email] :@"GET" :nil :YES];
}

/**
 * Remove email address from all books
 *
 * @param NSString email
 */
-(void) removeEmailFromAllBooks:(NSString*) email{
    if([email length]==0){
        [self handleError:@"Empty email"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"emails/%@",email] :@"DELETE" :nil :YES];
}

/**
 * Get statistic for email by all campaigns
 *
 * @param NSString email
 */
-(void) emailStatByCampaigns:(NSString*) email{
    if([email length]==0){
        [self handleError:@"Empty email"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"emails/%@/campaigns",email] :@"GET" :nil :YES];
}

/**
 * Show emails from blacklist
 */
-(void) getBlackList{
    [self sendrequest:@"blacklist" :@"GET" :nil :YES];
}

/**
 * Add email address to blacklist
 *
 * @param NSString emails
 */
-(void) addToBlackList:(NSString*) emails{
    if([emails length]==0){
        [self handleError:@"Empty emails"];
        return;
    }
    NSData *plainData = [emails dataUsingEncoding:NSUTF8StringEncoding];
    NSString * encodedemails = [plainData base64EncodedStringWithOptions:0];
    encodedemails = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)encodedemails,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8 ));
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:encodedemails forKey:@"emails"];
    [self sendrequest:@"blacklist" :@"POST" :data :YES];
}

/**
 * Remove email address from blacklist
 *
 * @param NSString emails
 */
-(void) removeFromBlackList:(NSString*) emails{
    if([emails length]==0){
        [self handleError:@"Empty emails"];
        return;
    }
    NSData *plainData = [emails dataUsingEncoding:NSUTF8StringEncoding];
    NSString * encodedemails = [plainData base64EncodedStringWithOptions:0];
    encodedemails = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)encodedemails,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8 ));
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:encodedemails forKey:@"emails"];
    [self sendrequest:@"blacklist" :@"DELETE" :data :YES];
}

/**
 * Return user balance
 *
 * @param NSString currency
 */
-(void) getBalance:(NSString*) currency{
    NSString* url = @"balance";
    if([currency length]>0){
        currency = [currency uppercaseString];
        url = [NSString stringWithFormat:@"%@/%@",url,currency];
    }
    [self sendrequest:url :@"GET" :nil :YES];
}

/**
 * Get list of emails that was sent by SMTP
 *
 * @param int limit
 * @param int offset
 * @param NSString fromDate
 * @param NSString toDate
 * @param NSString sender
 * @param NSString recipient
 */
-(void) smtpListEmails:(int) limit :(int) offset :(NSString*) fromDate :(NSString*) toDate :(NSString*) sender :(NSString*) recipient{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[NSString stringWithFormat:@"%d",limit] forKey:@"limit"];
    [data setObject:[NSString stringWithFormat:@"%d",offset] forKey:@"offset"];
    if([fromDate length]>0) [data setObject:fromDate forKey:@"fromDate"];
    if([toDate length]>0) [data setObject:toDate forKey:@"toDate"];
    if([sender length]>0) [data setObject:sender forKey:@"sender"];
    if([recipient length]>0) [data setObject:recipient forKey:@"recipient"];
    [self sendrequest:@"smtp/emails" :@"GET" :data :YES];
}
/**
 * Get information about email by his id
 *
 * @param NSString emailId
 */
-(void) smtpGetEmailInfoById:(NSString*) emailId{
    if([emailId length]==0){
        [self handleError:@"Empty id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"smtp/emails/%@",emailId] :@"GET" :nil :YES];
}

/**
 * Unsubscribe emails using SMTP
 *
 * @param NSString emails
 */
-(void) smtpUnsubscribeEmails:(NSString*) emails {
    if([emails length]==0){
        [self handleError:@"Empty emails"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:emails forKey:@"emails"];
    [self sendrequest:@"smtp/unsubscribe" :@"POST" :data :YES];
}

/**
 * Remove emails from unsubscribe list using SMTP
 *
 * @param NSString emails
 */
-(void) smtpRemoveFromUnsubscribe:(NSString*) emails {
    if([emails length]==0){
        [self handleError:@"Empty emails"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:emails forKey:@"emails"];
    [self sendrequest:@"smtp/unsubscribe" :@"DELETE" :data :YES];
}

/**
 * Get list of allowed IPs using SMTP
 */
-(void) smtpListIP{
    [self sendrequest:@"smtp/ips" :@"GET" :nil :YES];
}

/**
 * Get list of allowed domains using SMTP
 */
-(void) smtpListAllowedDomains{
    [self sendrequest:@"smtp/domains" :@"GET" :nil :YES];
}

/**
 * Add domain using SMTP
 *
 * @param NSString email
 */
-(void) smtpAddDomain:(NSString*) email{
    if([email length]==0){
        [self handleError:@"Empty email"];
        return;
    }
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:email forKey:@"email"];
    [self sendrequest:@"smtp/domains" :@"POST" :data :YES];
}

/**
 * Send confirm mail to verify new domain
 *
 * @param NSString email
 */
-(void) smtpVerifyDomain:(NSString*) email{
    if([email length]==0){
        [self handleError:@"Empty email"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"smtp/domains/%@",email] :@"GET" :nil :YES];
}

/**
 * Send mail using SMTP
 *
 * @param NSString email
 */
-(void) smtpSendMail:(NSMutableDictionary*) emaildata{
    RTSerializer *serializer = [[RTSerializer alloc]init];
    if([emaildata count]==0){
        [self handleError:@"Empty email data"];
        return;
    }
    NSString *html = [emaildata valueForKey:@"html"];
    NSData *plainData = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSString * encodedhtml = [plainData base64EncodedStringWithOptions:0];
    [emaildata setValue:encodedhtml forKey:@"html"];
    NSString *sdata = @"";
    sdata = [serializer  serialize:emaildata inString:sdata];
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    sdata = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)sdata,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8 ));
    [data setObject:sdata forKey:@"email"];
    [self sendrequest:@"smtp/emails" :@"POST" :data :YES];
}
/**
 * Get list of push campaigns
 * @param int limit
 * @param int offset
 */
-(void) pushListCampaigns:(int) limit :(int) offset {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[NSString stringWithFormat:@"%d",limit] forKey:@"limit"];
    [data setObject:[NSString stringWithFormat:@"%d",offset] forKey:@"offset"];
    [self sendrequest:@"push/tasks" :@"GET" :data :YES];
}
/**
 * Get push campaigns info
 *
 * @param NSString taskID
 */
-(void) pushCampaignInfo:(NSString*) taskID{
    if([taskID length]==0){
        [self handleError:@"Empty id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"push/tasks/%@",taskID] :@"GET" :nil :YES];
}
/**
 * Get amount of websites
 */
-(void) pushCountWebsites{
    [self sendrequest:@"push/websites/total" :@"GET" :nil :YES];
}
/**
 Get list of websites
 * @param int limit
 * @param int offset
 */
-(void) pushListWebsites:(int) limit :(int) offset {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[NSString stringWithFormat:@"%d",limit] forKey:@"limit"];
    [data setObject:[NSString stringWithFormat:@"%d",offset] forKey:@"offset"];
    [self sendrequest:@"push/websites" :@"GET" :data :YES];
}
/**
 * Get list of all variables for website
 *
 * @param NSString siteId
 */
-(void) pushListWebsiteVariables:(NSString*) siteId{
    if([siteId length]==0){
        [self handleError:@"Empty id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"push/websites/%@/variables",siteId] :@"GET" :nil :YES];
}

/**
 * Get list of subscriptions for the website
 *
 * @param NSString siteId
 * @param int limit
 * @param int offset
 */
-(void) pushListWebsiteSubscriptions:(NSString*) siteId :(int) limit :(int) offset{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:[NSString stringWithFormat:@"%d",limit] forKey:@"limit"];
    [data setObject:[NSString stringWithFormat:@"%d",offset] forKey:@"offset"];
    if([siteId length]==0){
        [self handleError:@"Empty id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"push/websites/%@/subscriptions",siteId] :@"GET" :data :YES];
}

/**
 * Get amount of subscriptions for the site
 *
 * @param NSString siteId
 */
-(void) pushCountWebsiteSubscriptions:(NSString*) siteId{
    if([siteId length]==0){
        [self handleError:@"Empty id"];
        return;
    }
    [self sendrequest:[NSString stringWithFormat:@"push/websites/%@/subscriptions/total",siteId] :@"GET" :nil :YES];
}

/**
 * Set state for subscription
 *
 * @param NSString subscriptionId
 * @param int state
 */
-(void) pushSetSubscriptionState:(NSString*) subscriptionId :(int) state {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    if([subscriptionId length]==0){
        [self handleError:@"Empty id"];
        return;
    }
    [data setObject:[NSString stringWithFormat:@"%@",subscriptionId] forKey:@"id"];
    [data setObject:[NSString stringWithFormat:@"%d",state] forKey:@"state"];
    [self sendrequest:@"push/subscriptions/state" :@"POST" :data :YES];
}
/**
 * Create new push campaign
 * @param NSMutableDictionary taskInfo
 * @param NSMutableDictionary additionalParams
 */
-(void) createPushTask:(NSMutableDictionary*) taskInfo :(NSMutableDictionary*) additionalParams{
    if([taskInfo valueForKey:@"ttl"]==nil){
        [taskInfo setValue:@"0" forKey:@"ttl"];
    }
    if([taskInfo valueForKey:@"title"]==nil || [taskInfo valueForKey:@"website_id"]==nil || [taskInfo valueForKey:@"body"]==nil){
        [self handleError:@"Not all data"];
        return;
    }
    if(additionalParams !=nil && [additionalParams count]>0){
        [taskInfo addEntriesFromDictionary:additionalParams];
    }
    [self sendrequest:@"/push/tasks" :@"POST" :taskInfo :YES];
}

@end
