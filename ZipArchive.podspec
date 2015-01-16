Pod::Spec.new do |s|
  s.name         = "ZipArchive"
  s.version      = "1.4.0"
  s.summary      = "An Objective C class for zip/unzip on iPhone and Mac OS X."
  s.description  = <<-DESC
ZipArchive is an Objective-C class to compress or uncompress zip files, which is base on open source code "MiniZip".

It can be used for iPhone application development, and cocoa on Mac OSX as well.
                    DESC
  s.homepage     = "https://github.com/mattconnolly/ZipArchive"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Unknown Name" => "acsolu@gmail.com", "Matt Connolly" => "matt.connolly@me.com" }
  s.source       = { :git => 'https://github.com/mattconnolly/ZipArchive.git', :tag => '1.4.0' }
  s.source_files = '*.{h,m}', 'minizip/crypt.{h,c}', 'minizip/ioapi.{h,c}', 'minizip/mztools.{h,c}', 'minizip/unzip.{h,c}', 'minizip/zip.{h,c}'
  s.public_header_files = '*.h'
  s.library   = 'z'
  s.requires_arc = false
  s.compiler_flags = '-Dunix'
end
