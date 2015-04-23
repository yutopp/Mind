//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module parsers.charactor;

import std.typecons : staticMap;
import std.range;
import std.traits : ForeachType, Unqual;
import parsers.parser, utility;


// ================================================================================
//
// ================================================================================
template ch(alias Char, T = typeof(Char))
{
    struct chType
    {
        // TODO: support utf-8
        mixin parser!T;

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            if ( !src.empty && front(src) == Char ) {
                mixin (MoveTo!("cast(ValueType)front(src)", "attr"));
                src.popFront;

                return true;

            } else {
                return false;
            }
        }
    }

    auto ch()
    {
        return chType();
    }
}

unittest
{
    {
        //
        alias p = ch!('b');
        //static assert(is(p.ValueType == char));

        //assert(parse!p("b") == PassTest!('b'));
    }
}


// ================================================================================
//
// ================================================================================
// like [A-Z]
template charRange(alias Begin, alias End)
{
    static assert(is(typeof(Begin) == typeof(End)));
    static if ( Begin == End ) {
        alias charRange = ch!Begin;     // or ch!End

    } else static if ( Begin < End ) {
        struct charRangeType
        {
            mixin parser!(typeof(Begin));   // or typeof(End)

            static bool parse(R, Context, Attr)
                (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
            {
                if ( !src.empty && Begin <= front(src) && front(src) <= End ) {
                    mixin (MoveTo!("cast(ValueType)front(src)", "attr"));
                    src.popFront;

                    return true;

                } else {
                    return false;
                }
            }
        }

        auto charRange()
        {
            return charRangeType();
        }

    } else {
        //
        static assert(false, "expect: Begin <= End");
    }
}


// ================================================================================
//
// ================================================================================
// like [a-zA-Z0-9_]
// short notation for this
template charRangeSeq(C, Ranges...)
{
    import std.traits;
    import std.typecons : Tuple;
    import operators.alternative;

    template convertToParser(alias R)
    {
        static if ( is(typeof(R) == Tuple!(C, C)) ) {
            static if ( R.length == 2 ) {
                // form ['A', 'B']
                alias convertToParser = charRange!(R[0], R[1]);

            } else static if ( R.length == 1 ) {
                // form ['A'], so same as 'A' (is it good??)
                alias convertToParser = convertToParser!(R[0]);

            } else {
                static assert(false);
            }

        } else static if ( is(typeof(R) ==C) ) {
            // form 'A'
            alias convertToParser = ch!R;

        } else {
            static assert(false);
        }
    }

    alias CharSeq = staticMap!(convertToParser, Ranges);

    // body of this parser
    alias charRangeSeq = alternative!CharSeq;
}

unittest
{
    import test;
    import std.typecons : tuple;

    {
        immutable input = "_";

        alias p = charRangeSeq!(char, tuple('a', 'z'), tuple('A',  'Z'), tuple('0', '9'), '_');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).passTest('_'));
    }

    {
        immutable input = "A";

        alias p = charRangeSeq!(char, tuple('a', 'z'), tuple('A',  'Z'), tuple('0', '9'), '_');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).passTest('A'));
    }
}


// ================================================================================
//
// ================================================================================
private template CharRangeGrammar(C = char)
{
    import parsers;
    import directives;

    struct Grammar
    {
        enum entry_ = +unit_ >> eoi;
        enum unit_ = range_ / char_;

        enum range_ = charactor_ ^ omit!(ch!'-') ^ charactor_;
        enum char_ = charactor_;

        enum charactor_ = any;
    }

    enum CharRangeGrammar = Grammar.entry_;

private:
    unittest
    {
        import test;
        import std.typecons : Tuple, tuple;
        import variant.dynamicvariant;

        {
            enum input = "a-z";
            enum expect = tuple('a', 'z');

            enum p = Grammar.range_;
            //pragma(msg, p.ValueType);
            //pragma(msg, parse!p(input));

            static assert(is(p.ValueType == Tuple!(char, char)));
            assert(parse!p(input).passTest(expect));
        }

        {
            enum input = "A-Z";
            enum expect = DynamicVariant!(Tuple!(char, char), char)(tuple('A', 'Z'));

            enum p = Grammar.unit_;
            //pragma(msg, p.ValueType);
            //pragma(msg, parse!p(input));

            static assert(is(p.ValueType == DynamicVariant!(Tuple!(char, char), char)));
            assert(parse!p(input).passTest(expect));
        }

        {
            enum input = "0-9";
            enum expect = [
                DynamicVariant!(Tuple!(char, char), char)(tuple('0', '9'))
                ];

            enum p = Grammar.entry_;
            //pragma(msg, p.ValueType);
            //pragma(msg, parse!p(input));

            static assert(is(p.ValueType == DynamicVariant!(Tuple!(char, char), char)[]));
            assert(parse!p(input).passTest(expect));
        }
    }
}

