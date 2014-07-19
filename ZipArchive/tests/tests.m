//
//  tests.m
//  tests
//
//  Created by Matt Connolly on 8/11/12.
//  Copyright (c) 2012 Matt Connolly. All rights reserved.
//

#import "tests.h"
#import "ZipArchive.h"

const NSUInteger NUM_FILES = 10;

@interface tests()
{
    NSArray* _files;
    NSString* _zipFile1; // without password
    NSString* _zipFile2; // with password
    NSUInteger _errorCount;
}
@end

@implementation tests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    chdir("/tmp");
    _files = [self createRandomFiles:NUM_FILES];
    NSLog(@"Files: %@", _files);
    _zipFile1 = [self createZipArchiveWithFiles:_files];
    NSLog(@"created zip: %@", _zipFile1);
    _zipFile2 = [self createZipArchiveWithFiles:_files andPassword:@"password"];
    NSLog(@"created password protected zip: %@", _zipFile2);
}

- (void)tearDown
{
    // Tear-down code here.
    
    NSFileManager* fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:_zipFile1 error:nil];
    [fm removeItemAtPath:_zipFile2 error:nil];
    
    [super tearDown];
}

- (void)testExpandNormalZipFile
{
    // unzip normal zip
    NSUInteger count = 0;
    NSFileManager* fm = [NSFileManager defaultManager];
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:_zipFile1];
    NSArray* contents = [zip getZipFileContents];
    XCTAssertTrue(contents && contents.count == _files.count, @"zip files has right number of contents");
    NSString* outputDir = [self tempDir];
    [zip UnzipFileTo:outputDir overWrite:YES];
    
    NSDirectoryEnumerator* dirEnum = [fm enumeratorAtPath:outputDir];
    NSString* file;
    NSError* error = nil;
    while ((file = [dirEnum nextObject])) {
        count += 1;
        NSString* fullPath = [outputDir stringByAppendingPathComponent:file];
        NSDictionary* attrs = [fm attributesOfItemAtPath:fullPath error:&error];
        XCTAssertTrue([attrs fileSize] > 0, @"file is not zero length");
    }
    XCTAssertTrue(count == NUM_FILES, @"files extracted successfully");
}

- (void)testExpandPasswordZipFileCorrectly
{
    // unzip password zip
    NSUInteger count = 0;
    NSFileManager* fm = [NSFileManager defaultManager];
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:_zipFile2 Password:@"password"];
    NSArray* contents = [zip getZipFileContents];
    XCTAssertTrue(contents && contents.count == _files.count, @"zip files has right number of contents");
    NSString* outputDir = [self tempDir];
    _errorCount = 0;
    zip.delegate = self;
    BOOL ok = [zip UnzipFileTo:outputDir overWrite:YES];
    XCTAssertTrue(ok, @"unzip should pass with wrong password");
    XCTAssertTrue(_errorCount == 0, @"no errors");
    NSDirectoryEnumerator* dirEnum = [fm enumeratorAtPath:outputDir];
    NSString* file;
    NSError* error = nil;
    while ((file = [dirEnum nextObject])) {
        count += 1;
        NSString* fullPath = [outputDir stringByAppendingPathComponent:file];
        NSDictionary* attrs = [fm attributesOfItemAtPath:fullPath error:&error];
        XCTAssertTrue([attrs fileSize] > 0, @"file is not zero length");
    }
    XCTAssertTrue(count == NUM_FILES, @"files extracted successfully");
}

