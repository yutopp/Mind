//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

public import parsing;


bool passTest(alias V, T)(ParseResult!(T) actual) {
    return actual == ParseResult!(T)(true, V);
}

bool passTest(T, U)(ParseResult!(T) actual, U expect_val) {
    return actual == ParseResult!(T)(true, expect_val);
}

bool failTest(T)(ParseResult!(T) actual) {
    return !actual.successful;
}
