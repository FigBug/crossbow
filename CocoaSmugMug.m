/*

CocoaSmugMug.m

The MIT License

Copyright (c)  2007-2008 Chris Beauvois

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/


#if MAC_OS_X_VERSION_10_4 <= MAC_OS_X_VERSION_MAX_ALLOWED

#define SMUGMUG_API_VERSION					@"1.2.0"
#define SMUGMUG_UPLOAD_URL					@"upload.smugmug.com/"


#import "CocoaSmugMug.h"
#import <openssl/md5.h>


@interface CocoaSmugMug(Private)
- (void)checkSession;
- (void)clearSession;
- (SmugMugResponse *)_login:(NSString *)loginString 
						   :(NSDictionary *)arguments;
- (void)setupHeadersForRequest:(NSMutableURLRequest *)request;
- (SmugMugResponse *)responseFromMethod:(NSString *)method 
							  arguments:(NSDictionary *)arguments 
							     useSSL:(BOOL)secure;
- (SmugMugResponse *)responseFromURL:(NSURL *)url;
- (SmugMugResponse *)responseFromData:(NSData *)data 
								error:(NSError *)error;
- (NSString *)urlEncode:(NSString *)string;
- (NSString *)realFilename:(NSString *)filename 
						  :(NSURL *)urlToImage;
- (NSString *)keywordStringFromKeywords:(NSArray *)arrayOfKeyWords;
- (NSString *)md5HashForData:(NSData *)data;
- (NSData *)HTTPBodyFromArguments:(NSDictionary *)arguments;
- (NSString *)baseURL:(BOOL)useSSL;
- (NSString *)baseUploadURL:(BOOL)useSSL;
- (void)_threadedUpload:(NSDictionary *)dictionary;
- (NSDictionary *)_upload:(NSURL *)urlToImage
					album:(NSString *)albumID 
					 name:(NSString *)filename 
				  caption:(NSString *)caption 
				 keywords:(NSArray *)keywords 
				 latitude:(NSString *)latitude 
				longitude:(NSString *)longitude 
				 altitude:(NSString *)altitudeInMeters;
- (BOOL)isSupportedImageType:(NSString *)extension;
+ (NSDictionary *)dictionaryForStringRepresentation:(NSString *)string;
+ (NSString *)stringRepresentationForDictionary:(NSDictionary *)dictionary;
@end



@implementation CocoaSmugMug

- (void)dealloc
{
	[self clearSession];
	[_formatter release];	
	
	[super dealloc];
}

- (id)initWithResponseFormatter:(id <ResponseFormatter>)formatter
{
	self = [super init];
		
	_formatter = [formatter retain];
	_shouldUseSSL = NO;
	_timeoutInterval = 20;
		
	return self;
}

- (void)checkSession
{
	NSAssert(_sessionID, @"*** No sessionID: Login first to use CocoaSmugMug.");
}

- (void)clearSession
{
	[_sessionID release];
	_sessionID = nil;
}

- (BOOL)shouldUseSSL
{
	return _shouldUseSSL;
}

- (void)setShouldUseSSL:(BOOL)value
{
	_shouldUseSSL = value;
}

- (void)setTimeoutInterval:(NSTimeInterval)value
{
	_timeoutInterval = value;
}

- (NSString *)md5HashForData:(NSData *)data
{
	unsigned char digest[16];
	char finaldigest[32];
	int i;
	
	MD5([data bytes],[data length],digest);
	for(i=0;i<16;i++) sprintf(finaldigest+i*2,"%02x",digest[i]);
	
	return [NSString stringWithCString:finaldigest length:32];
}

- (NSTimeInterval)timeoutInterval
{
	return _timeoutInterval;
}

- (NSString *)generateTransaction
{
	return [[NSProcessInfo processInfo] globallyUniqueString];
}

- (NSString *)keywordStringFromKeywords:(NSArray *)arrayOfKeyWords
{
	return [arrayOfKeyWords componentsJoinedByString:@";"]; 
}

// returns a string conforming to RFC 2396
- (NSString *)urlEncode:(NSString *)string
{
	NSString *urlSafeString = (NSString *) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef) string, NULL, NULL, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
	return urlSafeString;
}

- (NSString *)realFilename:(NSString *)filename :(NSURL *)urlToImage
{
	NSString *realFilename = nil;

	if (filename)  {
		realFilename = filename;
	}
	else {
		NSString *urlPathToImage = ([urlToImage isFileURL]) ? [urlToImage path] : [urlToImage absoluteString];
		realFilename = [[urlPathToImage lastPathComponent] stringByDeletingPathExtension];
	}
	return realFilename;
}

- (BOOL)isSupportedImageType:(NSString *)extension
{
	return ([extension caseInsensitiveCompare:@"JPG"]  || 
			[extension caseInsensitiveCompare:@"JPEG"] || 
			[extension caseInsensitiveCompare:@"GIF"]  || 
			[extension caseInsensitiveCompare:@"PNG"]) ? YES : NO;
}

- (SmugMugResponse *)responseFromMethod:(NSString *)method 
							  arguments:(NSDictionary *)arguments 
								 useSSL:(BOOL)secure 
{
	NSString *urlString = [self urlEncode:[NSString stringWithFormat:@"%@?method=%@", [self baseURL:secure], method]];
	NSURL *url = [NSURL URLWithString:urlString];
	
	NSError *error;	
	NSHTTPURLResponse *response;
	NSMutableURLRequest *request;
	NSData *responseData;
	
	request = [NSMutableURLRequest requestWithURL:url 
									  cachePolicy:NSURLRequestReloadIgnoringCacheData
								  timeoutInterval:[self timeoutInterval]];

	[request setHTTPMethod:@"POST"];							
	[self setupHeadersForRequest:request];
		
	NSData *bodyAsData = [self HTTPBodyFromArguments:arguments];
	[request setHTTPBody:bodyAsData];
	 	
	responseData = [NSURLConnection sendSynchronousRequest:request
										 returningResponse:&response
										 error:&error];
										 
	return [self responseFromData:responseData error:error];
}

- (NSData *)HTTPBodyFromArguments:(NSDictionary *)arguments
{
	NSArray *allHeaders = [arguments allKeys];
	int count = [allHeaders count], counter = 0;
	NSMutableString *mutableBody = [NSMutableString string];
	
	while (counter < count)  {
		NSString *header = [allHeaders objectAtIndex:counter++];
		NSString *value = [arguments objectForKey:header];
		[mutableBody appendFormat:@"&%@=%@", header, value];
	}
			
	NSString *bodyAsString = [self urlEncode:mutableBody];
	NSData *bodyAsData = [bodyAsString dataUsingEncoding:NSUTF8StringEncoding];

	return bodyAsData;
}

- (void)setupHeadersForRequest:(NSMutableURLRequest *)request
{
	[request setValue:[[NSProcessInfo processInfo] processName] forHTTPHeaderField:@"User-Agent"];
	[request setValue:SMUGMUG_API_VERSION forHTTPHeaderField:@"X-Smug-Version"];
	[request setValue:[_formatter formatType] forHTTPHeaderField:@"X-Smug-ResponseType"];
}

- (NSDictionary *)responseDictionaryFromData:(NSData *)data error:(NSError *)error
{
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	
	if (data && [data length])   {
		NSString *transaction = [self generateTransaction];		
		[d setObject:transaction forKey:SMUGMUG_RESPONSE_TRANSACTION];
		[d setObject:[_formatter formatType] forKey:SMUGMUG_RESPONSE_TYPE];
		[d setObject:data forKey:SMUGMUG_RESPONSE_DATA];
	}
	
	if (error != nil)
	{
		[d setObject:error forKey:SMUGMUG_RESPONSE_SYSTEM_ERROR];
	}
	
	return d;
}

- (SmugMugResponse *)responseFromData:(NSData *)data 
								error:(NSError *)error
{
	NSDictionary *d = [self responseDictionaryFromData:data error:error];
	return [[[SmugMugResponse alloc] initWithDictionary:d responseFormatter:_formatter] autorelease];
}

- (NSString *)baseURL:(BOOL)useSSL
{	
	return [NSString stringWithFormat:@"%@api.smugmug.com/hack/%@/%@/", (useSSL) ? @"https://" : @"http://", [[_formatter formatType] lowercaseString], SMUGMUG_API_VERSION];
}

- (NSString *)baseUploadURL:(BOOL)useSSL
{
	return [(useSSL) ? @"https://" : @"http://" stringByAppendingString:SMUGMUG_UPLOAD_URL];
}

- (NSDictionary *)errorDictionaryFromUploadErrorNotification:(NSNotification *)notification
{
	NSString *string = [notification object];
	NSDictionary *errorDictionary = [[self class] dictionaryForStringRepresentation:string];
	
	return errorDictionary;
}

- (SmugMugResponse *)responseFromDidCompleteUploadNotification:(NSNotification *)notification
{
	NSString *string = [notification object];
	NSDictionary *d = [[self class] dictionaryForStringRepresentation:string];
	
	return [[[SmugMugResponse alloc] initWithDictionary:d responseFormatter:_formatter] autorelease];
}

+ (NSDictionary *)dictionaryForStringRepresentation:(NSString *)string
{
	NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *dictionary = [NSPropertyListSerialization propertyListFromData: data mutabilityOption: NSPropertyListImmutable format: nil errorDescription: nil];
	return dictionary;
}

+ (NSString *)stringRepresentationForDictionary:(NSDictionary *)dictionary
{
	NSData *data = [NSPropertyListSerialization dataFromPropertyList: dictionary format: NSPropertyListXMLFormat_v1_0 errorDescription: nil];
	NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	return string;
}

#pragma mark -
#pragma mark Login

- (SmugMugResponse *)loginWithAPIKey:(NSString *)apiKey 
							   email:(NSString *)email 
							password:(NSString *)password;
{	
	NSString *method = @"smugmug.login.withPassword";
	NSString *loginString = [[self baseURL:NO] stringByAppendingFormat:@"?method=%@", method];
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:apiKey, @"APIKey", email, @"EmailAddress", password, @"Password", nil];
	return [self _login:loginString :arguments];
}

- (SmugMugResponse *)secureLoginWithAPIKey:(NSString *)apiKey 
									 email:(NSString *)email 
								  password:(NSString *)password
{	
	NSString *method = @"smugmug.login.withPassword";
	NSString *loginString = [[self baseURL:YES] stringByAppendingFormat:@"?method=%@", method];
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:apiKey, @"APIKey", email, @"EmailAddress", password, @"Password", nil];
	return [self _login:loginString :arguments];
}

- (SmugMugResponse *)loginWithAPIKey:(NSString *)apiKey 
							  userID:(NSNumber *)userID 
					    passwordHash:(NSString *)passwordHash
{	
	NSString *method = @"smugmug.login.withHash";
	NSString *loginString = [[self baseURL:NO] stringByAppendingFormat:@"?method=%@", method];
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:apiKey, @"APIKey", [userID stringValue], @"UserID", passwordHash, @"PasswordHash", nil];
	return [self _login:loginString :arguments];
}

- (SmugMugResponse *)secureLoginWithAPIKey:(NSString *)apiKey 
									userID:(NSNumber *)userID 
							  passwordHash:(NSString *)passwordHash
{	
	NSString *method = @"smugmug.login.withHash";
	NSString *loginString = [[self baseURL:YES] stringByAppendingFormat:@"?method=%@", method];
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:apiKey, @"APIKey", [userID stringValue], @"UserID", passwordHash, @"PasswordHash", nil];
	return [self _login:loginString :arguments];
}

- (SmugMugResponse *)anonymousLoginWithAPIKey:(NSString *)apiKey
{
	NSString *method = @"smugmug.login.anonymously";
	NSString *loginString = [[self baseURL:NO] stringByAppendingFormat:@"?method=%@", method];
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:apiKey, @"APIKey", nil];
	return [self _login:loginString :arguments];
}

- (SmugMugResponse *)secureAnonymousLoginWithAPIKey:(NSString *)apiKey
{	
	NSString *method = @"smugmug.login.anonymously";
	NSString *loginString = [[self baseURL:NO] stringByAppendingFormat:@"?method=%@", method];
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:apiKey, @"APIKey", nil];
	return [self _login:loginString :arguments];
}

- (SmugMugResponse *)_login:(NSString *)loginString 
						    :(NSDictionary *)arguments
{
	NSURL *url = [NSURL URLWithString:loginString];
	NSError *error = nil;	
	NSHTTPURLResponse *xmlResponse;  // not used
	NSMutableURLRequest *request;
	NSData *responseData = nil;
	SmugMugResponse *response = nil;
	NSData *bodyAsData = nil;
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	
	request = [NSMutableURLRequest requestWithURL:url 
									  cachePolicy:NSURLRequestReloadIgnoringCacheData
								  timeoutInterval:[self timeoutInterval]];

	[request setHTTPMethod:@"POST"];
	[self setupHeadersForRequest:request];
	
	bodyAsData = [self HTTPBodyFromArguments:arguments];
	[request setHTTPBody:bodyAsData];
	
	responseData = [NSURLConnection sendSynchronousRequest:request
										 returningResponse:&xmlResponse
													 error:&error];
	if ([responseData length])  {
		
		// do this here
		[self clearSession];
		
		NSString *transaction = [self generateTransaction];
		[d setObject:transaction forKey:SMUGMUG_RESPONSE_TRANSACTION];
				
		[d setObject:[_formatter formatType] forKey:SMUGMUG_RESPONSE_TYPE];
		[d setObject:responseData forKey:SMUGMUG_RESPONSE_DATA];

		NSDictionary *responseDictionary = [_formatter formatDictionaryFromResponseData:responseData];
		
		_sessionID = [[[[responseDictionary objectForKey:@"Login"] objectForKey:@"Session"] objectForKey:@"id"] retain];
	}
	
	if (error != nil)
	{
		[d setObject:error forKey:SMUGMUG_RESPONSE_SYSTEM_ERROR];
	}
		
	response = [[[SmugMugResponse alloc] initWithDictionary:d responseFormatter:_formatter] autorelease];
	return response;
}


#pragma mark -
#pragma mark Logout

- (SmugMugResponse *)logout
{
	NSString *method = @"smugmug.logout";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	[self clearSession];
	
	return response;
}


#pragma mark -
#pragma mark Users

- (SmugMugResponse *)getTree
{
	[self checkSession];

	NSString *method = @"smugmug.users.getTree";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)getTransferStatsForMonth:(NSNumber *)month 
									     year:(NSNumber *)year
{
	[self checkSession];

	NSString *method = @"smugmug.users.getTransferStats";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [month stringValue], @"Month", [year stringValue], @"Year", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
			 
	return response;
}


#pragma mark -
#pragma mark Albums

- (SmugMugResponse *)getAllAlbums
{
	[self checkSession];

	NSString *method = @"smugmug.albums.get";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
			 
	return response;
}

- (SmugMugResponse *)getAlbumInfo:(NSNumber *)albumID
{
	[self checkSession];

	NSString *method = @"smugmug.albums.getInfo";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [albumID stringValue], @"AlbumID", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)createAlbumWithTitle:(NSString *)title
							   categoryID:(NSNumber *)categoryID
						  albumTemplateID:(NSNumber *)albumTemplateID
						    subCategoryID:(NSNumber *)subCategoryID
							  communityID:(NSNumber *)communityID
							  description:(NSString *)description
							     keywords:(NSArray *)keywords
							     password:(NSString *)password
						     passwordHint:(NSString *)passwordHint
							     position:(NSNumber *)position
							   sortMethod:(NSString *)sortMethod
						    sortDirection:(BOOL)ascendingOrDescending
								   public:(BOOL)public
							    filenames:(BOOL)filenames
							     comments:(BOOL)comments
							     external:(BOOL)external
								     EXIF:(BOOL)EXIF
								    share:(BOOL)share
							    printable:(BOOL)printable
							    originals:(BOOL)originals
							   familyEdit:(BOOL)familyEdit
							   friendEdit:(BOOL)friendEdit
								   header:(BOOL)header
							   templateID:(NSNumber *)templateID
								   larges:(BOOL)larges
								    clean:(BOOL)clean
							    protected:(BOOL)protected
						     watermarking:(BOOL)watermarking
							    proofDays:(NSNumber *)proofDays
						     backprinting:(NSString *)backprinting
						   smugSearchable:(BOOL)smugSearchable
						  worldSearchable:(BOOL)worldSearchable
{
	[self checkSession];

	NSString *method = @"smugmug.albums.create";
	NSMutableDictionary *arguments = [NSMutableDictionary dictionary];
	
	[arguments setObject:title forKey:@"Title"];
	[arguments setObject:_sessionID forKey:@"SessionID"];
	[arguments setObject:[categoryID stringValue] forKey:@"CategoryID"];

	[arguments setObject:[albumTemplateID stringValue] forKey:@"AlbumTemplateID"];
	[arguments setObject:[subCategoryID stringValue]  forKey:@"SubCategoryID"];
	[arguments setObject:[communityID stringValue]  forKey:@"CommunityID"];
	if (description)
		[arguments setObject:description  forKey:@"Description"];
	if (keywords)  {
		NSString *keywordsAsString = [self keywordStringFromKeywords:keywords];
		[arguments setObject:keywordsAsString  forKey:@"Keywords"];
	}
	if (password)
		[arguments setObject:password  forKey:@"Password"];
	if (passwordHint)
		[arguments setObject:passwordHint forKey:@"PasswordHint"];
	[arguments setObject:[position stringValue]  forKey:@"Position"];
	if (sortMethod)
		[arguments setObject:sortMethod  forKey:@"SortMethod"];
	[arguments setObject:[[NSNumber numberWithBool:ascendingOrDescending] stringValue]  forKey:@"SortDirection"];
	[arguments setObject:[[NSNumber numberWithBool:public] stringValue]  forKey:@"Public"];
	[arguments setObject:[[NSNumber numberWithBool:filenames] stringValue]  forKey:@"Filenames"];
	[arguments setObject:[[NSNumber numberWithBool:comments] stringValue]  forKey:@"Comments"];
	[arguments setObject:[[NSNumber numberWithBool:external] stringValue]  forKey:@"External"];
	[arguments setObject:[[NSNumber numberWithBool:EXIF] stringValue]  forKey:@"EXIF"];
	[arguments setObject:[[NSNumber numberWithBool:share] stringValue]  forKey:@"Share"];
	[arguments setObject:[[NSNumber numberWithBool:printable] stringValue]  forKey:@"Printable"];
	[arguments setObject:[[NSNumber numberWithBool:originals] stringValue]  forKey:@"Originals"];
	[arguments setObject:[[NSNumber numberWithBool:familyEdit] stringValue]  forKey:@"FamilyEdit"];
	[arguments setObject:[[NSNumber numberWithBool:friendEdit] stringValue]  forKey:@"FriendEdit"];
	[arguments setObject:[[NSNumber numberWithBool:header] stringValue]  forKey:@"Header"];
	[arguments setObject:[templateID stringValue]  forKey:@"TemplateID"];
	[arguments setObject:[[NSNumber numberWithBool:larges] stringValue]  forKey:@"Larges"];
	[arguments setObject:[[NSNumber numberWithBool:clean] stringValue]  forKey:@"Clean"];
	[arguments setObject:[[NSNumber numberWithBool:protected] stringValue]  forKey:@"Protected"];
	[arguments setObject:[[NSNumber numberWithBool:watermarking] stringValue]  forKey:@"Watermarking"];
	[arguments setObject:[proofDays stringValue]  forKey:@"ProofDays"];
	if (backprinting)
		[arguments setObject:backprinting  forKey:@"Backprinting"];
	[arguments setObject:[[NSNumber numberWithBool:smugSearchable] stringValue]  forKey:@"SmugSearchable"];
	[arguments setObject:[[NSNumber numberWithBool:worldSearchable] stringValue]  forKey:@"WorldSearchable"];

	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	return response;
}

- (SmugMugResponse *)changeSettingsForAlbum:(NSNumber *)albumID
							     categoryID:(NSNumber *)categoryID
								newSettings:(NSDictionary *)settingsToChange
{
	[self checkSession];

	NSString *method = @"smugmug.albums.changeSettings";
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [albumID stringValue], @"AlbumID", [categoryID stringValue], @"CategoryID", nil];
	
	NSArray *keys = [settingsToChange allKeys];
	int count = [keys count], counter = 0;
	
	while (counter < count)  {
		NSString *header = [keys objectAtIndex:counter++];
		id value = [settingsToChange objectForKey:header];
		
		if ([value isKindOfClass:[NSNumber class]])  {
			[arguments setObject:[value stringValue] forKey:header];
		}
		else if ([value isKindOfClass:[NSString class]])  {
			[arguments setObject:value forKey:header];
		}
		// else ignore
	}
	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)sortAlbum:(NSNumber *)albumID 
							by:(NSString *)sortKey 
					 direction:(NSString *)direction
{
	[self checkSession];

	NSString *method = @"smugmug.albums.reSort";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", sortKey, @"By", direction, @"Direction", [albumID stringValue], @"AlbumID", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)deleteAlbum:(NSNumber *)albumID
{
	[self checkSession];

	NSString *method = @"smugmug.albums.delete";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [albumID stringValue], @"AlbumID", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)getStatsForAlbum:(NSNumber *)albumID 
								month:(NSNumber *)month 
								 year:(NSNumber *)year 
								heavy:(BOOL)includeStatsForEachImage
{
	[self checkSession];

	NSString *method = @"smugmug.albums.getStats";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:[albumID stringValue], @"AlbumID", _sessionID, @"SessionID", [month stringValue], @"Month", [year stringValue], @"Year", [[NSNumber numberWithBool:includeStatsForEachImage] stringValue], @"Heavy", nil];			 
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}


#pragma mark -
#pragma mark Album Templates

- (SmugMugResponse *)getAlbumTemplates
{
	[self checkSession];

	NSString *method = @"smugmug.albumtemplates.get";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}


#pragma mark -
#pragma mark Images

- (SmugMugResponse *)getImageIDsForAlbum:(NSNumber *)albumID 
								   heavy:(BOOL)notSureWhatThisIs
{
	[self checkSession];

	NSString *method = @"smugmug.images.get";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [[NSNumber numberWithBool:notSureWhatThisIs] stringValue], @"Heavy", [albumID stringValue], @"AlbumID", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)getImageURLsForImage:(NSNumber *)imageID 
									album:(NSNumber *)albumID 
								 template:(NSNumber *)templateID
{
	[self checkSession];

	NSString *method = @"smugmug.images.getURLs";
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [albumID stringValue], @"AlbumID", [imageID stringValue], @"ImageID", nil];
	if (templateID)
		[arguments setObject:[templateID stringValue] forKey:@"TemplateID"];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)getInfoForImage:(NSNumber *)imageID
{
	[self checkSession];

	NSString *method = @"smugmug.images.getInfo";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [imageID stringValue], @"ImageID", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];
	
	return response;
}

- (SmugMugResponse *)getEXIFforImage:(NSNumber *)imageID
{
	[self checkSession];

	NSString *method = @"smugmug.images.getEXIF";
	NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [imageID stringValue], @"ImageID", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];	
		 
	return response;
}

- (SmugMugResponse *)changeSetingsForImage:(NSNumber *)imageID 
								  newAlbum:(NSNumber *)newAlbumID 
								newCaption:(NSString *)newCaption 
							   newKeywords:(NSArray *)newKeywords
{
	[self checkSession];

	NSString *method = @"smugmug.images.changeSettings";
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [imageID stringValue], @"ImageID", nil];
		
	if (newAlbumID)  {
		[arguments setObject:[newAlbumID stringValue] forKey:@"AlbumID"];
	}
	
	if (newCaption)  {
		[arguments setObject:newCaption forKey:@"Caption"];
	}
	
	if (newKeywords)  {
		NSString *keywordsAsString = [self keywordStringFromKeywords:newKeywords];
		[arguments setObject:keywordsAsString forKey:@"Keywords"];
	}
		
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 
	return response;
}

- (SmugMugResponse *)changePositionForImage:(NSNumber *)imageID 
								newPosition:(NSNumber *)newPosition
{
	[self checkSession];

	NSString *method = @"smugmug.images.changePosition";
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [imageID stringValue], @"ImageID", [newPosition stringValue], @"Position", nil];		 
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 
	
	return response;
}

- (SmugMugResponse *)imageUpload:(NSURL *)urlToImage 
						 toAlbum:(NSNumber *)albumID 
						withName:(NSString *)filename 
						 caption:(NSString *)caption 
						keywords:(NSArray *)keywords 
						latitude:(NSNumber *)latitudeAsDouble
					   longitude:(NSNumber *)longitudeAsDouble 
						altitude:(NSNumber *)altitudeInMeters
{
	[self checkSession];

	NSString *pathExtension = [[urlToImage path] pathExtension];
	if ([self isSupportedImageType:pathExtension])  {
	
		NSString *realFilename = [self realFilename:filename :urlToImage];
		NSString *baseUploadURL = [self baseUploadURL:_shouldUseSSL];
		NSString *urlString = [self urlEncode:[NSString stringWithFormat:@"%@%@", baseUploadURL, realFilename]];
		NSURL *uploadURL = [NSURL URLWithString:urlString];
		
	/*
		* Content-Length
			  o required
			  o standard HTTP header, must match the actual bytes sent in the body (your image)
		* Content-MD5
			  o required
			  o standard HTTP header, must be an MD5 of the data in the body (your image)
		* X-Smug-SessionID
			  o required
			  o SessionID from API login calls
		* X-Smug-Version
			  o required
			  o API Version (ex: 1.1.1)
		* X-Smug-ResponseType
			  o required
			  o set "XML-RPC", "REST", "JSON" or "PHP" depending on your desired response formatting.
		* X-Smug-AlbumID
			  o required
			  o The AlbumID you're adding the photo to
		* X-Smug-FileName
			  o optional
			  o The filename of the photo you're adding
		* X-Smug-Caption
			  o optional
			  o Sets the Caption on the image
			  o For multi-line captions, use a carriage return between lines
		* X-Smug-Keywords
			  o optional
			  o Sets the Keywords on the image
		* X-Smug-Latitude
			  o optional
			  o Sets the Latitude of the image (in the form D.d, such as 37.430096)
		* X-Smug-Longitude
			  o optional
			  o Sets the Longitude of the image (in the form D.d, such as -122.152269)
		* X-Smug-Altitude
			  o optional
			  o Sets the Altitude of the image (in meters)
	*/

		NSData *content = [NSData dataWithContentsOfURL:urlToImage];
		unsigned int length = [content length];
		NSString *md5HashAsString = [self md5HashForData:content];
		NSString *keywordsAsString = [self keywordStringFromKeywords:keywords];
		NSHTTPURLResponse *xmlResponse;  // not used
		NSError *error;	
						
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uploadURL
															   cachePolicy:NSURLRequestReloadIgnoringCacheData
														   timeoutInterval:[self timeoutInterval]];
		[request setHTTPMethod:@"PUT"];
		[request setHTTPBody:content];
		
		[self setupHeadersForRequest:request];
		[request setValue:_sessionID forHTTPHeaderField:@"X-Smug-SessionID"];
		[request setValue:[[NSNumber numberWithInt:length] stringValue] forHTTPHeaderField:@"Content-Length"];
		[request setValue:md5HashAsString forHTTPHeaderField:@"Content-MD5"];
		[request setValue:[albumID stringValue] forHTTPHeaderField:@"X-Smug-AlbumID"];
		[request setValue:realFilename forHTTPHeaderField:@"X-Smug-FileName"];
		[request setValue:caption forHTTPHeaderField:@"X-Smug-Caption"];
		[request setValue:keywordsAsString forHTTPHeaderField:@"X-Smug-Keywords"];

		[request setValue:[latitudeAsDouble stringValue] forHTTPHeaderField:@"X-Smug-Latitude"];
		[request setValue:[longitudeAsDouble stringValue] forHTTPHeaderField:@"X-Smug-Longitude"];
		[request setValue:[altitudeInMeters stringValue] forHTTPHeaderField:@"X-Smug-Altitude"];
				
		//NSLog(@"[request allHTTPHeaderFields]: %@", [request allHTTPHeaderFields]);
				
		NSData *responseData = [NSURLConnection sendSynchronousRequest:request
											 returningResponse:&xmlResponse
														 error:&error];

		SmugMugResponse *response = [self responseFromData:responseData error:error];
		return response;
	}
	
	[[NSException exceptionWithName:CocoaSmugMugUnsupportedImageTypeException reason:[NSString stringWithFormat:@"'%@' images are not supported by SmugMug.", pathExtension]  userInfo:nil] raise];
	return nil; // for compiler happiness
}

