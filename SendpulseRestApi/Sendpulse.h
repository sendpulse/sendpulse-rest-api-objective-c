//
//  Sendpulse.h
//  ;
//
//  Copyright (c) 2016 sendpulse.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBJson.h"
#import "RTSerializer.h"
@interface Sendpulse : NSObject{
    dispatch_group_t d_group;
    dispatch_queue_t bg_queue;
}
@property (nonatomic, retain) NSMutableData *jsonData;
@property (strong,nonatomic) NSString *userId;
@property (strong,nonatomic) NSString *secret;
@property (strong,nonatomic) NSString *tokenName;
@property (strong,nonatomic) NSString *acceptedtokenName;
-(id) initWithUserIdandSecret:(NSString *) _userId :(NSString *) _secret;
-(void) createAddressBook:(NSString*) bookName;
-(void) listAddressBooks:(int) limit :(int) offset;
-(void) getBookInfo:(int) bookId;
-(void) editAddressBook:(int) bookId :(NSString*) newname;
-(void) removeAddressBook:(int) bookId;
-(void) getEmailsFromBook:(int) bookId;
-(void) addEmails:(int) bookId :(NSString*) emails;
-(void) removeEmails:(int) bookId : (NSString*) emails;
-(void) getEmailInfo:(int) bookId :(NSString*) email;
-(void) campaignCost:(int) bookId;
-(void) listCampaigns:(int) limit :(int) offset;
-(void) getCampaignInfo:(int) camaignId;
-(void) campaignStatByCountries:(int) camaignId;
-(void) campaignStatByReferrals:(int) camaignId;
-(void) createCampaign:(NSString*) senderName  :(NSString*) senderEmail  :(NSString*) subject :(NSString*) body :(int) bookId  :(NSString*) name  :(NSString*) attachments;
-(void) cancelCampaign:(int) camaignId;
-(void) listSenders;
-(void) addSender:(NSString*) senderName :(NSString*) senderEmail;
-(void) removeSender:(NSString*) email;
-(void) activateSender:(NSString*) email :(NSString*) code;
-(void) getSenderActivationMail:(NSString*) email;
-(void) getEmailGlobalInfo:(NSString*) email;
-(void) removeEmailFromAllBooks:(NSString*) email;
-(void) emailStatByCampaigns:(NSString*) email;
-(void) getBlackList;
-(void) addToBlackList:(NSString*) emails;
-(void) removeFromBlackList:(NSString*) emails;
-(void) getBalance:(NSString*) currency;
-(void) smtpListEmails:(int) limit :(int) offset :(NSString*) fromDate :(NSString*) toDate :(NSString*) sender :(NSString*) recipient;
-(void) smtpGetEmailInfoById:(NSString*) emailId;
-(void) smtpUnsubscribeEmails:(NSString*) emails;
-(void) smtpRemoveFromUnsubscribe:(NSString*) emails;
-(void) smtpListIP;
-(void) smtpListAllowedDomains;
-(void) smtpAddDomain:(NSString*) email;
-(void) smtpVerifyDomain:(NSString*) email;
-(void) smtpSendMail:(NSMutableDictionary*) emaildata;
-(void) pushListCampaigns:(int) limit :(int) offset;
-(void) pushCampaignInfo:(NSString*) taskID;
-(void) pushCountWebsites;
-(void) pushListWebsites:(int) limit :(int) offset;
-(void) pushListWebsiteVariables:(NSString*) siteId;
-(void) pushListWebsiteSubscriptions:(NSString*) siteId :(int) limit :(int) offset;
-(void) pushCountWebsiteSubscriptions:(NSString*) siteId;
-(void) pushSetSubscriptionState:(NSString*) subscriptionId :(int) state;
-(void) createPushTask:(NSMutableDictionary*) taskInfo :(NSMutableDictionary*) additionalParams;
@end
