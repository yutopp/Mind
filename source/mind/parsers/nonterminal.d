//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module mind.parsers.nonterminal;

import std.range : isInputRange;
import mind.parsers.parser, mind.utility;


// ================================================================================
//
// ================================================================================
template rule(alias Parser)
{
    struct ruleType
    {
        mixin parser!(GetValueType!Parser);

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            immutable b = Parser.parse(src, ctx, attr);

            return b;
        }
    }

    auto rule()
    {
        return ruleType();
    }
}
