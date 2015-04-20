//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module operators.option;

import operators.alternative;
import parsers.aux : eps;


// ================================================================================
//
// ================================================================================
template option(alias Parser)
{
    alias option = alternative!(Parser, eps);
}

unittest
{
    import test;
    import std.typecons : Nullable;
    import parsers.charactor;

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
