# ZipArchive change log

## Version 1.2.0

7 August 2013

* Fixes bug with folders in zipfiles. Pull request #20 (@lanbozhang)
* Adds "stringEncoding" property for specifying what character encoding to use for interpreting file names inside a zip file. This is used for reading and writing zip files. This now defaults to UTF8, it was previously ASCII.

## Version 1.1.1

3 June 2013

* Added autoreleasepool to unzip for better memory performance (@Wert1go)
* Added support for user specific NSFileManager (@namenu)

## Version 1.1.0

7 April 2013

* Created cocoapod podspec file.
* Updated project settings for Xcode 4.6.1
