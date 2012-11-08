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
    STAssertTrue(contents && contents.count == _files.count, @"zip files has right number of contents");
    NSString* outputDir = [self tempDir];
    [zip UnzipFileTo:outputDir overWrite:YES];
    
    NSDirectoryEnumerator* dirEnum = [fm enumeratorAtPath:outputDir];
    NSString* file;
    NSError* error = nil;
    while ((file = [dirEnum nextObject])) {
        count += 1;
        NSString* fullPath = [outputDir stringByAppendingPathComponent:file];
        NSDictionary* attrs = [fm attributesOfItemAtPath:fullPath error:&error];
        STAssertTrue([attrs fileSize] > 0, @"file is not zero length");
    }
    STAssertTrue(count == NUM_FILES, @"files extracted successfully");
}

- (void)testExpandPasswordZipFileCorrectly
{
    // unzip password zip
    NSUInteger count = 0;
    NSFileManager* fm = [NSFileManager defaultManager];
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:_zipFile2 Password:@"password"];
    NSArray* contents = [zip getZipFileContents];
    STAssertTrue(contents && contents.count == _files.count, @"zip files has right number of contents");
    NSString* outputDir = [self tempDir];
    _errorCount = 0;
    zip.delegate = self;
    BOOL ok = [zip UnzipFileTo:outputDir overWrite:YES];
    STAssertTrue(ok, @"unzip should pass with wrong password");
    STAssertTrue(_errorCount == 0, @"no errors");
    NSDirectoryEnumerator* dirEnum = [fm enumeratorAtPath:outputDir];
    NSString* file;
    NSError* error = nil;
    while ((file = [dirEnum nextObject])) {
        count += 1;
        NSString* fullPath = [outputDir stringByAppendingPathComponent:file];
        NSDictionary* attrs = [fm attributesOfItemAtPath:fullPath error:&error];
        STAssertTrue([attrs fileSize] > 0, @"file is not zero length");
    }
    STAssertTrue(count == NUM_FILES, @"files extracted successfully");
}

- (void)testExpandPasswordZipFileWithWrongPassword
{
    // unzip with wrong password
    NSUInteger count = 0;
    NSFileManager* fm = [NSFileManager defaultManager];
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:_zipFile2 Password:@"wrong"];
    NSArray* contents = [zip getZipFileContents];
    STAssertTrue(contents && contents.count == _files.count, @"zip files has right number of contents");
    NSString* outputDir = [self tempDir];
    _errorCount = 0;
    zip.delegate = self;
    BOOL ok = [zip UnzipFileTo:outputDir overWrite:YES];
    STAssertTrue(_errorCount == 1, @"we want the wrong password error reported only once");
    STAssertFalse(ok, @"unzip should fail with wrong password");
    
    NSDirectoryEnumerator* dirEnum = [fm enumeratorAtPath:outputDir];
    NSString* file;
    NSError* error = nil;
    while ((file = [dirEnum nextObject])) {
        count += 1;
        NSString* fullPath = [outputDir stringByAppendingPathComponent:file];
        NSDictionary* attrs = [fm attributesOfItemAtPath:fullPath error:&error];
        STAssertTrue([attrs fileSize] > 0, @"file is not zero length");
    }
    STAssertTrue(count == 0, @"files extracted successfully");
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
        const char* tempName = tempnam("/tmp", "ziptest");
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
    const char* tempName = tempnam("/tmp", "ziparchive");
    BOOL ok;
    NSString* zipPath = [NSString stringWithFormat:@"%s.zip", tempName];
    if (password && password.length > 0) {
        ok = [zip CreateZipFile2:zipPath Password:password];
    } else {
        ok = [zip CreateZipFile2:zipPath];
    }
    STAssertTrue(ok, @"created zip file");
    for (NSString* file in files) {
        ok = [zip addFileToZip:file newname:[file lastPathComponent]];
        STAssertTrue(ok, @"added file to zip archive");
    }
    ok = [zip CloseZipFile2];
    STAssertTrue(ok, @"closed zip file");
    return zipPath;
}


@end
