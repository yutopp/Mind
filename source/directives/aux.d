//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module directives.aux;

import operators.sequence, operators.alternative, operators.repeat;
import parsers.charactor;
import directives.omit;


// ================================================================================
//
// ================================================================================
template skipWrapper(alias Parser, Skipper = repeatMore0!(alternative!(ch!' ')))
{
    alias skipWrapper = sequence!(omit!Skipper, Parser, omit!Skipper);
}
