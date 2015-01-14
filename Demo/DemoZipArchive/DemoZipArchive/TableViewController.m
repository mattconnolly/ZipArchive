//
//  TableViewController.m
//  DemoZipArchive
//
//  Created by Robin Hsu on 2015/1/12.
//  Copyright (c) 2015年 TechD. All rights reserved.
//

#import "TableViewController.h"
#import "ARCMacros.h"


//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------
@interface TableViewController ()
{
    NSMutableArray                * demoList;
    
    
    UIViewController              * demoViewController;
    
    ZipArchive                    * zipArchive;
    
}


@end

//  ------------------------------------------------------------------------------------------------
@interface TableViewController (Private)

- ( CGFloat ) _GetStatusBarHeight;

- ( void ) _InitAttributes;
- ( void ) _ReleaseDemoViewController;

- ( BOOL ) _CreateDemoViewController;

//  ------------------------------------------------------------------------------------------------
- ( BOOL ) _UnZipFromDefaultToTmp:(BOOL)callback;
- ( BOOL ) _UnZipFromDefaultToMemory:(BOOL)callback;
- ( BOOL ) _UnzipFromDefaultBig5File:(BOOL)toMemory withList:(BOOL)getList;

- ( BOOL ) _ZipFileFromTmp:(BOOL)withDirectory;

//  ------------------------------------------------------------------------------------------------


@end


@implementation TableViewController (Private)

//  ------------------------------------------------------------------------------------------------
- ( CGFloat ) _GetStatusBarHeight
{
    UIApplication                 * application;
    BOOL                            isPortrait;
    
    application                     = [UIApplication sharedApplication];
    if ( ( nil == application ) || ( [application isStatusBarHidden] == YES ) )
    {
        return 0.0f;
    }
    
    isPortrait                      = ( [self interfaceOrientation] == UIInterfaceOrientationPortrait );
    return ( ( YES == isPortrait ) ? [application statusBarFrame].size.height : [application statusBarFrame].size.width );
}

//  ------------------------------------------------------------------------------------------------
- ( void ) _InitAttributes
{
    demoList                        = [NSMutableArray arrayWithCapacity: 4];
    [demoList                       addObject: @" unzip from default zip file to tmp" ];
    [demoList                       addObject: @" unzip to tmp with callback" ];
    [demoList                       addObject: @" unzip to tmp with cb & delegate"];
    [demoList                       addObject: @" unzip file default zip file to memory"];
    [demoList                       addObject: @" unzip to memory with callback "];
    [demoList                       addObject: @" unzip to memory with cb & delegate"];
    [demoList                       addObject: @" unzip big5 file to temp"];
    [demoList                       addObject: @" unzip big5 file to temp with list"];
    [demoList                       addObject: @" unzip big5 file to memory"];
    [demoList                       addObject: @" ------------------------------------ "];
    [demoList                       addObject: @" zip file from tmp to cache (not dir)"];
    [demoList                       addObject: @" zip file from tmp to cache (with dir)"];
    
    
    zipArchive                      = nil;
    
    demoViewController              = nil;
    
}


//  ------------------------------------------------------------------------------------------------
- ( void ) _ReleaseDemoViewController
{
    if ( nil == demoViewController )
    {
        return;
    }
    
    SAFE_ARC_RELEASE( demoViewController );
    SAFE_ARC_ASSIGN_POINTER_NIL( demoViewController );
}


//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------
- ( BOOL ) _CreateDemoViewController
{
    UIViewController              * viewController;
    
    viewController                  = [UIViewController new];
    if ( nil == viewController )
    {
        return NO;
    }
    demoViewController              = viewController;
    
    //  init Top bar & back button.
    CGFloat                         screenWidth;
    CGFloat                         statusBarHeight;
    UINavigationBar               * bar;
    
    screenWidth                     = [[UIScreen mainScreen] bounds].size.width;
    statusBarHeight                 = [self _GetStatusBarHeight];
    bar                             = [[UINavigationBar alloc] initWithFrame: CGRectMake( 0, ( statusBarHeight + 1.0f ), screenWidth, 36)];
    if ( nil == bar )
    {
        return YES;
    }
    [[viewController                view] setBackgroundColor: [UIColor darkGrayColor]];
    [[viewController                view] addSubview: bar];
    
    UIBarButtonItem               * backItem;
    UINavigationItem              * titleItem;
    
    backItem                        = SAFE_ARC_AUTORELEASE( [[UIBarButtonItem alloc] initWithTitle: @"Back" style: UIBarButtonItemStylePlain target: self action: @selector( _BackAction: )] );
    
    titleItem                       = SAFE_ARC_AUTORELEASE( [[UINavigationItem alloc] initWithTitle: @"Illustration Regulator"] );
    if ( nil == titleItem )
    {
        return YES;
    }
    
    NSLog( @"title %@", titleItem );
    [bar                            pushNavigationItem: titleItem animated: YES];
    if ( nil != backItem )
    {
        [titleItem                  setLeftBarButtonItem: backItem];
    }
    
    return YES;
}