- (NSString *)threadedImageUpload:(NSURL *)urlToImage 
						  toAlbum:(NSNumber *)albumID 
						 withName:(NSString *)filename 
						  caption:(NSString *)caption 
						 keywords:(NSArray *)keywords 
						 latitude:(NSNumber *)latitudeAsDouble
						longitude:(NSNumber *)longitudeAsDouble
						 altitude:(NSNumber *)altitudeInMeters
{
	[self checkSession];

	NSString *pathExtension = [[urlToImage path] pathExtension];
	if ([self isSupportedImageType:pathExtension])  {

		NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
		NSString *transaction = [self generateTransaction];
		
		[dictionary setObject:transaction forKey:SMUGMUG_RESPONSE_TRANSACTION];
		
		if (filename)
			[dictionary setObject:filename forKey:@"filename"];
		if (caption)
			[dictionary setObject:caption forKey:@"caption"];
		if (keywords)
			[dictionary setObject:keywords forKey:@"keywords"];
		if (latitudeAsDouble)
			[dictionary setObject:[latitudeAsDouble stringValue] forKey:@"latitude"];
		if (longitudeAsDouble)			
			[dictionary setObject:[longitudeAsDouble stringValue] forKey:@"longitude"];
		if (altitudeInMeters)
			[dictionary setObject:[altitudeInMeters stringValue] forKey:@"altitude"];

		[dictionary setObject:urlToImage forKey:@"url"];
		[dictionary setObject:[albumID stringValue] forKey:@"album"];
		
		[NSThread detachNewThreadSelector:@selector(_threadedUpload:) toTarget:self withObject:dictionary];
		
		return transaction;
	}
	
	[[NSException exceptionWithName:CocoaSmugMugUnsupportedImageTypeException reason:[NSString stringWithFormat:@"'%@' images are not supported by SmugMug.", pathExtension]  userInfo:nil] raise];
	return nil; // for compiler happiness
}