unittest
{
    import test;
    import std.typecons : Tuple, tuple;
    import variant.dynamicvariant;

    {
        enum input = "A-Za-z_";
        enum expect = [
            DynamicVariant!(Tuple!(char, char), char)(tuple('A', 'Z')),
            DynamicVariant!(Tuple!(char, char), char)(tuple('a', 'z')),
            DynamicVariant!(Tuple!(char, char), char)('_'),
            ];

        enum p = CharRangeGrammar!();
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == DynamicVariant!(Tuple!(char, char), char)[]));
        assert(parse!p(input).passTest(expect));
    }
}

template chRange(alias Str, C = Unqual!(ForeachType!(typeof(Str))))
{
    import std.typecons : Tuple;
    import std.typetuple;
    import parsing;
    import operators.alternative;
    import variant.dynamicvariant;

    template toT(alias V)
    {
        static if ( compareTypeInVariant!(V, Tuple!(C, C)) ) {
            enum val = V.peek!(Tuple!(C, C));
            alias toT = charRange!(val[0], val[1]);

        } else static if ( compareTypeInVariant!(V, C) ) {
            enum val = V.peek!(C);
            alias toT = ch!(val);

        } else {
            static assert(false);
        }
    }

    template toSeq(alias List) if (List.length > 0)
    {
        static if (List.length == 1) {
            alias toSeq = TypeTuple!(toT!(List[0]));
        } else {
            alias toSeq = TypeTuple!(toT!(List[0]), toSeq!(List[1..$]));
        }
    }

    enum result2 = parse!(CharRangeGrammar!C)(Str);
    //static assert(result.successful);

    //enum attr = result2.attr;
    alias sequence = toSeq!(parse!(CharRangeGrammar!C)(Str).attr);

    //
    alias chRange = alternative!sequence;
}

unittest
{
    import test;

    {
        enum input = "b";
        enum expect = 'b';
        alias expect_t = char;

        enum p = chRange!"a-z_";
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == expect_t));
        assert(parse!p(input).passTest(expect));
    }

    /+
    {
        enum s = "[a-z_]";
        enum result = parse!(charRangeGenerator!().Parser)(s);
        static assert(result.successful);

        enum attr = result.attr;
        alias hoge = Hoge!(attr);
        pragma(msg, hoge);
    }

    {
        enum input = "a";
        enum p = toR!"[a-z_]";

        enum result = parse!(p)(input);
        static assert(result.successful);

    }

    {
        {
            enum s = "a-z";
            pragma(msg, parse!(charRangeGenerator!().Parser.range_)(s));
        }
        {
            enum s = "A-Z";
            pragma(msg, parse!(charRangeGenerator!().Parser.range_)(s));
        }
        {
            enum s = "0-9";
            pragma(msg, parse!(charRangeGenerator!().Parser.range_)(s));
        }
    }

    {
        {
            enum s = "a";
            pragma(msg, parse!(charRangeGenerator!().Parser.charactor_)(s));
        }
        {
            enum s = "-";
            pragma(msg, parse!(charRangeGenerator!().Parser.charactor_)(s));
        }
        {
            enum s = "]";
            pragma(msg, parse!(charRangeGenerator!().Parser.charactor_)(s));
        }
    }
    +/
}


// ================================================================================
//
// ================================================================================
private struct anyType(C)
{
    mixin parser!C;

    static bool parse(R, Context, Attr)
        (ref R src, ref Context, ref Attr attr) if ( isInputRange!R )
    {
        if ( src.empty ) {
            return false;
        }

        mixin (MoveTo!("cast(ValueType)front(src)", "attr"));
        src.popFront;

        return true;
    }
}

auto any()
{
    return anyType!(char)();
}

auto any(C)()
{
    return anyType!(C)();
}

unittest
{
    import test;

    {
        immutable input = "_";

        alias p = any;
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).passTest('_'));
    }

    {
        immutable input = "";

        alias p = any;
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).failTest);
    }
}