//  ------------------------------------------------------------------------------------------------
- ( void ) _BackAction:(id) sender
{
    [demoViewController             dismissViewControllerAnimated: YES completion: ^()
     {
         [self                       _ReleaseDemoViewController];
     }];
    
}

//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------
- ( BOOL ) _UnZipFromDefaultToTmp:(BOOL)callback
{
    if ( nil == zipArchive )
    {
        return NO;
    }
    
    NSFileManager                 * fileManager;
    NSString                      * resourcePath;
    NSString                      * fullPath;
    NSString                      * destination;
    
    resourcePath                    = [[NSBundle mainBundle] resourcePath];
    fileManager                     = [NSFileManager defaultManager];
    fullPath                        = [resourcePath stringByAppendingPathComponent: [NSString stringWithFormat: @"ZipArchive(zip test).zip"]];
    
    if ( ( [fileManager fileExistsAtPath: resourcePath] == NO ) || ( [fileManager fileExistsAtPath: fullPath] == NO ) )
    {
        NSLog( @"file no exist." );
        return NO;
    }
    
    destination                     = [NSTemporaryDirectory() stringByAppendingString: @"ZipArchive"];
    //  set process call back.
    if ( YES == callback )
    {
        [zipArchive                 setProgressBlock: ^(int percentage, int filesProcessed, unsigned long numFiles, NSString * filename)
        {
            NSLog( @"[%d%%] %d/%ld  %s", percentage, filesProcessed, numFiles, [filename UTF8String] );
        }];
    }
    
    if ( [zipArchive UnzipOpenFile: fullPath ] == NO )
    {
        NSLog( @"cannot open zip file." );
        [zipArchive                 UnzipCloseFile];
        return NO;
    }
    
    if ( [zipArchive UnzipFileTo: destination overWrite: YES] == NO )
    {
        NSLog( @"cannot unzip file to destination." );
        [zipArchive                 UnzipCloseFile];
        return NO;
    }

    [zipArchive                     UnzipCloseFile];
    NSLog( @"unzip file finish." );
    return YES;
}

//  ------------------------------------------------------------------------------------------------
- ( BOOL ) _UnZipFromDefaultToMemory:(BOOL)callback
{
    if ( nil == zipArchive )
    {
        return NO;
    }
    
    NSFileManager                 * fileManager;
    NSString                      * resourcePath;
    NSString                      * fullPath;
    NSDictionary                  * zipFiles;
    
    zipFiles                        = nil;
    resourcePath                    = [[NSBundle mainBundle] resourcePath];
    fileManager                     = [NSFileManager defaultManager];
    fullPath                        = [resourcePath stringByAppendingPathComponent: [NSString stringWithFormat: @"ZipArchive(zip test).zip"]];
    
    if ( ( [fileManager fileExistsAtPath: resourcePath] == NO ) || ( [fileManager fileExistsAtPath: fullPath] == NO ) )
    {
        NSLog( @"file no exist." );
        return NO;
    }
    
    //  set process call back.
    if ( YES == callback )
    {
        [zipArchive                 setProgressBlock: ^(int percentage, int filesProcessed, unsigned long numFiles, NSString * filename)
         {
             NSLog( @"[%d%%] %d/%ld  %s", percentage, filesProcessed, numFiles, [filename UTF8String] );
         }];
    }
    
    if ( [zipArchive UnzipOpenFile: fullPath ] == NO )
    {
        NSLog( @"cannot open zip file." );
        [zipArchive                 UnzipCloseFile];
        return NO;
    }
    
    zipFiles                        = [zipArchive UnzipFileToMemory];
    if ( nil == zipFiles )
    {
        NSLog( @"cannot unzip file to memory");
        [zipArchive                 UnzipCloseFile];
        return NO;
    }
    
//.    NSLog( @"unzip file in memory : %@", zipFiles );
    [zipArchive                     UnzipCloseFile];
    return YES;
}