- (void)_threadedUpload:(NSDictionary *)dictionary
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSString *albumID = [dictionary objectForKey:@"album"];
	NSURL *url = [dictionary objectForKey:@"url"];
	
	NSDictionary *d = [self _upload:url album:albumID name:[dictionary objectForKey:@"filename"] caption:[dictionary objectForKey:@"caption"] keywords:[dictionary objectForKey:@"keywords"] latitude:[dictionary objectForKey:@"latitude"] longitude:[dictionary objectForKey:@"longitude"] altitude:[dictionary objectForKey:@"altitude"]];	
	NSData *responseData = [d objectForKey:SMUGMUG_RESPONSE_DATA];
	NSDictionary *responseDictionary = [_formatter formatDictionaryFromResponseData:responseData];
		
	BOOL success = ([[responseDictionary objectForKey:SMUGMUG_RESPONSE_STATUS] isEqualToString:@"ok"] && [d objectForKey:SMUGMUG_RESPONSE_SYSTEM_ERROR] == nil) ? YES : NO;

	if (success)  {
		[(NSMutableDictionary *)d setObject:responseDictionary forKey:SMUGMUG_PROPERTY_LIST];
		NSString *string = [[self class] stringRepresentationForDictionary:d];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:CocoaSmugMugDidCompleteUploadNotification object:string];
	}		
	else  {
		NSString *errorInfoAsString = nil;
		NSMutableDictionary *errorUserInfo = nil;
		NSString *transaction = [dictionary objectForKey:SMUGMUG_RESPONSE_TRANSACTION];
		
		if ([d objectForKey:SMUGMUG_RESPONSE_SYSTEM_ERROR])  {
			NSError *error = [d objectForKey:SMUGMUG_RESPONSE_SYSTEM_ERROR];
						
			errorUserInfo = [[error userInfo] mutableCopy];			
			[errorUserInfo removeObjectForKey:@"NSErrorFailingURLKey"];	// otherwise NSURL fails plist serialization
			
			[errorUserInfo setObject:transaction forKey:SMUGMUG_RESPONSE_TRANSACTION];
			[errorUserInfo setObject:[error domain] forKey:@"domain"];
			[errorUserInfo setObject:[NSNumber numberWithInt:[error code]] forKey:@"code"];			
		}
		else {
			NSString *formatType = [d objectForKey:SMUGMUG_RESPONSE_TYPE];
			NSData *responseData = [d objectForKey:SMUGMUG_RESPONSE_DATA];
			errorUserInfo = [[NSMutableDictionary alloc] init]; 
									
			NSDictionary *plist = [_formatter formatDictionaryFromResponseData:responseData];
			
			NSString *stat = nil; NSString *msg = nil; NSString *code = nil;
			 
			stat = [plist objectForKey:@"stat"];
			msg  = [plist objectForKey:@"message"];
			code = [plist objectForKey:@"code"];
			
			if (stat)
				[errorUserInfo setObject:stat forKey:SMUGMUG_RESPONSE_STATUS];
			if (msg)
				[errorUserInfo setObject:msg forKey:@"message"];
			if (code)
				[errorUserInfo setObject:code forKey:@"code"];
					
			[errorUserInfo setObject:formatType forKey:SMUGMUG_RESPONSE_TYPE];					
			[errorUserInfo setObject:transaction forKey:SMUGMUG_RESPONSE_TRANSACTION];
		}

		errorInfoAsString = [[self class] stringRepresentationForDictionary:errorUserInfo];

		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:CocoaSmugMugUploadErrorNotification object:errorInfoAsString];
		
		// cleanup
		[errorUserInfo release];
	}
	
	[pool release];
}

