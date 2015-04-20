//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module operators.predicate;

import std.range : isInputRange, save;
import utility;


// ================================================================================
//
// ================================================================================
template andPred(alias Parser)
{
    struct andPred
    {
        alias ValueType = Unused;

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            auto before = src.save;
            scope(exit) src = before;

            return Parser.parse!(R, Context, Attr)(src, ctx, attr);
        }
    }
}

unittest
{
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    {
        alias p = andPred!(ch!'w');
        //pragma(msg, p.ValueType);

        static assert(is(p.ValueType == Unused));
        assert(parse!p("www").passTest!(Unused()));
    }

    {
        alias p = andPred!(ch!'w');
        //pragma(msg, p.ValueType);

        static assert(is(p.ValueType == Unused));
        assert(parse!p("aww").failTest);
    }
}


// ================================================================================
//
// ================================================================================
template notPred(alias Parser)
{
    struct notPred
    {
        alias ValueType = Unused;

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            auto before = src.save;
            scope(exit) src = before;

            return !Parser.parse!(R, Context, Attr)(src, ctx, attr);
        }
    }
}

unittest
{
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    {
        alias p = notPred!(ch!'w');
        //pragma(msg, p.ValueType);

        static assert(is(p.ValueType == Unused));
        assert(parse!p("www").failTest);
    }

    {
        alias p = notPred!(ch!'w');
        //pragma(msg, p.ValueType);

        static assert(is(p.ValueType == Unused));
        assert(parse!p("aww").passTest!(Unused()));
    }
}