//  ------------------------------------------------------------------------------------------------
- ( BOOL ) _UnzipFromDefaultBig5File:(BOOL)toMemory withList:(BOOL)getList
{
    if ( nil == zipArchive )
    {
        return NO;
    }
    
    NSFileManager                 * fileManager;
    NSString                      * resourcePath;
    NSString                      * fullPath;
    NSString                      * destination;
    
    resourcePath                    = [[NSBundle mainBundle] resourcePath];
    fileManager                     = [NSFileManager defaultManager];
    fullPath                        = [resourcePath stringByAppendingPathComponent: [NSString stringWithFormat: @"測試用中文目錄.zip"]];
    if ( ( [fileManager fileExistsAtPath: resourcePath] == NO ) || ( [fileManager fileExistsAtPath: fullPath] == NO ) )
    {
        NSLog( @"file no exist." );
        return NO;
    }
    
    [zipArchive                     setStringEncoding:  NSUTF8StringEncoding];
    [zipArchive                     setSecondStringEncoding: CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)];
    
    
    destination                     = [NSTemporaryDirectory() stringByAppendingString: @"ZipArchive"];
    if ( [zipArchive UnzipOpenFile: fullPath ] == NO )
    {
        NSLog( @"cannot open zip file." );
        [zipArchive                 UnzipCloseFile];
        return NO;
    }
    
    if ( NO == toMemory )
    {
        if ( [zipArchive UnzipFileTo: destination overWrite: YES] == NO )
        {
            NSLog( @"cannot unzip file to destination." );
            [zipArchive             UnzipCloseFile];
            return NO;
        }
    }
    else
    {
        NSDictionary              * zipFiles;
        
        zipFiles                    = nil;
        zipFiles                    = [zipArchive UnzipFileToMemory];
        if ( nil == zipFiles )
        {
            NSLog( @"cannot unzip file to memory");
            [zipArchive             UnzipCloseFile];
            return NO;
        }
        NSLog( @"unzip file in memory : %@", zipFiles );
        
    }
    
    
    if ( YES == getList )
    {
        NSArray                   * fileList;
        fileList                    = [zipArchive getZipFileContents];
        if ( nil != fileList )
        {
            NSLog( @"%@", fileList );
        }
    }
    
    [zipArchive                     UnzipCloseFile];
    NSLog( @"unzip file finish." );
    return YES;
}

//  ------------------------------------------------------------------------------------------------
- ( BOOL ) _ZipFileFromTmp:(BOOL)withDirectory
{
    if ( nil == zipArchive )
    {
        return NO;
    }
    NSFileManager                 * fileManager;
    NSString                      * tempPath;
    
    fileManager                     = [NSFileManager defaultManager];

    //  prework, clear & unzip resource file to tmp.
    tempPath                        = [NSTemporaryDirectory() stringByAppendingString: @"ZipArchive"];;
    if ( ( nil != tempPath ) && ( [fileManager fileExistsAtPath: tempPath] == YES ) )
    {
        NSError                   * error;
        
        error                       = nil;
        [fileManager                removeItemAtPath: tempPath error: &error ];
    }
//    [self                           _UnZipFromDefaultToTmp: NO];
    [self                           _UnzipFromDefaultBig5File: NO withList: NO];
    
    NSArray                       * paths;
    NSString                      * cachePath;
    NSError                       * error;
    BOOL                            isDir;

    paths                           = NSSearchPathForDirectoriesInDomains( NSCachesDirectory, NSUserDomainMask, YES );
    cachePath                       = [paths objectAtIndex:0];
    isDir                           = NO;
    error                           = nil;
    if ( ( [fileManager fileExistsAtPath:cachePath isDirectory:&isDir] == NO ) && ( NO == isDir ) )
    {
        error                       = nil;
        [fileManager                createDirectoryAtPath: cachePath withIntermediateDirectories: NO attributes: nil error: &error];
    }
    
    NSString                      * zipFile;
    NSString                      * fullPath;
    
    paths                           = nil;
    error                           = nil;
    fullPath                        = nil;
    paths                           = [fileManager contentsOfDirectoryAtPath: tempPath error: &error];
    zipFile                         = [cachePath stringByAppendingString: @"/zipfile.zip"];
    if ( [zipArchive CreateZipFile2: zipFile] == NO )
    {
        NSLog( @"cannot create zip file!" );
        return NO;
    }
    
    if ( YES == withDirectory )
    {
        NSInteger                   count;
        
        [zipArchive                 setCompression: ZipArchiveCompressionNone];
//        count                       = [zipArchive addFolderToZip: tempPath pathPrefix: @"JustTest" ];
        count = [zipArchive addFolderToZip: tempPath pathPrefix: @"JustTest" progress: ^(int deepIndex, int pathIndex, int pathTotal, NSString * filename, BOOL isDirSymbolicLink )
        {
            NSLog( @"%d/%d/%d zipping (%d)%s ", deepIndex, pathTotal, pathIndex, isDirSymbolicLink, [filename UTF8String] );
            
        }];
        
        
        [zipArchive                 CloseZipFile2];
        NSLog( @"zip file finish.(%d)", count );
        return YES;
    }
    
    for ( NSString * filename in paths )
    {
        if ( nil == filename )
        {
            continue;
        }
        fullPath                    = [tempPath stringByAppendingFormat: @"/%s", [filename UTF8String]];
        if ( nil == fullPath )
        {
            continue;
        }
        //  because the zip method, just do zip, cannot loop in directory & zip sub files or directory ...
        isDir                           = NO;
        if ( ( [fileManager fileExistsAtPath: fullPath isDirectory: &isDir] == YES ) && ( YES == isDir ) )
        {
            continue;
        }
        
        [zipArchive                 addFileToZip: fullPath newname: filename];
    }
    
    [zipArchive                     CloseZipFile2];
    NSLog( @"zip file finish." );
    return YES;
}