- (NSDictionary *)_upload:(NSURL *)urlToImage
					album:(NSString *)albumID 
					 name:(NSString *)filename 
				  caption:(NSString *)caption 
				 keywords:(NSArray *)keywords 
				 latitude:(NSString *)latitude 
				longitude:(NSString *)longitude 
				 altitude:(NSString *)altitudeInMeters
{	
	NSString *realFilename = [self realFilename:filename :urlToImage];
	NSString *baseUploadURL = [self baseUploadURL:_shouldUseSSL];
	NSString *urlString = [self urlEncode:[NSString stringWithFormat:@"%@%@", baseUploadURL, realFilename]];
	NSURL *uploadURL = [NSURL URLWithString:urlString];

	NSData *content = nil;
	content = [NSData dataWithContentsOfURL:urlToImage];		// load picture data into memory to calculate required MD5 hash
	NSString *lengthString = [[NSNumber numberWithInt:[content length]] stringValue];
	NSString *md5HashAsString = [self md5HashForData:content];
		
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uploadURL
														   cachePolicy:NSURLRequestReloadIgnoringCacheData
													   timeoutInterval:[self timeoutInterval]];
	[request setHTTPMethod:@"PUT"];
	[request setHTTPBody:content];

	[self setupHeadersForRequest:request];
		
	[request setValue:_sessionID forHTTPHeaderField:@"X-Smug-SessionID"];
	[request setValue:lengthString forHTTPHeaderField:@"Content-Length"];
	[request setValue:md5HashAsString forHTTPHeaderField:@"Content-MD5"];
	[request setValue:albumID forHTTPHeaderField:@"X-Smug-AlbumID"];

	[request setValue:realFilename forHTTPHeaderField:@"X-Smug-FileName"];
	
	if (caption)  {
		[request setValue:caption forHTTPHeaderField:@"X-Smug-Caption"];
	}
	if (keywords)  {
		NSString *keywordsAsString = [self keywordStringFromKeywords:keywords];
		[request setValue:keywordsAsString forHTTPHeaderField:@"X-Smug-Keywords"];
	}
	if (latitude)  {
		[request setValue:latitude forHTTPHeaderField:@"X-Smug-Latitude"];
	}	
	if (longitude)  {
		[request setValue:longitude forHTTPHeaderField:@"X-Smug-Longitude"];
	}
	if (altitudeInMeters)  {
		[request setValue:altitudeInMeters forHTTPHeaderField:@"X-Smug-Altitude"];
	}
		
	NSHTTPURLResponse *xmlResponse;  // not used
	NSError *error;	
	
	NSData *responseData = [NSURLConnection sendSynchronousRequest:request
										 returningResponse:&xmlResponse
													 error:&error];			
	
	return [self responseDictionaryFromData:responseData error:error];
}

