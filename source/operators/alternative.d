//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module operators.alternative;

import std.typecons, std.typetuple;
import std.range;

import utility;
import variant.dynamicvariant;


// ================================================================================
//
// ================================================================================
template alternative(Parsers...)
{
    static assert(Parsers.length > 0);

    alias ValueTypeTuple = staticMap!(GetValueType, Parsers);
    alias NonUnusedValueTypeTuple = Filter!(isNotUnused, ValueTypeTuple);
    alias UniqueValueTypeTuple = NoDuplicates!NonUnusedValueTypeTuple;

    //pragma(msg, ValueTypeTuple);
    //pragma(msg, NonUnusedValueTypeTuple);
    //pragma(msg, UniqueValueTypeTuple);

    static if ( UniqueValueTypeTuple.length == 0 ) {
        alias mode = Mode.unused;

    } else static if ( ValueTypeTuple.length == NonUnusedValueTypeTuple.length ) {
        // Unused is not contained
        //pragma(msg, "Unused is not containd");
        static assert( UniqueValueTypeTuple.length > 0 );

        static if ( UniqueValueTypeTuple.length == 1 ) {
            alias mode = Mode.unique;

        } else {
            alias mode = Mode.variant;
        }

    } else {
        // Unused is containd
        //pragma(msg, "Unused is containd");
        static assert( UniqueValueTypeTuple.length > 0 );

        static if ( UniqueValueTypeTuple.length == 1 ) {
            alias mode = Mode.optional;

        } else {
            alias mode = Mode.variant;
        }
    }

    struct alternative
    {
        static if ( mode == Mode.unused ) {
            alias ValueType = Unused;

        } else static if ( mode == Mode.optional ) {
            alias ValueType = Nullable!(UniqueValueTypeTuple[0]);

        } else static if ( mode == Mode.unique ) {
            alias ValueType = UniqueValueTypeTuple[0];

        } else static if ( mode == Mode.variant ) {
            alias ValueType = DynamicVariant!UniqueValueTypeTuple;
        }

        //pragma(msg, ValueType);

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            foreach( i, Parser; Parsers ) {
                static if ( mode == Mode.unused || is(Attr == Unused) ) {
                    alias ElemType = Unused;
                    ElemType element_attr;

                } else static if ( mode == Mode.optional ) {
                    alias ElemType = UniqueValueTypeTuple[0];
                    ElemType element_attr;

                } else static if ( mode == Mode.unique ) {
                    alias ElemType = UniqueValueTypeTuple[0];
                    ElemType element_attr;

                } else static if ( mode == Mode.variant ) {
                    alias ElemType = ValueTypeTuple[i];
                    ElemType element_attr;
                }

                if ( Parser.parse!(R, Context, ElemType)(src, ctx, element_attr) ) {
                    static if ( !is(ValueTypeTuple[i] == Unused) ) {
                        attr = element_attr;
                    }

                    return true;
                }
            }

            return false;   // not matched
        }
    }
}

private enum Mode
{
    unused,
    optional,
    unique,
    variant
}


unittest
{
    import std.stdio;
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    {
        immutable input = "111";
        auto expect = DynamicVariant!(char[], char)(['1', '1', '1']);

        alias p1 = repeatMore1!(ch!'1');
        alias p2 = ch!'1';
        alias p = alternative!(p1, p2);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == DynamicVariant!(char[], char)));
        assert(parse!p(input).passTest!(expect));
    }

    {
        immutable input = "111222";
        auto expect = DynamicVariant!(char, char[])(['1', '1', '1']);

        alias p1 = ch!'2';
        alias p2 = repeatMore1!(ch!'1');
        alias p = alternative!(p1, p2);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == DynamicVariant!(char, char[])));
        assert(parse!p(input).passTest!(expect));
    }

    {
        immutable input = "111222";
        auto expect = Nullable!char();

        alias p1 = ch!'2';
        alias p2 = eps;
        alias p = alternative!(p1, p2);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == Nullable!char));
        assert(parse!p(input).passTest!(expect));
    }
}
