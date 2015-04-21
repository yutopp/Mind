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
auto parse(alias Parser, R)(R input)
{
    //pragma(msg, typeof(Parser));
    alias Attr = GetValueType!Parser;

    return parseImpl!(Parser, Attr)(input);
}

//
auto onlyParse(alias Parser, R)(R input)
{
    alias Attr = Unused;

    return parseImpl!(Parser, Attr)(input);
}


private auto parseImpl(alias Parser, Attr, R)(R input) {
    int c;  // TEMP: int as Context

    ParseResult!Attr res;

    immutable b = Parser.parse!(R)(input, c, res.attr);
    res.successful = b;

    return res;
}
