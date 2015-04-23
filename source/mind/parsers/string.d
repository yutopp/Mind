//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module mind.parsers.string;

import std.typecons : staticMap;
import std.range;
import mind.parsers.parser, mind.utility;
import std.string;

// ================================================================================
//
// ================================================================================
template str(alias String, CharType = dchar)
{
    struct strType
    {
        mixin parser!(typeof(String));

        // ch and sequence like implementation...
        // TODO: fix...
        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            auto before = src.save;
            scope(failure) src = before;

            foreach( CharType Char; String ) {
                if ( src.empty || front(src) != Char ) {
                    src = before;   // revert iterator
                    return false;
                }

                popFront(src);
            }

            static if ( !is(Attr == Unused) ) {
                attr ~= String;
            }

            return true;
        }
    }

    auto str()
    {
        return strType();
    }
}

unittest
{
    import mind.test;

    {
        immutable input = "turamiturami";
        immutable expect = "turami";

        alias p = str!("turami");
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == string));
        assert(parse!p(input).passTest!(expect));
    }

    {
        immutable input = "こんにちはこんにちは";
        immutable expect = "こんにちは";

        alias p = str!("こんにちは");
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == string));
        assert(parse!p(input).passTest(expect));
    }
}