- (SmugMugResponse *)deleteImage:(NSNumber *)imageID
{
	[self checkSession];

	NSString *method = @"smugmug.images.delete";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [imageID stringValue], @"ImageID", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 
	
	return response;
}

- (SmugMugResponse *)getStatsForImage:(NSNumber *)imageID 
								month:(NSNumber *)month
{
	[self checkSession];

	NSString *method = @"smugmug.images.getStats";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [imageID stringValue], @"ImageID", [month stringValue], nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}


#pragma mark -
#pragma mark Categories

- (SmugMugResponse *)getAllCategories
{
	[self checkSession];

	NSString *method = @"smugmug.categories.get";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];	
		 	
	return response;
}

- (SmugMugResponse *)createCategory:(NSString *)name
{
	[self checkSession];

	NSString *method = @"smugmug.categories.create";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", name, @"Name", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];	
		 	
	return response;
}

- (SmugMugResponse *)deleteCategory:(NSNumber *)categoryID
{
	[self checkSession];

	NSString *method = @"smugmug.categories.delete";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [categoryID stringValue], @"CategoryID", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}

- (SmugMugResponse *)renameCategory:(NSNumber *)categoryID 
								 to:(NSString *)newName
{
	[self checkSession];

	NSString *method = @"smugmug.categories.rename";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [categoryID stringValue], @"CategoryID", newName, @"Name", nil];		
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}


