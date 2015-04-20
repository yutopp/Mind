//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module parsers.aux;

import std.typecons : staticMap;
import std.range;
import utility;


// ================================================================================
//
// ================================================================================
template attr(alias Val)
{
    struct attr {
        alias ValueType = typeof(Val);

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            mixin (MoveTo!("Val", "attr"));

            return true;
        }
    }
}


// ================================================================================
//
// ================================================================================
struct eps
{
    alias ValueType = Unused;

    static bool parse(R, Context, Attr)
        (ref R, Context, ref Attr) if ( isInputRange!R )
    {
        return true;
    }
}


// ================================================================================
//
// ================================================================================
struct eoi {
    import std.range;

    alias ValueType = Unused;

    static bool parse(R, Context, Attr)
        (ref R src, ref Context, ref Attr) if ( isInputRange!R )
    {
        return src.empty;
    }
}
