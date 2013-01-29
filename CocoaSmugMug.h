/*  

CocoaSmugMug.h

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

#import <Cocoa/Cocoa.h>


#define CocoaSmugMugUnsupportedImageTypeException					@"CocoaSmugMugUnsupportedImageTypeException"
#define CocoaSmugMugDidCompleteUploadNotification					@"CocoaSmugMugDidCompleteUploadNotification"
#define CocoaSmugMugUploadErrorNotification							@"CocoaSmugMugUploadErrorNotification"

#define SMUGMUG_JSON_FORMAT										@"JSON"
#define SMUGMUG_REST_FORMAT										@"REST"
#define SMUGMUG_XML_RPC_FORMAT									@"XMLRPC"
#define SMUGMUG_PHP_FORMAT										@"PHP"

#define SMUGMUG_RESPONSE_TRANSACTION		@"transaction"
#define SMUGMUG_PROPERTY_LIST				@"responsePlist"
#define SMUGMUG_RESPONSE_TYPE				@"formatType"
#define SMUGMUG_RESPONSE_DATA				@"responseData"
#define SMUGMUG_RESPONSE_STATUS				@"stat"
#define SMUGMUG_RESPONSE_SYSTEM_ERROR		@"systemError"


@class SmugMugResponse;

@protocol ResponseFormatter <NSObject>
- (NSString *)formatType;
- (NSDictionary *)formatDictionaryFromResponseData:(NSData *)data;
@end

@interface CocoaSmugMug : NSObject 
{
	NSString *_sessionID;
	id <ResponseFormatter> _formatter;
	
	BOOL _shouldUseSSL;
	NSTimeInterval _timeoutInterval;
}

/*!
    @method 
    @abstract 
		Designated initializer
	@result 
		SmugMugResponse
	@discussion
*/
- (id)initWithResponseFormatter:(id <ResponseFormatter>)strategy;


/*  SMUGMUG API METHODS  */


/* NOTE: All string arguments should be made RFC 2396 compliant */

#pragma mark -
#pragma mark Login

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.login.withPassword
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)loginWithAPIKey:(NSString *)apiKey 
							   email:(NSString *)email 
						    password:(NSString *)password;
							
- (SmugMugResponse *)secureLoginWithAPIKey:(NSString *)apiKey 
								     email:(NSString *)email 
								  password:(NSString *)password;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.login.withHash
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)loginWithAPIKey:(NSString *)apiKey 
							  userID:(NSNumber *)userID 
						passwordHash:(NSString *)passwordHash;
						
- (SmugMugResponse *)secureLoginWithAPIKey:(NSString *)apiKey 
									userID:(NSNumber *)userID 
							  passwordHash:(NSString *)password;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.login.anonymously
	@result 
		SmugMugResponse
	@discussion
*/
 
- (SmugMugResponse *)anonymousLoginWithAPIKey:(NSString *)apiKey;
- (SmugMugResponse *)secureAnonymousLoginWithAPIKey:(NSString *)apiKey;


#pragma mark -
#pragma mark Logout

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.logout
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)logout;


#pragma mark -
#pragma mark Users

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.users.getTree
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getTree;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.users.getTransferStats
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getTransferStatsForMonth:(NSNumber *)month year:(NSNumber *)year;


#pragma mark -
#pragma mark Albums

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.get
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getAllAlbums;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.getInfo
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getAlbumInfo:(NSNumber *)albumID;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.create
	@result 
		SmugMugResponse
	@discussion
*/
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
						  worldSearchable:(BOOL)worldSearchable;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.changeSettings
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)changeSettingsForAlbum:(NSNumber *)albumID
							     categoryID:(NSNumber *)categoryID
								newSettings:(NSDictionary *)settingsToChange;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.reSort								 
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)sortAlbum:(NSNumber *)albumID by:(NSString *)sortKey direction:(NSString *)direction;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.delete
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)deleteAlbum:(NSNumber *)albumID;

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.getStats
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getStatsForAlbum:(NSNumber *)albumID 
								month:(NSNumber *)month 
								 year:(NSNumber *)year 
								heavy:(BOOL)includeStatsForEachImage;

#pragma mark -
#pragma mark Album Templates

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albumtemplates.get		
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getAlbumTemplates;


#pragma mark -
#pragma mark Images