#pragma mark -
#pragma mark SubCategories

- (SmugMugResponse *)getSubCategoriesForCategory:(NSNumber *)categoryID
{
	[self checkSession];

	NSString *method = @"smugmug.subcategories.get";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [categoryID stringValue], @"CategoryID", nil];		
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}

- (SmugMugResponse *)getAllSubCategories
{
	[self checkSession];

	NSString *method = @"smugmug.subcategories.getAll";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}

- (SmugMugResponse *)createSubCategoryWithName:(NSString *)name 
								   forCategory:(NSNumber *)categoryID
{
	[self checkSession];

	NSString *method = @"smugmug.subcategories.create";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [categoryID stringValue], @"CategoryID", name, @"Name", nil];	
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}

- (SmugMugResponse *)deleteSubCategory:(NSNumber *)subCategoryID
{
	[self checkSession];

	NSString *method = @"smugmug.subcategories.delete";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [subCategoryID stringValue], @"SubCategoryID", nil];		
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}

- (SmugMugResponse *)renameSubCategory:(NSNumber *)subCategoryID 
									to:(NSString *)newName
{
	[self checkSession];

	NSString *method = @"smugmug.subcategories.rename";	
	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys:_sessionID, @"SessionID", [subCategoryID stringValue], @"SubCategoryID", newName, @"Name", nil];
	SmugMugResponse *response = [self responseFromMethod:method arguments:arguments useSSL:_shouldUseSSL];		 	
	
	return response;
}


