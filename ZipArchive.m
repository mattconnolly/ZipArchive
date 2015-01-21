/**
//  ZipArchive.m
//  
//
//  Created by aish on 08-9-11.
//  acsolu@gmail.com
//  Copyright 2008  Inc. All rights reserved.
//
*/

#import "ZipArchive.h"
#import <zlib.h>
#import <zconf.h>
#include "minizip/zip.h"
#include "minizip/unzip.h"



@interface NSFileManager(ZipArchive)
- (NSDictionary *)_attributesOfItemAtPath:(NSString *)path followingSymLinks:(BOOL)followingSymLinks error:(NSError **)error;
@end

@interface ZipArchive ()

-(void) OutputErrorMessage:(NSString*) msg;
-(BOOL) OverWrite:(NSString*) file;
-(NSDate*) Date1980;

@property (nonatomic,copy) NSString* password;
@end



@implementation ZipArchive
@synthesize delegate = _delegate;
@synthesize numFiles = _numFiles;
@synthesize password = _password;
@synthesize unzippedFiles = _unzippedFiles;
@synthesize progressBlock = _progressBlock;
@synthesize stringEncoding = _stringEncoding;
@synthesize secondStringEncoding = _secondStringEncoding;

-(id) init
{
    return [self initWithFileManager:[NSFileManager defaultManager]];
}

-(id) initWithFileManager:(NSFileManager*) fileManager
{
	if( self=[super init] )
	{
		_zipFile = NULL;
        _fileManager = fileManager;
        self.stringEncoding = NSUTF8StringEncoding;
        self.secondStringEncoding = 0;
        self.compression = ZipArchiveCompressionDefault;
	}
	return self;
}

-(void) dealloc
{
    // close any open file operations
	[self CloseZipFile2];
    [self UnzipCloseFile];
    
    // release retained/copied properties.
    [_password release];
    [_delegate release];
    [_unzippedFiles release];
    
    [super dealloc];

}

/**
 * Create a new zip file at the specified path, ready for new files to be added.
 *
 * @param zipFile     the path of the zip file to create
 * @returns BOOL YES on success
 */

-(BOOL) CreateZipFile2:(NSString*) zipFile
{
	_zipFile = zipOpen( (const char*)[zipFile UTF8String], 0 );
	if( !_zipFile ) 
		return NO;
	return YES;
}

/**
 * Create a new zip file at the specified path, ready for new files to be added.
 *
 * @param zipFile     the path of the zip file to create
 * @param password    a password used to encrypt the zip file
 * @returns BOOL YES on success
 */

-(BOOL) CreateZipFile2:(NSString*) zipFile Password:(NSString*) password
{
	self.password = password;
	return [self CreateZipFile2:zipFile];
}

/**
 * add an existing file on disk to the zip archive, compressing it.
 *
 * @param file    the path to the file to compress
 * @param newname the name of the file in the zip archive, ie: path relative to the zip archive root.
 * @returns BOOL YES on success
 */

