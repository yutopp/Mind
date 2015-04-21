//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module parsers.charactor;

import std.typecons : staticMap;
import std.range;
import parsers.parser, utility;


// ================================================================================
//
// ================================================================================
template ch(alias Char, T = typeof(Char))
{
    struct chType
    {
        // TODO: support utf-8
        mixin parser!T;

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            if ( !src.empty && front(src) == Char ) {
                mixin (MoveTo!("cast(ValueType)front(src)", "attr"));
                src.popFront;

                return true;

            } else {
                return false;
            }
        }
    }

    auto ch()
    {
        return chType();
    }
}

unittest
{
    {
        //
        alias p = ch!('b');
        //static assert(is(p.ValueType == char));

        //assert(parse!p("b") == PassTest!('b'));
    }
}


// ================================================================================
//
// ================================================================================
// like [A-Z]
template charRange(alias Begin, alias End)
{
    static assert(is(typeof(Begin) == typeof(End)));
    static if ( Begin == End ) {
        alias charRange = ch!Begin;     // or ch!End

    } else static if ( Begin < End ) {
        struct charRangeType
        {
            mixin parser!(typeof(Begin));   // or typeof(End)

            static bool parse(R, Context, Attr)
                (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
            {
                if ( !src.empty && Begin <= front(src) && front(src) <= End ) {
                    mixin (MoveTo!("cast(ValueType)front(src)", "attr"));
                    src.popFront;

                    return true;

                } else {
                    return false;
                }
            }
        }

        auto charRange()
        {
            return charRangeType();
        }

    } else {
        //
        static assert(false, "expect: Begin <= End");
    }
}


// ================================================================================
//
// ================================================================================
// like [a-zA-Z0-9_]
// short notation for this
template charRangeSeq(Ranges...)
{
    import std.traits;
    import operators.alternative;

    template convertToChars(alias R)
    {
        static if ( isArray!(typeof(R)) ) {
            static if ( R.length == 2 ) {
                // form ['A', 'B']
                alias convertToChars = charRange!(R[0], R[1]);

            } else static if ( R.length == 1 ) {
                // form ['A'], so same as 'A' (is it good??)
                alias convertToChars = convertToChars!(R[0]);

            } else {
                static assert(false);
            }

        } else {
            // form 'A'
            alias convertToChars = ch!R;
        }
    }

    alias CharSeq = staticMap!(convertToChars, Ranges);

    // body of this parser
    alias charRangeSeq = alternative!CharSeq;
}

unittest
{
    import test;

    {
        immutable input = "_";

        alias p = charRangeSeq!(['a', 'z'], ['A',  'Z'], ['0', '9'], '_');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).passTest!('_'));
    }

    {
        immutable input = "A";

        alias p = charRangeSeq!(['a', 'z'], ['A',  'Z'], ['0', '9'], '_');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).passTest!('A'));
    }
}