@end


#pragma mark -


@implementation SmugMugResponse

- (void)dealloc
{
	[_dictionary release];
	[_formatter release];
	
	[super dealloc];
}

- (id)initWithDictionary:(NSDictionary *)dictionary 
	   responseFormatter:(id <ResponseFormatter>)formatter
{
	self = [super init];
	_dictionary = [dictionary retain];
	_formatter = [formatter retain];
			
	return self;
}

- (NSString *)formatType
{
	return [_formatter formatType];
}

- (BOOL)success
{	
	return ([[self status] isEqualToString:@"ok"] && [self systemError] == nil) ? YES : NO;
}

- (NSString *)status
{
	NSString *s = nil;
	s = [_dictionary objectForKey:SMUGMUG_RESPONSE_STATUS];
	if (!s)  {
		NSDictionary *plist = [self responseDictionary];
		s = [plist objectForKey:SMUGMUG_RESPONSE_STATUS];
		[_dictionary setObject:s forKey:SMUGMUG_RESPONSE_STATUS];
	}
	return s;
}

- (NSError *)systemError
{
	return [_dictionary objectForKey:SMUGMUG_RESPONSE_SYSTEM_ERROR];
}

- (NSDictionary *)responseDictionary
{
	NSDictionary *responseDictionary = nil;
	responseDictionary = [_dictionary objectForKey:SMUGMUG_PROPERTY_LIST];
	if (!responseDictionary)  {
		NSData *responseData = [self responseData];
		responseDictionary = [_formatter formatDictionaryFromResponseData:responseData];
		[_dictionary setObject:responseDictionary forKey:SMUGMUG_PROPERTY_LIST];
	}
	return responseDictionary;
}

- (NSData *)responseData
{
	return [_dictionary objectForKey:SMUGMUG_RESPONSE_DATA];
}

- (NSString *)transaction	
{
	return [_dictionary objectForKey:SMUGMUG_RESPONSE_TRANSACTION];
}

- (NSString *)description
{
	return [[super description] stringByAppendingFormat:@": %@", [_dictionary description]]; 
}

@end
#endif