-(BOOL) addFileToZip:(NSString*) file newname:(NSString*) newname;
{
    @autoreleasepool {
        if( !_zipFile )
            return NO;
        //	tm_zip filetime;
        
        zip_fileinfo zipInfo = {{0}};
        
        NSDate* fileDate = nil;
        
        NSError* error = nil;
        NSDictionary* attr = [_fileManager _attributesOfItemAtPath:file followingSymLinks:YES error:&error];
        if( attr )
            fileDate = (NSDate*)[attr objectForKey:NSFileModificationDate];
        
        if( fileDate == nil )
            fileDate = [NSDate date];
        
        //NS_AVAILABLE(10_6, 4_0);
        NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
        NSDateComponents* components = [gregorianCalendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                                        NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:fileDate];
        [gregorianCalendar release];
        zipInfo.tmz_date.tm_sec = (uInt)components.second;
        zipInfo.tmz_date.tm_min = (uInt)components.minute;
        zipInfo.tmz_date.tm_hour = (uInt)components.hour;
        zipInfo.tmz_date.tm_mday = (uInt)components.day;
        zipInfo.tmz_date.tm_mon = (uInt)(components.month - 1);
        zipInfo.tmz_date.tm_year = (uInt)components.year;
        
        
        int ret ;
        NSData* data = nil;
        if( [_password length] == 0 )
        {
            ret = zipOpenNewFileInZip( _zipFile,
                                      (const char*) [newname cStringUsingEncoding:self.stringEncoding],
                                      &zipInfo,
                                      NULL,0,
                                      NULL,0,
                                      NULL,//comment
                                      Z_DEFLATED,
                                      self.compression );
        }
        else
        {
            data = [ NSData dataWithContentsOfFile:file];
            uLong crcValue = crc32( 0L,NULL, 0L );
            crcValue = crc32( crcValue, (const Bytef*)[data bytes], (unsigned int)[data length] );
            ret = zipOpenNewFileInZip3( _zipFile,
                                       (const char*) [newname cStringUsingEncoding:self.stringEncoding],
                                       &zipInfo,
                                       NULL,0,
                                       NULL,0,
                                       NULL,//comment
                                       Z_DEFLATED,
                                       self.compression,
                                       0,
                                       15,
                                       8,
                                       Z_DEFAULT_STRATEGY,
                                       [_password cStringUsingEncoding:NSASCIIStringEncoding],
                                       crcValue );
        }
        if( ret!=Z_OK )
        {
            return NO;
        }
        if( data==nil )
        {
            data = [ NSData dataWithContentsOfFile:file];
        }
        unsigned int dataLen = (unsigned int)[data length];
        ret = zipWriteInFileInZip( _zipFile, (const void*)[data bytes], dataLen);
        if( ret!=Z_OK )
        {
            return NO;
        }
        ret = zipCloseFileInZip( _zipFile );
        
        if( ret!=Z_OK )
            return NO;
        return YES;
    }
}

// 2010-12-22, Michael Burford (michael@burford.net)
// 2013-09-25, Altered by Javin Elliff to add folder names and maintain initial prefix.
// "pathPrefix" should be nil or @"" the first call; lets the recursive calls store in subfolders in the zip file.
-(NSInteger) addFolderToZip:(NSString*)path pathPrefix:(NSString*)prefix
{
	NSInteger	fileCount = 0;
	NSArray		*dirArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
	
    if( prefix == nil )
        prefix = [path lastPathComponent];
    else
        prefix = [prefix stringByAppendingPathComponent:[path lastPathComponent]];
    
    [self addFileToZip:path newname:[prefix stringByAppendingString:@"/"]];
    
	for (int i=0; i<[dirArray count]; i++)
    {
		NSString		*dirItem = [dirArray objectAtIndex:i];
		NSDictionary	*dict = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:dirItem] error:nil];
		
		if ([[dict fileType] isEqualToString:NSFileTypeDirectory] || [[dict fileType] isEqualToString:NSFileTypeSymbolicLink])
		{
			//Recursively do subfolders.
			fileCount += [self addFolderToZip:[path stringByAppendingPathComponent:dirItem] pathPrefix:prefix];
		}
		else
		{
			//Count if added OK.
			if ([self addFileToZip:[path stringByAppendingPathComponent:dirItem] newname:([prefix length]>0 ? [prefix stringByAppendingPathComponent:dirItem] : dirItem)])
            {
				fileCount++;
			}
		}
	}
	return fileCount;
}



/**
 * Close a zip file after creating and added files to it.
 *
 * @returns BOOL YES on success
 */

-(BOOL) CloseZipFile2
{
	self.password = nil;
	if( _zipFile==NULL )
		return NO;
	BOOL ret =  zipClose( _zipFile,NULL )==Z_OK?YES:NO;
	_zipFile = NULL;
	return ret;
}

/**
 * open an existing zip file ready for expanding.
 *
 * @param zipFile     the path to a zip file to be opened.
 * @returns BOOL YES on success
 */

-(BOOL) UnzipOpenFile:(NSString*) zipFile
{
    // create an array to receive the list of unzipped files.
    if (_unzippedFiles) [_unzippedFiles release];
    _unzippedFiles = [[NSMutableArray alloc] initWithCapacity:1];
    
	_unzFile = unzOpen( (const char*)[zipFile UTF8String] );
	if( _unzFile )
	{
		unz_global_info  globalInfo = {0};
		if( unzGetGlobalInfo(_unzFile, &globalInfo )==UNZ_OK )
		{
            _numFiles = globalInfo.number_entry;
			NSLog(@"%lu entries in the zip file", globalInfo.number_entry);
		}
	}
	return _unzFile!=NULL;
}

