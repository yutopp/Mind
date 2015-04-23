//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

import utility;


struct ParseResult(Attr)
{
    bool successful;
    Attr attr;
}

//
auto parse(alias ParserGen, R)(R input)
{
    alias Parser = toParser!ParserGen;
    alias Attr = GetValueType!Parser;

    return parseImpl!(Parser, Attr)(input);
}

//
auto onlyParse(alias ParserGen, R)(R input)
{
    alias Parser = toParser!ParserGen;
    alias Attr = Unused;

    return parseImpl!(Parser, Attr)(input);
}


private auto parseImpl(alias Parser, Attr, R)(R input) {
    struct Context {
    }
    Context c;

    ParseResult!Attr res;

    //pragma(msg, "parseImpl");
    //pragma(msg, typeof(res.attr));

    immutable b = Parser.parse!(R, Context, Attr)(input, c, res.attr);
    res.successful = b;

    return res;
}
