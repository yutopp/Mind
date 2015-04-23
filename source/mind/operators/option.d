//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module mind.operators.option;

import mind.parsers.parser, mind.utility;
import mind.operators.alternative;
import mind.parsers.aux : eps;


// ================================================================================
//
// ================================================================================
template option(alias ParserGen)
{
    alias Parser = toParser!ParserGen;

    alias option = alternative!(Parser, eps);
}

unittest
{
    import mind.test;
    import std.typecons : Nullable;
    import mind.parsers.charactor;

    {
        immutable input = "www";
        immutable expect = Nullable!char('w');

        alias p = option!(ch!'w');

        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));
        static assert(is(p.ValueType == Nullable!char));
        assert(parse!p(input).passTest!(expect));
    }
}
