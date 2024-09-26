/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2023, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import ArgumentParser
import CryptoKit
import Foundation

struct Options: ParsableArguments
{
    @Argument( help: "The directory to traverse."            ) var path:   String
    @Flag(     help: "Display a SHA-256 hash for each file." ) var files = false
    @Flag(     help: "Display the size for each file."       ) var size  = false
}

let options = Options.parseOrExit()
let dir     = URL( filePath: options.path )
var isDir   = ObjCBool( false )
var hasher  = SHA256()

if FileManager.default.fileExists( atPath: dir.path( percentEncoded: false ), isDirectory: &isDir ) == false
{
    print( "Error: The specified path does not exist - \( options.path )" )
    exit( -1 )
}

if isDir.boolValue == false
{
    print( "Error: The specified path is not a directory - \( options.path )" )
}

guard let enumerator = FileManager.default.enumerator( atPath: dir.path( percentEncoded: false ) )
else
{
    print( "Error: Cannot enumerate specified directory - \( options.path )" )
    exit( -1 )
}

struct File
{
    public enum Error: Swift.Error
    {
        case isDirectory
        case doesNotExist
        case cannotRead
    }

    public var url:    URL
    public var sha256: String
    public var size:   Int

    public init( url: URL, globalHasher: inout SHA256 ) throws
    {
        var isDir = ObjCBool( false )

        if FileManager.default.fileExists( atPath: url.path( percentEncoded: false ), isDirectory: &isDir ) == false
        {
            throw Error.doesNotExist
        }

        if isDir.boolValue
        {
            throw Error.isDirectory
        }

        guard let data = try? Data( contentsOf: url ),
              let res  = try? url.resourceValues( forKeys: [ .fileSizeKey ] ),
              let size = res.fileSize
        else
        {
            throw Error.cannotRead
        }

        var hasher = SHA256()

        hasher.update( data: data )
        globalHasher.update( data: data )

        self.url    = url
        self.size   = size
        self.sha256 = hasher.finalize().stringValue
    }
}

let files: [ File ] = enumerator.compactMap
{
    filename in autoreleasepool
    {
        guard let filename = filename as? String
        else
        {
            return nil
        }

        let url = dir.appending( component: filename )

        do
        {
            return try File( url: url, globalHasher: &hasher )
        }
        catch File.Error.isDirectory
        {
            return nil
        }
        catch File.Error.doesNotExist
        {
            print( "Error: File does not exist - \( url.path( percentEncoded: false ) )" )
            exit( -1 )
        }
        catch File.Error.cannotRead
        {
            print( "Error: Cannot read file - \( url.path( percentEncoded: false ) )" )
            exit( -1 )
        }
        catch
        {
            print( "Error: \( error )" )
            exit( -1 )
        }
    }
}
.sorted
{
    $0.url.path( percentEncoded: false ) < $1.url.path( percentEncoded: false )
}

if options.files
{
    files.forEach
    {
        print( $0.url.path( percentEncoded: false ) )
        print( "    - SHA-256: \( $0.sha256 )" )

        if options.size
        {
            print( "    - Size:    \( humanReadableSize( bytes: $0.size ) )" )
        }
    }

    print( "--" )
}

print( "Directory:  \( dir.path( percentEncoded: false ) )" )
print( "SHA-256:    \( hasher.finalize().stringValue )" )

func humanReadableSize( bytes: Int ) -> String
{
    if bytes < 1000
    {
        return "\( bytes ) bytes"
    }
    else if bytes < 1000 * 1000
    {
        return "\( String( format: "%.02f", Double( bytes ) / 1000.0 ) ) KB - \( bytes ) bytes"
    }
    else if bytes < 1000 * 1000 * 1000
    {
        return "\( String( format: "%.02f", ( Double( bytes ) / 1000.0 ) / 1000.0 ) ) MB - \( bytes ) bytes"
    }
    else if bytes < 1000 * 1000 * 1000 * 1000
    {
        return "\( String( format: "%.02f", ( ( Double( bytes ) / 1000.0 ) / 1000.0 ) / 1000.0 ) ) GB - \( bytes ) bytes"
    }
    else
    {
        return "\( String( format: "%.02f", ( ( ( Double( bytes ) / 1000.0 ) / 1000.0 ) / 1000.0 ) / 1000.0 ) ) TB - \( bytes ) bytes"
    }
}
