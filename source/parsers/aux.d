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
import parsers.parser, utility;


// ================================================================================
//
// ================================================================================
template attr(alias Val)
{
    struct attrType
    {
        mixin parser!(typeof(Val));

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            mixin (MoveTo!("Val", "attr"));

            return true;
        }
    }

    auto attr()
    {
        return attrType();
    }
}


// ================================================================================
//
// ================================================================================
private struct epsType
{
    mixin parser!Unused;

    static bool parse(R, Context, Attr)
        (ref R, ref Context, ref Attr) if ( isInputRange!R )
    {
        return true;
    }
}

auto eps()
{
    return epsType();
}


// ================================================================================
//
// ================================================================================
private struct eoiType
{
    mixin parser!Unused;

    static bool parse(R, Context, Attr)
        (ref R src, ref Context, ref Attr) if ( isInputRange!R )
    {
        return src.empty;
    }
}

auto eoi()
{
    return eoiType();
}
