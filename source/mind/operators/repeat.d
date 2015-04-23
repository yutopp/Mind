//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module mind.operators.repeat;

import std.range;
import mind.parsers.parser, mind.utility;


// ================================================================================
//
// ================================================================================
template repeatMore0(alias ParserGen)
{
    alias Parser = toParser!ParserGen;

    struct repeatMore0Type
    {
        mixin parser!(GetValueType!(Parser)[]);

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            while( parseIntoContainer!(Parser)(src, ctx, attr) ) {}
            return true;
        }
    }

    auto repeatMore0()
    {
        return immutable repeatMore0Type();
    }
}

/+
unittest {
    ParserPassTest!(
        repeat_more_0!(ch!'w'),
        "www",
        ['w', 'w', 'w']
        );

    ParserPassTest!(
        repeat_more_0!(ch!'w'),
        "aww",
        []
        );
}
+/


// ================================================================================
//
// ================================================================================
template repeatMore1(alias ParserGen)
{
    alias Parser = toParser!ParserGen;

    struct repeatMore1Type
    {
        mixin parser!(GetValueType!(Parser)[]);

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            if ( !parseIntoContainer!(Parser)(src, ctx, attr) ) return false;

            while( parseIntoContainer!(Parser)(src, ctx, attr) ) {}
            return true;
        }
    }

    auto repeatMore1()
    {
        return immutable repeatMore1Type();
    }
}

/+
unittest {
    ParserPassTest!(
        repeat_more_1!(ch!'w'),
        "www",
        ['w', 'w', 'w']
        );

    ParserFailTest!(
        repeat_more_1!(ch!'w'),
        "aww"
        );
}
+/