/*!
    @method 
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.get
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getImageIDsForAlbum:(NSNumber *)albumID 
								   heavy:(BOOL)notSureWhatThisIs;

/*!
    @method 
			'templateID' is optional and can be nil
    @abstract 
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getURLs
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getImageURLsForImage:(NSNumber *)imageID 
									album:(NSNumber *)albumID 
								 template:(NSNumber *)templateID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getInfo
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getInfoForImage:(NSNumber *)imageID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getEXIF
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getEXIFforImage:(NSNumber *)imageID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.changeSettings
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)changeSetingsForImage:(NSNumber *)imageID 
							      newAlbum:(NSNumber *)newAlbumID 
							    newCaption:(NSString *)newCaption 
							   newKeywords:(NSArray *)newKeywords;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.changePosition
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)changePositionForImage:(NSNumber *)imageID 
								newPosition:(NSNumber *)newPosition;

/*!
    @method 
			uploads the image at urlToImage, which can be local (i.e. file url) or networked. all params after 'albumID' are optional.
			note all images are loaded into memory first to calculate the required MD5 hash.
    @abstract	
			(see HTTP PUT section)
			http://smugmug.jot.com/WikiHome/API/Uploading
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)imageUpload:(NSURL *)urlToImage 
						 toAlbum:(NSNumber *)albumID 
						withName:(NSString *)filename 
						 caption:(NSString *)caption 
						keywords:(NSArray *)keywords 
						latitude:(NSNumber *)latitudeAsDouble 
					   longitude:(NSNumber *)longitudeAsDouble 
						altitude:(NSNumber *)altitudeInMeters; 

/*!
    @method 
		same as above, except performs upload in a separate thread. returns a transaction ID in calling thread, and posts
		either a CocoaSmugMugDidCompleteUploadNotification on success or CocoaSmugMugUploadErrorNotification on failure to [NSDistributedNotificationCenter defaultCenter];
		[notification object] can be used to retrieve a SmugMugResponse or error dictionary respectively
		 
		(see also 'errorDictionaryFromUploadErrorNotification:' and 'responseFromDidCompleteUploadNotification:'
		
    @abstract	
	@result 
		Transaction ID
	@discussion
*/
- (NSString *)threadedImageUpload:(NSURL *)urlToImage 
						  toAlbum:(NSNumber *)albumID 
						 withName:(NSString *)filename 
						  caption:(NSString *)caption 
						 keywords:(NSArray *)keywords 
						 latitude:(NSNumber *)latitudeAsDouble 
						longitude:(NSNumber *)longitudeAsDouble 
						 altitude:(NSNumber *)altitudeInMeters; 

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.delete
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)deleteImage:(NSNumber *)imageID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getStats
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getStatsForImage:(NSNumber *)imageID month:(NSNumber *)month;


#pragma mark -
#pragma mark Categories

/*!
    @method 
    @abstract
		http://smugmug.jot.com/WikiHome/1.2.0/smugmug.categories.get
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getAllCategories;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.categories.create
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)createCategory:(NSString *)name;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.categories.delete
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)deleteCategory:(NSNumber *)categoryID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.categories.rename
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)renameCategory:(NSNumber *)categoryID 
								 to:(NSString *)newName;


#pragma mark -
#pragma mark SubCategories

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.subcategories.get
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getSubCategoriesForCategory:(NSNumber *)categoryID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.subcategories.getAll
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)getAllSubCategories;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.subcategories.create
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)createSubCategoryWithName:(NSString *)name 
								   forCategory:(NSNumber *)categoryID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/1.2.0/smugmug.subcategories.delete
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)deleteSubCategory:(NSNumber *)subCategoryID;

/*!
    @method 
    @abstract
			http://smugmug.jot.com/WikiHome/API/Versions/1.2.0/smugmug.subcategories.rename
	@result 
		SmugMugResponse
	@discussion
*/
- (SmugMugResponse *)renameSubCategory:(NSNumber *)subCategoryID 
									to:(NSString *)newName;





#pragma mark -
#pragma mark Class and Instance Methods

/*!
    @method
				default NO
    @abstract 	
	@result 
	@discussion
*/
- (BOOL)shouldUseSSL;										
- (void)setShouldUseSSL:(BOOL)value;

/*!
    @method
				default 20sec
    @abstract 
	@result 
	@discussion
*/
- (NSTimeInterval)timeoutInterval;							
- (void)setTimeoutInterval:(NSTimeInterval)value;

/*!
    @method
			override to implement transaction management (default returns a GUID used for each request).
    @abstract 
	@result 
	@discussion
*/
- (NSString *)generateTransaction;

/*!
    @methods
			for threaded uploads (see below), these methods are used to extract either an error dictionary or SmugMugResponse
			from a CocoaSmugMugUploadErrorNotification or CocoaSmugMugDidCompleteUploadNotification respectively. 
    @abstract 
	@result 
	@discussion
*/

- (NSDictionary *)errorDictionaryFromUploadErrorNotification:(NSNotification *)notification;
- (SmugMugResponse *)responseFromDidCompleteUploadNotification:(NSNotification *)notification;


@end

#pragma mark -
#pragma mark 


@interface SmugMugResponse : NSObject
{
	id <ResponseFormatter> _formatter;
	NSMutableDictionary *_dictionary;
}

- (id)initWithDictionary:(NSDictionary *)dictionary 
	   responseFormatter:(id <ResponseFormatter>)formatter;

/*!
    @method
    @abstract 
	@result 
			returns ([self status] == "ok" && [self systemError] == nil) ? YES : NO 
	@discussion
*/
- (BOOL)success;	

/*!
    @method
    @abstract 	
	@result 
		returns [_formatter formatType];
	@discussion
*/
- (NSString *)formatType;		

/*!
    @method
    @abstract 	
	@result 
		returns response data as returned by SmugMug
	@discussion
*/

- (NSData *)responseData;

/*!
    @method
    @abstract 	
	@result 
		returns [_formatter formatDictionaryFromResponseData:[self responseData]];
	@discussion
*/		
- (NSDictionary *)responseDictionary;

/*!
    @method
    @abstract 	
	@result 
		return server-side stat code for request  ("ok" or "fail")
	@discussion
*/
- (NSString *)status;						

/*!
    @method
    @abstract 	
	@result 
		returns client-side error if present
	@discussion
*/
- (NSError *)systemError;					

/*!
    @method
				by default, returns [[NSProcessInfo processInfo] globallyUniqueString]
    @abstract 	
	@result 
	@discussion
*/
- (NSString *)transaction;					/* transaction identifier */

@end

#endif
