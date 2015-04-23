//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module mind.grammar;

import std.typecons : Unqual;
import std.range : isInputRange;
import mind.parsers.parser, mind.utility;


// ================================================================================
//
// ================================================================================
mixin template grammar(alias EntryParser)
{
    import std.traits;

    mixin parser!(EntryParser.ValueType);

    static bool parse(R, Context, Attr)
        (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
    {
        return ParserType.parse(src, ctx, attr);
    }
}
