//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module mind.parsers.parser;


mixin template parser(AttrType)
{
    alias ValueType = AttrType;

    // =====
    // Aux
    // =====
    static bool isAppendable(alias Attr)()
    {
        /+
        pragma(msg, "???? isAppendable");
        pragma(msg, typeof(this));
        pragma(msg, typeof(this).ValueType);
        pragma(msg, typeof(Attr));
        pragma(msg, __traits(compiles, () => { typeof(this).ValueType v; }));
        pragma(msg, __traits(compiles, (ref typeof(Attr) attr) => {
                    typeof(this).ValueType v;
                    attr ~= v;
                }));
        pragma(msg, "====");
        +/

        return __traits(compiles, (ref typeof(Attr) attr) => {
                typeof(this).ValueType v;
                attr ~= v;
            });
    }

    static bool parseToContainer(R, Context, Attr)
        (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
    {
        import mind.utility;

        return parseIntoContainer!(typeof(this))(src, ctx, attr);
    }

    // =====
    // Operators
    // =====
    // for parser sequence(merge)
    // ">>", left assoc
    auto opBinary(string op, P)(P lhs) inout if ( op == ">>" )
    {
        import std.typecons : Unqual;
        import mind.operators.sequence;

        return sequence!(Unqual!(typeof(this)), Unqual!(typeof(lhs)))();
    }

    // for parser sequence
    // "^", left assoc
    auto opBinary(string op, P)(P lhs) inout if ( op == "^" )
    {
        import std.typecons : Unqual;
        import mind.operators.sequence;

        return sequenceSimple!(Unqual!(typeof(this)), Unqual!(typeof(lhs)))();
    }


    // for parser selection
    // "/"
    auto opBinary(string op, P)(P p) inout if ( op == "/" )
    {
        import std.typecons : Unqual;
        import mind.operators.alternative;

        return alternative!(Unqual!(typeof(this)), Unqual!(typeof(p)))();
    }


    // 0 or more
    // "*"
    auto opUnary(string op)() inout if ( op == "*" )
    {
        import std.typecons : Unqual;
        import mind.operators.repeat;

        return repeatMore0!(Unqual!(typeof(this)))();
    }

    // 1 or more
    // "+"
    auto opUnary(string op)() inout if ( op == "+" )
    {
        import std.typecons : Unqual;
        import mind.operators.repeat;

        return repeatMore1!(Unqual!(typeof(this)))();
    }

    // 0 or 1
    // "-"
    auto opUnary(string op)() inout if ( op == "-" )
    {
        import std.typecons : Unqual;
        import mind.operators.option;

        return option!(Unqual!(typeof(this)))();
    }

    // not predicate
    // "~"
    auto opUnary(string op)() inout if ( op == "~" )
    {
        import std.typecons : Unqual;
        import mind.operators.predicate;

        return notPred!(Unqual!(typeof(this)))();
    }
}

unittest
{

    import mind.test;
    import mind.parsers;
    import std.typecons : Tuple, tuple;

    {
        enum input = "abc";
        enum expect = tuple('a', 'b', 'c');

        enum p = ch!'a' ^ ch!'b' ^ ch!'c';
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == Tuple!(char, char, char)));
        assert(parse!p(input).passTest!(expect));
    }

    {
        enum input = "abc";
        enum expect = ['a', 'b', 'c'];

        enum p = ch!'a' >> ch!'b' >> ch!'c';
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char[]));
        assert(parse!p(input).passTest!(expect));
    }
}
