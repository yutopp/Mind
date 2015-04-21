//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module directives.omit;

import std.range : isInputRange;
import parsers.parser, utility;


// ================================================================================
//
// ================================================================================
template omit(alias ParserGen)
{
    alias Parser = toParser!ParserGen;

    struct omitType
    {
        mixin parser!Unused;    // do not get Attribute

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            auto unused = Unused();   // TODO: fix
            return Parser.parse!(R, Context, ValueType)(src, ctx, unused);
        }
    }

    auto omit()
    {
        return immutable omitType();
    }
}

unittest
{
    import test;
    import parsers.charactor;
    import operators.sequence, operators.repeat;

    {
        alias p1 = repeatMore1!(ch!'1');
        alias p2 = ch!'a';
        alias p3 = repeatMore1!(ch!'2');
        alias p4 = sequence!(p1, p2, p3);

        alias p = omit!(p4);

        assert(parse!p("111a222").passTest!(Unused()));
    }
}
