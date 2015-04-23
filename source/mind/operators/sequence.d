//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module operators.sequence;

import std.traits, std.range;
import std.typecons, std.typetuple;

import parsers.parser, utility;


// ================================================================================
//
// ================================================================================
alias sequence(Parsers...) = sequenceImpl!(seq2Merge, Parsers);
alias sequenceSimple(Parsers...) = sequenceImpl!(seq2Simple, Parsers);


// ================================================================================
//
// ================================================================================
template seq2Merge(alias ParserGenL, alias ParserGenR)
{
    alias ParserL = toParser!ParserGenL;
    alias ParserR = toParser!ParserGenR;

    //pragma(msg, "====== parserB");
    //pragma(msg, ParserB.ValueType);
    //pragma(msg, ParserB.Index);
    //pragma(msg, ParserB.Actions);
    //pragma(msg, "==============");

    alias ValL = GetValueType!ParserL;
    alias ValR = GetValueType!ParserR;

    static if ( is(ValL == Unused) && is(ValR == Unused) ) {
        // a: Unused, b: Unused     --> Unused
        alias value_type = Unused;
        enum merge_base = MergeMode.none;

    } else static if ( is(ValL == Unused) || is(ValR == Unused) ) {
        // a: A, b: Unused          --> A
        // a: Unused, b: B          --> B
        static if ( is(ValR == Unused) ) {
            alias value_type = ValL;

            static if ( __traits(compiles, ParserL.TypeTuple) ) {
                alias type_tuple = ParserL.TypeTuple;
            }

        } else {
            alias value_type = ValR;

            static if ( __traits(compiles, ParserR.TypeTuple) ) {
                alias type_tuple = ParserR.TypeTuple;
            }
        }
        enum merge_base = MergeMode.none;

    } else static if ( is(ValL == ValR) ) {
        // a: A[], b: A[]           --> A[]
        // a: A, b: A               --> A[]
        static if (isDynamicArray!ValL && isDynamicArray!ValR) {
            static assert( is(ForeachType!ValL == ForeachType!ValR) );
            //pragma(msg, "a: A[], b: A[]");

            alias element_type = ForeachType!ValL; // or ForeachType!ValR;

        } else {
            //pragma(msg, "a: A, b: A");

            alias element_type = ValL; // or ValR
        }

        alias value_type = element_type[];
        enum merge_base = MergeMode.left;

    } else {
        // a: A[], b: A             --> A[]
        // a: A, b: A[]             --> A[]
        // a: A, b: B               --> Tuple!(A, B)
        // a: A, b: Tuple(A, B)     --> Tuple!(A[], B)
        // a: A, b: Tuple(A[], B)   --> Tuple!(A[], B)
        // a: Tuple(A, B), b: B     --> Tuple!(A, B[])
        // a: Tuple(A, B[]), b: B   --> Tuple!(A, B[])
        static if (isDynamicArray!ValL || isDynamicArray!ValR) {
            static if ( isDynamicArray!ValL && is(ForeachType!ValL == ValR) ) {
                //pragma(msg, "a: A[], b: A");

                alias element_type = ForeachType!ValL; // or ValR
                alias value_type = element_type[];
                enum merge_base = MergeMode.left;

            } else static if ( isDynamicArray!ValR && is(ValL == ForeachType!ValR) ) {
                //pragma(msg, "a: A, b: A[]");
                alias element_type = ForeachType!ValR; // or ValL
                alias value_type = element_type[];
                enum merge_base = MergeMode.left;

            } else {
                mixin asTuple;
            }

        } else {
            mixin asTuple;
        }

        mixin template asTuple()
        {
            static assert( !is(ValL == ValR) );
            //pragma(msg, "== asTuple");
            //pragma(msg, "L      : " ~ ValL.stringof);
            //pragma(msg, "L merge: " ~ __traits(compiles, ParserL.TypeTuple).stringof);
            //pragma(msg, "R      : " ~ ValR.stringof);
            //pragma(msg, "R merge: " ~ __traits(compiles, ParserR.TypeTuple).stringof);

            static if ( __traits(compiles, ParserL.TypeTuple) && __traits(compiles, ParserR.TypeTuple) ) {
                static assert(false);

            } else {
                static if ( __traits(compiles, ParserL.TypeTuple) ) {
                    alias left_tuple_t = ParserL.TypeTuple;
                    static assert(false);

                } else {
                    alias left_tuple_t = ValL;
                }

                static if ( __traits(compiles, ParserR.TypeTuple) ) {
                    alias rt = ParserR.TypeTuple;
                    alias rt_most_l = rt[0];

                    static if ( isDynamicArray!rt_most_l && is(ValL == ForeachType!rt_most_l) ) {
                        //pragma(msg, "a: A, b: Tuple(A[], B)");
                        alias right_tuple_t = rt[1..$];
                        alias type_tuple = TypeTuple!(rt_most_l, right_tuple_t);
                        enum merge_base = MergeMode.left;

                    } else static if ( is(ValL == rt_most_l) ) {
                        //pragma(msg, "a: A, b: Tuple(A, B)");
                        alias right_tuple_t = rt[1..$];
                        alias type_tuple = TypeTuple!(rt_most_l[], right_tuple_t);
                        enum merge_base = MergeMode.left;

                    } else {
                        //pragma(msg, "a: A, b: Tuple(B, C)");
                        alias right_tuple_t = rt;
                        alias type_tuple = TypeTuple!(left_tuple_t, right_tuple_t);
                        enum merge_base = MergeMode.none;
                    }

                } else {
                    //pragma(msg, "a: ?, b: B");
                    alias right_tuple_t = ValR;
                    alias type_tuple = TypeTuple!(left_tuple_t, right_tuple_t);
                    enum merge_base = MergeMode.none;
                }
            }

            alias value_type = Tuple!type_tuple;
        }
    }

    struct seq2Merge
    {
        mixin parser!value_type;
        mixin parseAsSeq;

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            auto before = src.save;
            scope(failure) src = before;

            //pragma(msg, "[!] parse: " ~ Attr.stringof);

            static if ( __traits(compiles, attr.expand) ) {
                if ( !parseAsSeq(src, ctx, attr.expand) ) {
                    src = before;   // revert iterator
                    return false;
                }

            } else {
                if ( !parseAsSeq(src, ctx, attr) ) {
                    src = before;   // revert iterator
                    return false;
                }
            }

            return true;
        }
    }
}