/**
 * open an existing zip file with a password ready for expanding.
 *
 * @param zipFile     the path to a zip file to be opened.
 * @param password    the password to use decrpyting the file.
 * @returns BOOL YES on success
 */

-(BOOL) UnzipOpenFile:(NSString*) zipFile Password:(NSString*) password
{
	self.password = password;
	return [self UnzipOpenFile:zipFile];
}

/**
 * Expand all files in the zip archive into the specified directory.
 *
 * If a delegate has been set and responds to OverWriteOperation: it can
 * return YES to overwrite a file, or NO to skip that file.
 *
 * On completion, the property `unzippedFiles` will be an array populated
 * with the full paths of each file that was successfully expanded.
 *
 * @param path    the directory where expanded files will be created
 * @param overwrite    should existing files be overwritten
 * @returns BOOL YES on success
 */

-(BOOL) UnzipFileTo:(NSString*) path overWrite:(BOOL) overwrite
{
	BOOL success = YES;
    int index = 0;
    int progress = -1;
	int ret = unzGoToFirstFile( _unzFile );
	unsigned char		buffer[4096] = {0};
	if( ret!=UNZ_OK )
	{
		[self OutputErrorMessage:@"Failed"];
	}
    
	const char* password = [_password cStringUsingEncoding:NSASCIIStringEncoding];
	
	do{
        @autoreleasepool {
            if( [_password length]==0 )
                ret = unzOpenCurrentFile( _unzFile );
            else
                ret = unzOpenCurrentFilePassword( _unzFile, password );
            if( ret!=UNZ_OK )
            {
                [self OutputErrorMessage:@"Error occurs"];
                success = NO;
                break;
            }
            // reading data and write to file
            int read ;
            unz_file_info	fileInfo ={0};
            ret = unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
            if( ret!=UNZ_OK )
            {
                [self OutputErrorMessage:@"Error occurs while getting file info"];
                success = NO;
                unzCloseCurrentFile( _unzFile );
                break;
            }
            char* filename = (char*) malloc( fileInfo.size_filename +1 );
            unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
            filename[fileInfo.size_filename] = '\0';
            
            // check if it contains directory
            NSString * strPath = [NSString stringWithCString:filename encoding:self.stringEncoding];
            if ( nil == strPath )
            {
                strPath         = [NSString stringWithCString: filename encoding: [self _OptionStringEncoding]];
            }
            if ( nil == strPath )
            {
                [self           OutputErrorMessage:@"Error occurs while second encoding file name"];
                success         = NO;
                unzCloseCurrentFile( _unzFile );
                break;
            }
                        
            BOOL isDirectory = NO;
            if( filename[fileInfo.size_filename-1]=='/' || filename[fileInfo.size_filename-1]=='\\')
                isDirectory = YES;
            free( filename );
            if( [strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location!=NSNotFound )
            {// contains a path
                strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
            }
            NSString* fullPath = [path stringByAppendingPathComponent:strPath];
            
            if( isDirectory )
                [_fileManager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:nil];
            else
                [_fileManager createDirectoryAtPath:[fullPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
			
			// Send message to delegate about the file we're about to decompress
			index++;
			if ([_delegate respondsToSelector:@selector(zipArchive:willBeginToDecompressFile:number:of:withTotalUncompressedBytes:)]) {
				[_delegate zipArchive:self willBeginToDecompressFile:strPath number:index of:_numFiles withTotalUncompressedBytes:fileInfo.uncompressed_size];
			}
			
            FILE* fp = NULL;
            do
            {
                read = unzReadCurrentFile(_unzFile, buffer, 4096);
                if (read >= 0)
                {
                    if (fp == NULL) {
                        if( [_fileManager fileExistsAtPath:fullPath] && !isDirectory && !overwrite )
                        {
                            if( ![self OverWrite:fullPath] )
                            {
                                // don't process any more of the file, but continue
                                break;
                            }
                        }
                        if (!isDirectory) {
                            fp = fopen( (const char*)[fullPath UTF8String], "wb");
                            if (fp == NULL) {
                                [self OutputErrorMessage:@"Failed to open output file for writing"];
                                break;
                            }
                        }
                    }
                    fwrite(buffer, read, 1, fp );
					
					// Send message to delegate about number of bytes written out
					if ([_delegate respondsToSelector:@selector(zipArchive:uncompressedBytesWritten:)]) {
						[_delegate zipArchive:self uncompressedBytesWritten:read];
					}
                }
                else // if (read < 0)
                {
                    ret = read; // result will be an error code
                    success = NO;
                    [self OutputErrorMessage:@"Failed to read zip file"];
                }
            } while (read > 0);
            
            if (fp)
            {
                fclose( fp );
                
                // add the full path of this file to the output array
                [(NSMutableArray*)_unzippedFiles addObject:fullPath];
                
                // set the orignal datetime property
                if( fileInfo.tmu_date.tm_year!=0 )
                {
                    NSDateComponents* components = [[NSDateComponents alloc] init];
                    components.second = fileInfo.tmu_date.tm_sec;
                    components.minute = fileInfo.tmu_date.tm_min;
                    components.hour = fileInfo.tmu_date.tm_hour;
                    components.day = fileInfo.tmu_date.tm_mday;
                    components.month = ( fileInfo.tmu_date.tm_mon + 1 );
                    components.year = fileInfo.tmu_date.tm_year;
                    
                    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
                    
                    NSDate* orgDate =  [[gregorianCalendar dateFromComponents:components] retain];
                    [components release];
                    [gregorianCalendar release];
                    
                    NSDictionary* attr = [NSDictionary dictionaryWithObject:orgDate forKey:NSFileModificationDate]; //[_fileManager fileAttributesAtPath:fullPath traverseLink:YES];
                    if( attr )
                    {
                        //	[attr  setValue:orgDate forKey:NSFileCreationDate];
                        if( ![_fileManager setAttributes:attr ofItemAtPath:fullPath error:nil] )
                        {
                            // cann't set attributes 
                            NSLog(@"Failed to set attributes");
                        }
                        
                    }
                    [orgDate release];
                    orgDate = nil;
                }
                
            }
            
            if (ret == UNZ_OK) {
                ret = unzCloseCurrentFile( _unzFile );
                if (ret != UNZ_OK) {
                    [self OutputErrorMessage:@"file was unzipped but failed crc check"];
                    success = NO;
                }
            }
            
            if (ret == UNZ_OK) {
                ret = unzGoToNextFile( _unzFile );
            }
            
            if (_progressBlock && _numFiles) {
                //index++;
                int p = index*100/_numFiles;
                progress = p;
                _progressBlock(progress, index, _numFiles, strPath);
            }
        }
	} while (ret==UNZ_OK && ret!=UNZ_END_OF_LIST_OF_FILE);
	return success;
}

-(NSDictionary *)UnzipFileToMemory
{
    NSMutableDictionary *fileDictionary = [NSMutableDictionary dictionary];
    
    BOOL success = YES;
    int index = 0;
    int progress = -1;
    int ret = unzGoToFirstFile( _unzFile );
    unsigned char		buffer[4096] = {0};
    if( ret!=UNZ_OK )
    {
        [self OutputErrorMessage:@"Failed"];
    }
    
    const char* password = [_password cStringUsingEncoding:NSASCIIStringEncoding];
    
    do{
        @autoreleasepool {
            if( [_password length]==0 )
                ret = unzOpenCurrentFile( _unzFile );
            else
                ret = unzOpenCurrentFilePassword( _unzFile, password );
            if( ret!=UNZ_OK )
            {
                [self OutputErrorMessage:@"Error occurs"];
                success = NO;
                break;
            }
            // reading data and write to file
            int read ;
            unz_file_info	fileInfo ={0};
            ret = unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
            if( ret!=UNZ_OK )
            {
                [self OutputErrorMessage:@"Error occurs while getting file info"];
                success = NO;
                unzCloseCurrentFile( _unzFile );
                break;
            }
            char* filename = (char*) malloc( fileInfo.size_filename +1 );
            unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
            filename[fileInfo.size_filename] = '\0';
            
            // check if it contains directory
            NSString * strPath = [NSString stringWithCString:filename encoding:self.stringEncoding];
            if ( nil == strPath )
            {
                strPath         = [NSString stringWithCString: filename encoding: [self _OptionStringEncoding]];
            }
            if ( nil == strPath )
            {
                [self           OutputErrorMessage:@"Error occurs while second encoding file name"];
                success         = NO;
                unzCloseCurrentFile( _unzFile );
                break;
            }
            
            free( filename );
            if( [strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location!=NSNotFound )
            {// contains a path
                strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
            }
            
            // Send message to delegate about the file we're about to decompress
            index++;
            if ([_delegate respondsToSelector:@selector(zipArchive:willBeginToDecompressFile:number:of:withTotalUncompressedBytes:)]) {
                [_delegate zipArchive:self willBeginToDecompressFile:strPath number:index of:_numFiles withTotalUncompressedBytes:fileInfo.uncompressed_size];
            }
            
            NSMutableData *fileMutableData = [NSMutableData data];
            do
            {
                read = unzReadCurrentFile(_unzFile, buffer, 4096);
                if (read >= 0)
                {
                    if (read != 0)
                    {
                        [fileMutableData appendBytes:buffer length:read];
                    }

                    // Send message to delegate about number of bytes written out
                    if ([_delegate respondsToSelector:@selector(zipArchive:uncompressedBytesWritten:)]) {
                        [_delegate zipArchive:self uncompressedBytesWritten:read];
                    }
                    
                }
                else // if (read < 0)
                {
                    ret = read; // result will be an error code
                    success = NO;
                    [self OutputErrorMessage:@"Failed to read zip file"];
                }
            } while (read > 0);
            
            
            if (fileMutableData.length > 0)
            {
                NSData *fileData = [NSData dataWithData:fileMutableData];
                [fileDictionary setObject:fileData forKey:strPath];
            }
            
            if (ret == UNZ_OK) {
                ret = unzCloseCurrentFile( _unzFile );
                if (ret != UNZ_OK) {
                    [self OutputErrorMessage:@"file was unzipped but failed crc check"];
                    success = NO;
                }
            }
            
            if (ret == UNZ_OK) {
                ret = unzGoToNextFile( _unzFile );
            }
            
            if (_progressBlock && _numFiles) {
                //index++;
                int p = index*100/_numFiles;
                progress = p;
                _progressBlock(progress, index, _numFiles, strPath);
            }
        }
    } while (ret==UNZ_OK && ret!=UNZ_END_OF_LIST_OF_FILE);
    
    NSDictionary *resultDictionary = [NSDictionary dictionaryWithDictionary:fileDictionary];
    return resultDictionary;
}

/**
 * Close the zip file.
 *
 * @returns BOOL YES on success
 */

-(BOOL) UnzipCloseFile
{
	self.password = nil;
	if( _unzFile ) {
		int err = unzClose( _unzFile );
        _unzFile = nil;
        return err ==UNZ_OK;
    }
	return YES;
}


/**
 * Return a list of filenames that are in the zip archive. 
 * No path information is available as this can be called before the zip is expanded.
 *
 * @returns NSArray list of filenames in the zip archive. 
 */

-(NSArray*) getZipFileContents     // list the contents of the zip archive. must be called after UnzipOpenFile
{
    int ret = unzGoToFirstFile( _unzFile );
    NSMutableArray * allFilenames = [NSMutableArray arrayWithCapacity:40];
    
    if( ret!=UNZ_OK )
    {
        [self OutputErrorMessage:@"Failed"];
    }
    
    const char* password = [_password cStringUsingEncoding:NSASCIIStringEncoding];
    
    do{
        if( [_password length]==0 )
            ret = unzOpenCurrentFile( _unzFile );
        else
            ret = unzOpenCurrentFilePassword( _unzFile, password );
        if( ret!=UNZ_OK )
        {
            [self OutputErrorMessage:@"Error occured"];
            break;
        }
        
        // reading data and write to file
        unz_file_info   fileInfo ={0};
        ret = unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
        if( ret!=UNZ_OK )
        {
            [self OutputErrorMessage:@"Error occurs while getting file info"];
            unzCloseCurrentFile( _unzFile );
            break;
        }
        char* filename = (char*) malloc( fileInfo.size_filename +1 );
        unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
        filename[fileInfo.size_filename] = '\0';
        
        // check if it contains directory
        NSString * strPath = [NSString stringWithCString:filename encoding:self.stringEncoding];
        if ( nil == strPath )
        {
            strPath         = [NSString stringWithCString: filename encoding: [self _OptionStringEncoding]];
        }
        if ( nil == strPath )
        {
            [self           OutputErrorMessage:@"Error occurs while second encoding file name"];
            unzCloseCurrentFile( _unzFile );
            break;
        }
        
        free( filename );
        if( [strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location!=NSNotFound )
        {// contains a path
            strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        }
        
        // Copy name to array
        [allFilenames addObject:strPath];
        
        unzCloseCurrentFile( _unzFile );
        ret = unzGoToNextFile( _unzFile );
    }  while( ret==UNZ_OK && UNZ_OK!=UNZ_END_OF_LIST_OF_FILE );
    
    // return an immutable array.
    return [NSArray arrayWithArray:allFilenames];
}


#pragma mark wrapper for delegate

/**
 * send the ErrorMessage: to the delegate if it responds to it.
 */
-(void) OutputErrorMessage:(NSString*) msg
{
	if( _delegate && [_delegate respondsToSelector:@selector(ErrorMessage:)] )
		[_delegate ErrorMessage:msg];
#ifdef DEBUG
    else
    {
        NSLog( @"%s", [msg UTF8String] );
    }
#endif
}

/**
 * send the OverWriteOperation: selector to the delegate if it responds to it,
 * returning the result, or YES by default.
 */

-(BOOL) OverWrite:(NSString*) file
{
	if( _delegate && [_delegate respondsToSelector:@selector(OverWriteOperation:)] )
		return [_delegate OverWriteOperation:file];
	return YES;
}

#pragma mark get NSDate object for 1980-01-01
-(NSDate*) Date1980
{
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	[comps setDay:1];
	[comps setMonth:1];
	[comps setYear:1980];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	NSDate *date = [gregorian dateFromComponents:comps];

    [comps release];
    [gregorian release];
	return date;
}

//  ------------------------------------------------------------------------------------------------
/**
 *  @brief  get string encode with default string encoding or relation with preferredLanguages, again.
 *
 *  @return NSStringEncoding
 */
- (NSStringEncoding) _OptionStringEncoding
{
    if ( [self secondStringEncoding] != 0 )
    {
        return [self secondStringEncoding];
    }
    
    //  when second not set, use setting language in device.
    NSString                  * language;
    language                    = [[NSLocale preferredLanguages] objectAtIndex: 0];
    if ( nil == language )
    {
        return [self stringEncoding];
    }
    
    if ( [language isEqualToString: @"ja"] == YES )
    {
        return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese);
    }
    if ( [language isEqualToString: @"zh-Hant"] == YES )
    {
        return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacChineseTrad);
    }
    if ( [language isEqualToString: @"zh-Hans"] == YES )
    {
        return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacChineseSimp);
    }
    if ( [language isEqualToString: @"ko"] == YES )
    {
        return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacKorean);
    }
    return [self stringEncoding];
}
//  ------------------------------------------------------------------------------------------------

@end


@implementation NSFileManager(ZipArchive)

- (NSDictionary *)_attributesOfItemAtPath:(NSString *)path followingSymLinks:(BOOL)followingSymLinks error:(NSError **)error
{
    // call file manager default action, which is to not follow symlinks
    NSDictionary* results = [self attributesOfItemAtPath:path error:error];
    if (followingSymLinks && results && (error ? *error == nil : YES)) {
        if ([[results fileType] isEqualToString:NSFileTypeSymbolicLink]) {
            // follow the symlink
            NSString* realPath = [self destinationOfSymbolicLinkAtPath:path error:error];
            if (realPath && (error ? *error == nil : YES)) {
                return [self _attributesOfItemAtPath:realPath followingSymLinks:followingSymLinks error:error];
            } else {
                // failure to resolve symlink should be an error returning nil and error will already be set.
                return nil;
            }
        }
    }
    return results;
}

@end