- (void)testExpandPasswordZipFileWithWrongPassword
{
    // unzip with wrong password
    NSUInteger count = 0;
    NSFileManager* fm = [NSFileManager defaultManager];
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:_zipFile2 Password:@"wrong"];
    NSArray* contents = [zip getZipFileContents];
    XCTAssertTrue(contents && contents.count == _files.count, @"zip files has right number of contents");
    NSString* outputDir = [self tempDir];
    _errorCount = 0;
    zip.delegate = self;
    BOOL ok = [zip UnzipFileTo:outputDir overWrite:YES];
    XCTAssertTrue(_errorCount == 1, @"we want the wrong password error reported only once");
    XCTAssertFalse(ok, @"unzip should fail with wrong password");
    
    NSDirectoryEnumerator* dirEnum = [fm enumeratorAtPath:outputDir];
    NSString* file;
    NSError* error = nil;
    while ((file = [dirEnum nextObject])) {
        count += 1;
        NSString* fullPath = [outputDir stringByAppendingPathComponent:file];
        NSDictionary* attrs = [fm attributesOfItemAtPath:fullPath error:&error];
        XCTAssertTrue([attrs fileSize] > 0, @"file is not zero length");
    }
    XCTAssertTrue(count == 0, @"files extracted successfully");
}


-(void) ErrorMessage:(NSString*) msg
{
    _errorCount += 1;
}




- (NSString*)tempDir
{
    const char* template = "/tmp/zipunzip.XXXXXX";
    char name[1000];
    strcpy(name, template);
    mkdtemp(name);
    return [NSString stringWithUTF8String:name];
}



- (NSArray*) createRandomFiles:(int) count
{
    if (count <= 0) return nil;
    NSMutableArray* files = [NSMutableArray arrayWithCapacity:count];
    char buffer[1024];
    for (int i = 0; i < count; i++) {
        char tempName[1000];
        strcpy(tempName, "/tmp/ziptest-XXXXXXXX");
        mkstemp(tempName);
        FILE* fp = fopen(tempName, "wb");
        if (fp) {
            int len = arc4random() % 1000;
            arc4random_buf(buffer, len);
            fwrite(buffer, 1, len, fp);
            fclose(fp);
        }
        [files addObject:[NSString stringWithUTF8String:tempName]];
    }
    return [NSArray arrayWithArray:files];
}

- (NSString*) createZipArchiveWithFiles:(NSArray*)files
{
    return [self createZipArchiveWithFiles:files andPassword:nil];
}

- (NSString*) createZipArchiveWithFiles:(NSArray*)files andPassword:(NSString*)password
{
    ZipArchive* zip = [[ZipArchive alloc] init];
    char tempName[1000];
    strcpy(tempName, "/tmp/ziptest-XXXXXXXX");
    mkstemp(tempName);
    BOOL ok;
    NSString* zipPath = [NSString stringWithFormat:@"%s.zip", tempName];
    if (password && password.length > 0) {
        ok = [zip CreateZipFile2:zipPath Password:password];
    } else {
        ok = [zip CreateZipFile2:zipPath];
    }
    XCTAssertTrue(ok, @"created zip file");
    for (NSString* file in files) {
        ok = [zip addFileToZip:file newname:[file lastPathComponent]];
        XCTAssertTrue(ok, @"added file to zip archive");
    }
    ok = [zip CloseZipFile2];
    XCTAssertTrue(ok, @"closed zip file");
    return zipPath;
}


/**
 This test is for some specific files that cause a crash. The files were posted on
 this issue: https://github.com/mattconnolly/ZipArchive/issues/14
 */
- (void)testForCrashWithSpecificFiles;
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    ZipArchive* theZip = [[ZipArchive alloc] init];
    NSString *theZippedFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                   @"archivedFile.zip"];

    if ([fileManager fileExistsAtPath:theZippedFilePath])
    {
        [fileManager removeItemAtPath:theZippedFilePath error:nil];
    }
    
    [theZip CreateZipFile2:theZippedFilePath Password:@"password"];
    
    NSString* path = [[NSBundle bundleForClass:[self class]] bundlePath];
    NSArray* testFiles = @[@"V3.png", @"V3.xml"];
    for (NSString *fileName in testFiles) {
        NSString* theFilePath = [path stringByAppendingPathComponent:fileName];
        [theZip addFileToZip:theFilePath newname:[theFilePath lastPathComponent]];
    }
    
    [theZip CloseZipFile2];
    NSLog(@"Zip file created at: %@", theZippedFilePath);
}

@end
