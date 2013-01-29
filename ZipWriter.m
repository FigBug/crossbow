//
//  ZipWriter.m
//  Crossbow
//
// Copyright (C) 2009 Roland Rabien
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


#import "ZipWriter.h"
#import "DirEntry.h"
#include "zip.h"

@implementation ZipWriter

+ (NSString*)createZipName:(NSString*)path
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* post = [path lastPathComponent];
	
	NSString* zipFile = [path stringByAppendingPathComponent: [post stringByAppendingString:@".zip"]];
	if (![fm fileExistsAtPath:zipFile])
		return zipFile;
	
	int i = 0;
	
	do
	{
		i++;
		NSString* str = [NSString stringWithFormat:@"%@(%d).zip", post, i];
		zipFile = [path stringByAppendingPathComponent:str]; 
		
	} while ([fm fileExistsAtPath:zipFile]);
	
	return zipFile;
}

+ (NSThread*)createZippingThread:(DirEntry*)location with:(NSArray*)files forSheet:(id)sheet;
{
	NSString* path = [location path];
	NSString* zipFile = [ZipWriter createZipName:path];
	
	return [[NSThread alloc] initWithTarget:[ZipWriter zipWriterWithPath:zipFile] selector:@selector(threadProc:) object:[NSArray arrayWithObjects:location, files, sheet, nil]];
}

- (void)threadProc:(id)param
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	DirEntry* location = [param objectAtIndex:0];
	NSArray*  files    = [param objectAtIndex:1];
	id sheet           = [param objectAtIndex:2];
	
	NSString* path = [location path];
	
	int i = 0;
	for (DirEntry* de in files)
	{
		if ([de isFile])
		{
			NSString* name = [[de path] substringFromIndex:[path length] + 1];
			
			[self addFile:[de path] withName:name];
		}	
		i++;
		[sheet performSelectorOnMainThread:@selector(setProgress:) withObject:[NSNumber numberWithDouble: i / (double)[files count]] waitUntilDone:NO];
		
		if ([[NSThread currentThread] isCancelled])
			break;
	}
		
	[self close];
	
	if ([[NSThread currentThread] isCancelled])
	{
		[[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
	}
	else
	{
		[[NSWorkspace sharedWorkspace] selectFile:zipFilePath inFileViewerRootedAtPath:path];
		[sheet performSelectorOnMainThread:@selector(cancel:) withObject:[NSThread currentThread] waitUntilDone:NO];
	}
	
	[[NSThread currentThread] autorelease];
	
	[pool release];
}

+ (bool)createZipIn:(DirEntry*)location with:(NSArray*)files
{
	NSString* path = [location path];
	NSString* zipFile = [ZipWriter createZipName:path];
	
	ZipWriter* zip = [ZipWriter zipWriterWithPath:zipFile];
	
	for (DirEntry* de in files)
	{
		if ([de isFile])
		{
			NSString* name = [[de path] substringFromIndex:[path length] + 1];
		
			[zip addFile:[de path] withName:name];
		}
	}
	
	[zip close];
	
	[[NSWorkspace sharedWorkspace] selectFile:zipFile inFileViewerRootedAtPath:path];
	
	return YES;
}

+ (id)zipWriterWithPath:(NSString*)path
{
	return [[[ZipWriter alloc] initWithPath:path] autorelease];
}

- (id)initWithPath:(NSString*)path
{
	if (self = [super init])
	{
		zipFilePath = [path copy];
		zipHandle = zipOpen([path fileSystemRepresentation], APPEND_STATUS_CREATE);
		if (!zipHandle)
		{
			[self autorelease];
			return nil;
		}
	}
	return self;
}

- (void)dealloc
{
	[zipFilePath release];
	
	[super dealloc];
}

- (BOOL)addFile:(NSString*)path withName:(NSString*)name
{
	NSFileHandle* src = [NSFileHandle fileHandleForReadingAtPath:path];
	if (!src)
		return NO;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSDictionary* attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
	
	zip_fileinfo zipInfo;
	
	NSDate* date = [attr objectForKey:NSFileModificationDate];
	NSDateComponents* comp = [[NSCalendar currentCalendar] components: NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit fromDate:date];
	
	zipInfo.tmz_date.tm_sec  = [comp second];
	zipInfo.tmz_date.tm_min  = [comp minute];
	zipInfo.tmz_date.tm_hour = [comp hour];
	zipInfo.tmz_date.tm_mday = [comp day];
	zipInfo.tmz_date.tm_mon  = [comp month];
	zipInfo.tmz_date.tm_year = [comp year];
	
	zipInfo.dosDate = 0;
	
	zipInfo.internal_fa = 0;
	zipInfo.external_fa = 0;
	
	if (zipOpenNewFileInZip(zipHandle, 
                        [name fileSystemRepresentation], 
	                    &zipInfo, 
	                    NULL, 0,
	                    NULL, 0,
	                    NULL,
	                    Z_DEFLATED,
	                    Z_DEFAULT_COMPRESSION) == ZIP_OK)
	{
		NSData* data = nil;
		int len = 0;
		do
		{
			NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];

			data = [src readDataOfLength:10 * 1024];
			len = [data length];
			
			if (len > 0)
				zipWriteInFileInZip(zipHandle, [data bytes], [data length]);
			
			[subpool release];
		}
		while (len > 0);
		
		[src closeFile];
		
		zipCloseFileInZip(zipHandle);
	}
	[pool release];
	return YES;
}

- (void)close
{
	zipClose(zipHandle, NULL);
}

@end