//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------

@end

//  ------------------------------------------------------------------------------------------------



@implementation TableViewController

//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------
#pragma mark overwrite implementation of UIViewController
//  ------------------------------------------------------------------------------------------------
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    //  must register cell class for reuse identifier.
    [(UITableView *)[self           view] registerClass: [UITableViewCell class] forCellReuseIdentifier: @"Cell"];
    
    [self                           _InitAttributes];
}

//  ------------------------------------------------------------------------------------------------
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------
#pragma mark protocol required for UITableViewDataSource.
//  ------------------------------------------------------------------------------------------------
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if ( ( nil == demoList ) || ( [demoList count] == 0 ) )
    {
        return 0;
    }
    return [demoList count];
}

//  ------------------------------------------------------------------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell               * cell;
    
    cell                            = [tableView dequeueReusableCellWithIdentifier: @"Cell" forIndexPath: indexPath];
    if ( nil == cell )
    {
        cell                        = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: @"Cell"];
    }
    
    NSString                      * demoName;
    
    demoName                        = [demoList objectAtIndex: indexPath.row];
    if ( nil != demoName )
    {
        [[cell                      textLabel] setText: demoName];
    }    
    
    // Configure the cell...
    [[cell                          contentView] setBackgroundColor: [UIColor grayColor]];
    
    return cell;
}

//  ------------------------------------------------------------------------------------------------
#pragma mark protocol optional for UITableViewDelegate.
//  ------------------------------------------------------------------------------------------------
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog( @"%@", indexPath );
    ZipArchive                    * zip;
    
    zip                             = [[ZipArchive alloc] init];
    if ( nil == zip )
    {
        return;
    }
    zipArchive                      = zip;
    
    switch ( indexPath.row )
    {
        case 0:     [self           _UnZipFromDefaultToTmp: NO];                    break;
        case 1:     [self           _UnZipFromDefaultToTmp: YES];                   break;
        case 2:
        {
            [zipArchive             setDelegate: self];
            [self                   _UnZipFromDefaultToTmp: YES];
            break;
        }
            
        case 3:     [self           _UnZipFromDefaultToMemory: NO];                 break;
        case 4:     [self           _UnZipFromDefaultToMemory: YES];                break;
        case 5:
        {
            [zipArchive             setDelegate: self];
            [self                   _UnZipFromDefaultToMemory: YES];
            break;
        }
        case 6:     [self           _UnzipFromDefaultBig5File: NO  withList: NO];   break;
        case 7:     [self           _UnzipFromDefaultBig5File: NO  withList: YES];  break;
        case 8:     [self           _UnzipFromDefaultBig5File: YES withList: NO];   break;
            
        case 10:    [self           _ZipFileFromTmp: NO];                           break;
        case 11:    [self           _ZipFileFromTmp: YES];                          break;
        default:
            break;
    }
    
}

//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------
- (void)zipArchive:(ZipArchive *)zipArchive willBeginToDecompressFile:(NSString *)file number:(NSUInteger)fileCount of:(NSUInteger)totalFiles withTotalUncompressedBytes:(NSUInteger)bytes
{
    NSLog( @"begin to decompress file : %s %d/%d", [file UTF8String], fileCount, totalFiles );
}

//  ------------------------------------------------------------------------------------------------
- (void)zipArchive:(ZipArchive *)zipArchive uncompressedBytesWritten:(NSUInteger)bytes
{
    NSLog( @"uncompressed bytes ... %8d", bytes );
}

//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------


@end


//  ------------------------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------