unittest
{
    import std.stdio;
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    pragma(msg, "=== Sequence Merge ===============================================");

    {
        // a: A, b: B               --> Tuple!(A, B)
        enum input = "b";
        enum expect = tuple(42, 'b');
        alias expect_t = Tuple!(int, char);

        alias p = seq2Merge!(attr!42, ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A, b: Unused          --> A
        enum input = "b";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Merge!(attr!42, eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: Unused, b: B          --> B
        enum input = "b";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Merge!(eps, attr!42);
        //npragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: Unused, b: Unused     --> Unused
        enum input = "";
        enum expect = Unused();
        alias expect_t = Unused;

        alias p = seq2Merge!(eps, eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A, b: A               --> A[]
        enum input = "ab";
        enum expect = ['a', 'b'];
        alias expect_t = char[];

        alias p = seq2Merge!(ch!'a', ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A[], b: A             --> A[]
        enum input = "aab";
        enum expect = ['a', 'a', 'b'];
        alias expect_t = char[];

        alias p = seq2Merge!(repeatMore1!(ch!'a'), ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A, b: A[]             --> A[]
        enum input = "abb";
        enum expect = ['a', 'b', 'b'];
        alias expect_t = char[];

        alias p = seq2Merge!(ch!'a', repeatMore1!(ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A[], b: A[]           --> A[]
        enum input = "aabb";
        enum expect = ['a', 'a', 'b', 'b'];
        alias expect_t = char[];

        alias p = seq2Merge!(repeatMore1!(ch!'a'), repeatMore1!(ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // char, int, char[]
        enum input = "A";
        enum expect = tuple('a', 42, ['b', 'A']);
        alias expect_t = Tuple!(char, int, char[]);

        alias p = seq2Merge!(attr!'a', seq2Merge!(attr!42, seq2Merge!(attr!'b', ch!'A')));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int[], char[]
        enum input = "A";
        enum expect = tuple([42, 72], ['a', 'A']);
        alias expect_t = Tuple!(int[], char[]);

        alias p = seq2Merge!(attr!42, seq2Merge!(attr!72, seq2Merge!(attr!'a', ch!'A')));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int, double, int, char[]
        enum input = "A";
        enum expect = tuple(42, 3.14, 72, ['a', 'A']);
        alias expect_t = Tuple!(int, double, int, char[]);

        alias p = seq2Merge!(attr!42, seq2Merge!(attr!(3.14), seq2Merge!(attr!72, seq2Merge!(attr!'a', ch!'A'))));
        //pragma(msg, p.ValueType.stringof);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int[], char[]
        enum input = "A";
        enum expect = tuple([42, 72, 114], ['a', 'A']);
        alias expect_t = Tuple!(int[], char[]);

        alias p = seq2Merge!(attr!42, seq2Merge!(attr!72, seq2Merge!(attr!114, seq2Merge!(attr!'a', ch!'A'))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int[], double, char[]
        enum input = "A";
        enum expect = tuple([42, 72], 3.14, ['a', 'A']);
        alias expect_t = Tuple!(int[], double, char[]);

        alias p = seq2Merge!(attr!42, seq2Merge!(attr!72, seq2Merge!(attr!(3.14), seq2Merge!(attr!'a', ch!'A'))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // char[] with unused
        enum input = "ab";
        enum expect = ['a', 'b'];
        alias expect_t = char[];

        alias p = seq2Merge!(ch!'a', seq2Merge!(eps, ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // char int with unused
        enum input = "a";
        enum expect = tuple('a', 42);
        alias expect_t = Tuple!(char, int);

        alias p = seq2Merge!(ch!'a', seq2Merge!(eps, attr!42));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Merge!(eps, seq2Merge!(eps, attr!42));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Merge!(attr!42, seq2Merge!(eps, eps));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "a";
        enum expect = tuple('a', 42);
        alias expect_t = Tuple!(char, int);

        alias p = seq2Merge!(ch!'a', seq2Merge!(eps, seq2Merge!(attr!42, seq2Merge!(eps, eps))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "a";
        enum expect = tuple('a', [42, 72]);
        alias expect_t = Tuple!(char, int[]);

        alias p = seq2Merge!(ch!'a', seq2Merge!(eps, seq2Merge!(attr!42, seq2Merge!(eps, attr!72))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // Unused, Unused, Unused!
        enum input = "";
        enum expect = Unused();
        alias expect_t = Unused;

        alias p = seq2Merge!(seq2Merge!(eps, eps), eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // char, Unused, char
        enum input = "az";
        enum expect = ['a', 'z'];
        alias expect_t = char[];

        alias p = seq2Merge!(seq2Merge!(ch!'a', eps), ch!'z');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    pragma(msg, "<<< Sequence Merge ===============================================");
}


// ================================================================================
//
// ================================================================================
template seq2Simple(alias ParserGenL, alias ParserGenR)
{
    alias ParserL = toParser!ParserGenL;
    alias ParserR = toParser!ParserGenR;

    //pragma(msg, "====== parserB");
    //pragma(msg, ParserB.ValueType);
    //pragma(msg, ParserB.Index);
    //pragma(msg, ParserB.Actions);
    //pragma(msg, "==============");

    alias ValL = GetValueType!ParserL;
    alias ValR = GetValueType!ParserR;

    static if ( is(ValL == Unused) && is(ValR == Unused) ) {
        // a: Unused, b: Unused     --> Unused
        alias value_type = Unused;

    } else static if ( is(ValL == Unused) || is(ValR == Unused) ) {
        // a: A, b: Unused          --> A
        // a: Unused, b: B          --> B
        static if ( is(ValR == Unused) ) {
            alias value_type = ValL;

            static if ( __traits(compiles, ParserL.TypeTuple) ) {
                alias type_tuple = ParserL.TypeTuple;
            }

        } else {
            alias value_type = ValR;

            static if ( __traits(compiles, ParserR.TypeTuple) ) {
                alias type_tuple = ParserR.TypeTuple;
            }
        }

    } else {
        // a: A, b: B   -> Tuple!(A, B)
        static if ( __traits(compiles, ParserL.TypeTuple) ) {
            alias left_tuple_t = ParserL.TypeTuple;

        } else {
            alias left_tuple_t = ValL;
        }

        static if ( __traits(compiles, ParserR.TypeTuple) ) {
            alias right_tuple_t = ParserR.TypeTuple;

        } else {
            alias right_tuple_t = ValR;
        }

        alias type_tuple = TypeTuple!(left_tuple_t, right_tuple_t);
        alias value_type = Tuple!type_tuple;
    }

    enum merge_base = MergeMode.none;

    struct seq2Simple
    {
        mixin parser!value_type;
        mixin parseAsSeq;

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            auto before = src.save;
            scope(failure) src = before;

            static if ( __traits(compiles, attr.expand) ) {
                if ( !parseAsSeq(src, ctx, attr.expand) ) {
                    src = before;   // revert iterator
                    return false;
                }

            } else {
                if ( !parseAsSeq(src, ctx, attr) ) {
                    src = before;   // revert iterator
                    return false;
                }
            }

            return true;
        }
    }
}

unittest
{
    import std.stdio;
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    pragma(msg, "=== Sequence Simple===============================================");

    {
        // a: A, b: B               --> Tuple!(A, B)
        enum input = "b";
        enum expect = tuple(42, 'b');
        alias expect_t = Tuple!(int, char);

        alias p = seq2Simple!(attr!42, ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A, b: Unused          --> A
        enum input = "b";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Simple!(attr!42, eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: Unused, b: B          --> B
        enum input = "b";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Simple!(eps, attr!42);
        //npragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: Unused, b: Unused     --> Unused
        enum input = "";
        enum expect = Unused();
        alias expect_t = Unused;

        alias p = seq2Simple!(eps, eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A, b: A               --> Tuple!(A, A)
        enum input = "ab";
        enum expect = tuple('a', 'b');
        alias expect_t = Tuple!(char, char);

        alias p = seq2Simple!(ch!'a', ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A[], b: A             --> Tuple!(A[], A)
        enum input = "aab";
        enum expect = tuple(['a', 'a'], 'b');
        alias expect_t = Tuple!(char[], char);

        alias p = seq2Simple!(repeatMore1!(ch!'a'), ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A, b: A[]             --> Tuple!(A, A[])
        enum input = "abb";
        enum expect = tuple('a', ['b', 'b']);
        alias expect_t = Tuple!(char, char[]);

        alias p = seq2Simple!(ch!'a', repeatMore1!(ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // a: A[], b: A[]           --> Tuple!(A[], A[])
        enum input = "aabb";
        enum expect = tuple(['a', 'a'], ['b', 'b']);
        alias expect_t = Tuple!(char[], char[]);

        alias p = seq2Simple!(repeatMore1!(ch!'a'), repeatMore1!(ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // char, int, char, char
        enum input = "A";
        enum expect = tuple('a', 42, 'b', 'A');
        alias expect_t = Tuple!(char, int, char, char);

        alias p = seq2Simple!(attr!'a', seq2Simple!(attr!42, seq2Simple!(attr!'b', ch!'A')));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int, int, char, char
        enum input = "A";
        enum expect = tuple(42, 72, 'a', 'A');
        alias expect_t = Tuple!(int, int, char, char);

        alias p = seq2Simple!(attr!42, seq2Simple!(attr!72, seq2Simple!(attr!'a', ch!'A')));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int, double, int, char, char
        enum input = "A";
        enum expect = tuple(42, 3.14, 72, 'a', 'A');
        alias expect_t = Tuple!(int, double, int, char, char);

        alias p = seq2Simple!(attr!42, seq2Simple!(attr!(3.14), seq2Simple!(attr!72, seq2Simple!(attr!'a', ch!'A'))));
        //pragma(msg, p.ValueType.stringof);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int, int, int, char, char
        enum input = "A";
        enum expect = tuple(42, 72, 114, 'a', 'A');
        alias expect_t = Tuple!(int, int, int, char, char);

        alias p = seq2Simple!(attr!42, seq2Simple!(attr!72, seq2Simple!(attr!114, seq2Simple!(attr!'a', ch!'A'))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    // complex
    {
        // int, int, double, char, char
        enum input = "A";
        enum expect = tuple(42, 72, 3.14, 'a', 'A');
        alias expect_t = Tuple!(int, int, double, char, char);

        alias p = seq2Simple!(attr!42, seq2Simple!(attr!72, seq2Simple!(attr!(3.14), seq2Simple!(attr!'a', ch!'A'))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // char, char with unused
        enum input = "ab";
        enum expect = tuple('a', 'b');
        alias expect_t = Tuple!(char, char);

        alias p = seq2Simple!(ch!'a', seq2Simple!(eps, ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // char int with unused
        enum input = "a";
        enum expect = tuple('a', 42);
        alias expect_t = Tuple!(char, int);

        alias p = seq2Simple!(ch!'a', seq2Simple!(eps, attr!42));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Simple!(eps, seq2Simple!(eps, attr!42));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "";
        enum expect = 42;
        alias expect_t = int;

        alias p = seq2Simple!(attr!42, seq2Simple!(eps, eps));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "a";
        enum expect = tuple('a', 42);
        alias expect_t = Tuple!(char, int);

        alias p = seq2Simple!(ch!'a', seq2Simple!(eps, seq2Simple!(attr!42, seq2Simple!(eps, eps))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // int with unused
        enum input = "a";
        enum expect = tuple('a', 42, 72);
        alias expect_t = Tuple!(char, int, int);

        alias p = seq2Simple!(ch!'a', seq2Simple!(eps, seq2Simple!(attr!42, seq2Simple!(eps, attr!72))));
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // Unused, Unused, Unused!
        enum input = "";
        enum expect = Unused();
        alias expect_t = Unused;

        alias p = seq2Simple!(seq2Simple!(eps, eps), eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    {
        // char, Unused, char
        enum input = "az";
        enum expect = tuple('a', 'z');
        alias expect_t = Tuple!(char, char);

        alias p = seq2Simple!(seq2Simple!(ch!'a', eps), ch!'z');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    pragma(msg, "<<< Sequence Simple ===============================================");
}


// ================================================================================
//
// ================================================================================
private template sequenceImpl(alias Seq, ParsersGen...) if (ParsersGen.length > 0)
{
    static if ( ParsersGen.length == 1 ) {
        alias sequenceImpl = toParser!(ParsersGen[0]);
    } else {
        alias sequenceImpl = Seq!(sequenceImpl!(Seq, ParsersGen[0..$-1]), ParsersGen[$-1]);
    }
}


// ================================================================================
//
// ================================================================================
private enum MergeMode
{
    none,
    left,
}

private mixin template parseAsSeq()
{
    static if ( __traits(compiles, type_tuple) ) {
        alias TypeTuple = type_tuple;
    }

    private static bool parseAsSeq(R, Context, Attrs...)
        (ref R src, ref Context ctx, ref Attrs attrs) if ( isInputRange!R )
    {
        //pragma(msg, "[+] parseAsSeq === ");
        //pragma(msg, "[+] merge_base: " ~ merge_base.stringof);
        //pragma(msg, "[+] value_type: " ~ ValueType.stringof);
        //pragma(msg, "[+] Attrs     : " ~ Attrs.stringof);

        // left
        static if ( __traits(compiles, ParserL.TypeTuple) ) {
            static assert(__traits(hasMember, ParserL, "parseAsSeq"));
            //pragma(msg, "ParserL : parseAsSeq");

            enum l_length = ParserL.TypeTuple.length;
            //pragma( msg, "l_length: " ~ l_length.stringof );

            static if ( l_length == 1 ) {
                if ( !ParserL.parseAsSeq(src, ctx, attrs) ) {
                    return false;
                }

            } else {
                if ( !ParserL.parseAsSeq(src, ctx, attrs[0..l_length]) ) {
                    return false;
                }
            }

        } else {
            //pragma(msg, "!!! ~~ " ~ typeof(attrs[0]).stringof);
            static if ( is(ParserL.ValueType == Unused) || is(Attrs[0] == Unused) ) {
                auto l_attr = Unused();
                enum l_length = 0;

            } else {
                alias l_attr = attrs[0];
                static if ( merge_base == MergeMode.left ) {
                    enum l_length = 0;

                } else {
                    enum l_length = 1;
                }
            }

            //pragma(msg, "l_attr_s: " ~ typeof(mixin (l_attr_s)).stringof);
            static if ( ParserL.isAppendable!(l_attr) ) {
                //pragma(msg, "append L");
                if ( !ParserL.parseToContainer(src, ctx, l_attr) ) {
                    return false;
                }

            } else {
                //pragma(msg, "assign L");
                if ( !ParserL.parse(src, ctx, l_attr) ) {
                    return false;
                }
            }
        }

        //pragma(msg, "to right");
        //pragma(msg, ValueType);
        //pragma(msg, ParserR.ValueType);
        //pragma(msg, l_length);
        //pragma(msg, ParserR);
        //pragma(msg, merge_base);

        // right
        static if ( __traits(hasMember, ParserR, "parseAsSeq")) {
            if ( !ParserR.parseAsSeq(src, ctx, attrs[l_length..$]) ) {
                return false;
            }

        } else {
            static if ( is(ParserR.ValueType == Unused) || is(Attrs[0] == Unused) ) {
                auto r_attr = Unused();
                enum r_attr_s = "r_attr";

            } else {
                enum r_attr_s = "attrs[l_length]";
            }

            static if ( ParserR.isAppendable!(mixin (r_attr_s)) ) {
                //pragma(msg, "append R");
                if ( !ParserR.parseToContainer(src, ctx, mixin (r_attr_s)) ) {
                    return false;
                }

            } else {
                if ( !ParserR.parse(src, ctx, mixin (r_attr_s)) ) {
                    return false;
                }
            }
        }

        //pragma(msg, "[+] ======");

        return true;
    }
}
