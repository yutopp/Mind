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
template sequence(Parsers...) if (Parsers.length > 0)
{
    alias tape = sequence_folder!Parsers;
    alias Index = tape.Index;
    alias Actions = tape.Actions;

    struct sequenceType
    {
        mixin parser!(tape.ValueType);

        static bool parse(R, Context, Attr)
            (ref R src, ref Context ctx, ref Attr attr) if ( isInputRange!R )
        {
            auto before = src.save;
            scope(failure) src = before;

            static if ( !is(Attr == Unused) && __traits(compiles, tape.SeqTupleExpandable) ) {
                // attr is Tuple!
                foreach(i, Parser; Parsers) {
                    if ( !seq_func!(Parsers[i], Actions[i])(src, ctx, attr.tupleof[Index[i]]) ) {
                        src = before;   // revert iterator
                        return false;
                    }
                }

            } else {
                // attr is normal value
                foreach(i, Parser; Parsers) {
                    if ( !seq_func!(Parsers[i], Actions[i])(src, ctx, attr) ) {
                        src = before;   // revert iterator
                        return false;
                    }
                }
            }

            return true;
        }
    }

    auto sequence()
    {
        return sequenceType();
    }
}

unittest
{
    import std.stdio;
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    {
        immutable input = "a";

        alias p = sequence!(ch!'a');
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).passTest!('a'));
    }

    {
        immutable input = "111a222";

        alias p1 = repeatMore1!(ch!'1');
        alias p2 = ch!'a';
        alias p3 = repeatMore1!(ch!'2');
        alias p = sequence!(p1, p2, p3);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char[]));
        assert(parse!p(input).passTest!(['1', '1', '1', 'a', '2', '2', '2']));
    }

    {
        immutable input = "abc";

        alias p1 = ch!'a';
        alias p2 = attr!42;
        alias p3 = ch!'b';
        alias p4 = ch!'c';
        alias p = sequence!(p1, p2, p3, p4);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == Tuple!(char, int, char[])));
        assert(parse!p(input).passTest!(tuple('a', 42, ['b', 'c'])));
    }

    {
        immutable input = "1";

        alias p = sequence!(ch!'1', eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, parse!p(input));

        static assert(is(p.ValueType == char));
        assert(parse!p(input).passTest!('1'));
    }
}


private:
template seq_func(alias Parsers, alias Action, R, Context, Attr)
{
    bool seq_func(ref R src, ref Context ctx, ref Attr attr)
    {
        static if ( Action == Mode.assign ) {
            if ( !Parsers.parse(src, ctx, attr) ) {
                return false;
            }

        } else static if ( Action == Mode.append ) {
            if ( !parseIntoContainer!(Parsers)(src, ctx, attr) ) {
                return false;
            }

        } else static if (Action == Mode.unused ){
            auto unused = Unused();
            if ( !Parsers.parse(src, ctx, unused) ) {
                return false;
            }

        } else {
            //pragma(msg, Action);
            static assert(false);
        }

        return true;
    }
}


private:

enum Mode {
    unused,
    assign,
    append,
}
alias Action = Mode;

template seq_tail(alias ParserA)
{
    alias ValueType = GetValueType!ParserA;

    static if ( is(ValueType == Unused) ) {
        immutable Index = [-1];
        immutable Actions = [Action.unused];
    } else {
        immutable Index = [0];
        immutable Actions = [Action.assign];
    }
}

template seq2(alias ParserA, alias ParserB)
{
    import std.algorithm;

    auto replaceToAppendActions(R)(R range) {
        return range.replaceFirst([Action.assign], [Action.append]);
    }

    //pragma(msg, "====== parserB");
    //pragma(msg, ParserB.ValueType);
    //pragma(msg, ParserB.Index);
    //pragma(msg, ParserB.Actions);
    //pragma(msg, "==============");

    alias PTa = GetValueType!ParserA;
    alias PTb = GetValueType!ParserB;

    static if ( is(PTa == Unused) && is(PTb == Unused) ) {
        // a: Unused, b: Unused     --> Unused
        alias value_type = Unused;

        immutable mode = [Mode.unused] ~ ParserB.Actions;
        immutable index = [-1] ~ ParserB.Index;

    } else static if ( is(PTa == Unused) || is(PTb == Unused) ) {
        // a: A, b: Unused          --> A
        // a: Unused, b: B          --> B
        static if ( is(PTb == Unused) ) {
            alias value_type = PTa;
            immutable mode = [Mode.assign] ~ ParserB.Actions;
            immutable index = [0] ~ ParserB.Index;

        } else {
            alias value_type = PTb;
            immutable mode = [Mode.unused] ~ ParserB.Actions;
            immutable index = [-1] ~ ParserB.Index;
        }

    } else static if ( is(PTa == PTb) ){
        // a: A[], b: A[]           --> A[]
        // a: A, b: A               --> A[]
        static if (isDynamicArray!PTa && isDynamicArray!PTb) {
            static assert( is(ForeachType!PTa == ForeachType!PTb) );
            //pragma(msg, "a: A[], b: A[]");

            alias element_type = ForeachType!PTa; // or ForeachType!PTb;

        } else {
            //pragma(msg, "a: A, b: A");

            alias element_type = PTa; // or PTb
        }

        alias value_type = element_type[];

        immutable mode = [Mode.append] ~ ParserB.Actions.replaceToAppendActions;
        immutable index = [0] ~ ParserB.Index;

    } else {
        // a: A[], b: A             --> A[]
        // a: A, b: A[]             --> A[]
        // a: A, b: B               --> Tuple!(A, B)
        // a: A, b: Tuple(A, B)     --> Tuple!(A[], B[])
        // a: A, b: Tuple(A[], B)   --> Tuple!(A[], B[])
        static if (isDynamicArray!PTa || isDynamicArray!PTb) {
            static if ( isDynamicArray!PTa && is(ForeachType!PTa == PTb) ) {
                //pragma(msg, "a: A[], b: A");

                alias element_type = ForeachType!PTa; // or PTb

                alias value_type = element_type[];
                immutable mode = [Mode.append] ~ ParserB.Actions.replaceToAppendActions;
                immutable index = [0] ~ ParserB.Index;

            } else static if( isDynamicArray!PTb && is(PTa == ForeachType!PTb) ) {
                //pragma(msg, "a: A, b: A[]");

                alias element_type = ForeachType!PTb; // or PTa

                alias value_type = element_type[];
                immutable mode = [Mode.append] ~ ParserB.Actions.replaceToAppendActions;
                immutable index = [0] ~ ParserB.Index;

            } else {
                // tuple
                mixin make_tuple;
            }

        } else {
            // tuple
            mixin make_tuple;
        }

        mixin template make_tuple()
        {
            static assert( !is(PTa == PTb) );
            //pragma(msg, "make_tuple");
            //pragma(msg, "A: " ~ PTa.stringof);
            //pragma(msg, "B: " ~ PTb.stringof);
            immutable f = function int(int a) => (a != -1) ? (a + 1) : a;

            static if ( __traits(compiles, ParserB.SeqTupleExpandable) ) {
                //pragma(msg, "!! B is tuple!!!");
                //pragma(msg, ParserB.SeqTupleExpandable);
                alias right_tuple_t = ParserB.SeqTupleExpandable;
                //pragma(msg, right_b.length);

                //pragma(msg, "index:");
                //pragma(msg, ParserB.Index);
                //pragma(msg, ParserB.Actions);

                alias LeftElem = right_tuple_t[0];
                //pragma(msg, LeftElem);

                static if ( is(PTa == LeftElem) ) {
                    //pragma(msg, "a: A  b: Tuple!(A, B)  -> Tuple!(A[], B)");
                    immutable index = [0] ~ ParserB.Index;
                    immutable mode = [Action.append, Action.append] ~ ParserB.Actions[1..$];

                    alias type_tuple = TypeTuple!(PTa[], right_tuple_t[1..$]);

                } else static if( isDynamicArray!LeftElem && is (PTa == ForeachType!LeftElem) ) {
                    //pragma(msg, "a: A  b: Tuple!(A[], B)-> Tuple!(A[], B)");
                    immutable index = [0] ~ ParserB.Index;
                    immutable mode = [Action.append] ~ ParserB.Actions;

                    alias type_tuple = TypeTuple!(right_tuple_t);

                } else {
                    //pragma(msg, "a: A  b: B             -> Tuple!(A, B)");
                    immutable index = [0] ~ ParserB.Index.map!f.array;
                    immutable mode = [Mode.assign] ~ ParserB.Actions;

                    alias right_b = right_tuple_t;

                    alias type_tuple = TypeTuple!(PTa, right_b);
                }

            } else {
                // right hand is not tuple
                //pragma(msg, ParserB.Index.length);
                static assert(ParserB.Index.length > 0);

                static if ( ParserB.Index.length == 1 ) {
                    //pragma(msg, "init");
                    immutable index = [0] ~ ParserB.Index;
                    immutable mode = [Mode.assign] ~ ParserB.Actions;

                } else {
                    //pragma(msg, "dup");
                    immutable index = [0] ~ ParserB.Index.map!f.array;
                    immutable mode = [Mode.assign] ~ ParserB.Actions;
                }

                // merge tuple type
                alias type_tuple = TypeTuple!(PTa, PTb);
            }

            //pragma(msg, "tuples: " ~ type_tuple.stringof);

            alias value_type = Tuple!type_tuple;
        }
    }

    static if ( __traits(compiles, ParserA.SeqTupleExpandable) ) {
        static assert(false, "seq2 is not able to be nested right hand");
    }

    //
    alias ValueType = value_type;
    alias Index = index;
    alias Actions = mode;

    static if ( __traits(compiles, type_tuple) ) {
        alias SeqTupleExpandable = type_tuple;
    }

    //pragma(msg, "====== instance");
    //pragma(msg, ValueType);
    //pragma(msg, Index);
    //pragma(msg, Actions);
}


unittest
{
    import std.stdio;
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    {
        // a: A, b: B               --> Tuple!(A, B)
        alias p = seq2!(attr!42, seq_tail!(ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int, char)));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.assign, Action.assign]);
    }

    {
        // a: A, b: Unused          --> A
        alias p = seq2!(attr!42, seq_tail!eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == int));
        static assert(p.Index == [0, -1]);
        static assert(p.Actions == [Action.assign, Action.unused]);
    }

    {
        // a: Unused, b: B          --> B
        alias p = seq2!(eps, seq_tail!(attr!42));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == int));
        static assert(p.Index == [-1, 0]);
        static assert(p.Actions == [Action.unused, Action.assign]);
    }

    {
        // a: Unused, b: Unused     --> Unused
        alias p = seq2!(eps, seq_tail!eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Unused));
        static assert(p.Index == [-1, -1]);
        static assert(p.Actions == [Action.unused, Action.unused]);
    }

    {
        // a: A, b: A               --> A[]
        alias p = seq2!(ch!'a', seq_tail!(ch!'b'));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }

    {
        // a: A[], b: A             --> A[]
        alias p = seq2!(repeatMore1!(ch!'a'), seq_tail!(ch!'c'));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }

    {
        // a: A, b: A[]             --> A[]
        alias p = seq2!(ch!'c', seq_tail!(repeatMore1!(ch!'a')));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }

    {
        // a: A[], b: A[]           --> A[]
        alias p = seq2!(repeatMore1!(ch!'a'), seq_tail!(repeatMore1!(ch!'a')));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }


    // complex
    {
        // char, int, char[]
        alias p = seq2!(attr!'a', seq2!(attr!42, seq2!(attr!'m', seq_tail!(ch!'j'))));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(char, int, char[])));
        static assert(p.Index == [0, 1, 2, 2]);
        static assert(p.Actions == [Action.assign, Action.assign, Action.append, Action.append]);
    }

    // complex
    {
        // int[], char[]
        alias p = seq2!(attr!42, seq2!(attr!42, seq2!(attr!'m', seq_tail!(ch!'j'))));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int[], char[])));
        static assert(p.Index == [0, 0, 1, 1]);
        static assert(p.Actions == [Action.append, Action.append, Action.append, Action.append]);
    }

    // complex
    {
        // int, double, int, char[]
        alias p = seq2!(attr!42, seq2!(attr!(3.14), seq2!(attr!42, seq2!(attr!'m', seq_tail!(ch!'j')))));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int, double, int, char[])));
        static assert(p.Index == [0, 1, 2, 3, 3]);
        static assert(p.Actions == [Action.assign, Action.assign, Action.assign, Action.append, Action.append]);
    }

    // complex
    {
        // int[], char[]
        alias p = seq2!(attr!42, seq2!(attr!42, seq2!(attr!42, seq2!(attr!'m', seq_tail!(ch!'j')))));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int[], char[])));
        static assert(p.Index == [0, 0, 0, 1, 1]);
        static assert(p.Actions == [Action.append, Action.append, Action.append, Action.append, Action.append]);
    }

    // complex
    {
        // int[], double, char[]
        alias p = seq2!(attr!42, seq2!(attr!42, seq2!(attr!(3.14), seq2!(attr!'m', seq_tail!(ch!'j')))));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int[], double, char[])));
        static assert(p.Index == [0, 0, 1, 2, 2]);
        static assert(p.Actions == [Action.append, Action.append, Action.assign, Action.append, Action.append]);
    }

    {
        // char[] with unused
        alias p = seq2!(ch!'a', seq2!(eps, seq_tail!(ch!'b')));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, -1, 0]);
        static assert(p.Actions == [Action.append, Action.unused, Action.append]);
    }

    {
        // char int with unused
        alias p = seq2!(ch!'a', seq2!(eps, seq_tail!(attr!42)));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(char, int)));
        static assert(p.Index == [0, -1, 1]);
        static assert(p.Actions == [Action.assign, Action.unused, Action.assign]);
    }

    {
        // int with unused
        alias p = seq2!(eps, seq2!(eps, seq_tail!(attr!42)));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == int));
        static assert(p.Index == [-1, -1, 0]);
        static assert(p.Actions == [Action.unused, Action.unused, Action.assign]);
    }

    {
        // int with unused
        alias p = seq2!(attr!42, seq2!(eps, seq_tail!(eps)));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == int));
        static assert(p.Index == [0, -1, -1]);
        static assert(p.Actions == [Action.assign, Action.unused, Action.unused]);
    }

    {
        // int with unused
        alias p = seq2!(ch!'a', seq2!(eps, seq2!(attr!42, seq2!(eps, seq_tail!(eps)))));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(char, int)));
        static assert(p.Index == [0, -1, 1, -1, -1]);
        static assert(p.Actions == [Action.assign, Action.unused, Action.assign, Action.unused, Action.unused]);
    }

    {
        // int with unused
        alias p = seq2!(ch!'a', seq2!(eps, seq2!(attr!42, seq2!(eps, seq_tail!(attr!42)))));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(char, int[])));
        static assert(p.Index == [0, -1, 1, -1, 1]);
        static assert(p.Actions == [Action.assign, Action.unused, Action.append, Action.unused, Action.append]);
    }
}


private:

template sequence_folder(Parsers...)
{
    static assert(Parsers.length > 0);

    static if ( Parsers.length == 1 ) {
        alias sequence_folder = seq_tail!(Parsers[0]);
    } else {
        alias sequence_folder = seq2!(Parsers[0], sequence_folder!(Parsers[1..$]));
    }
}


unittest
{
    import std.stdio;
    import test;
    import parsers.charactor, parsers.aux;
    import operators.repeat;

    {
        // a: A, b: B               --> Tuple!(A, B)
        alias p = sequence_folder!(attr!42, ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int, char)));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.assign, Action.assign]);
    }

    {
        // a: A, b: Unused          --> A
        alias p = sequence_folder!(attr!42, eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == int));
        static assert(p.Index == [0, -1]);
        static assert(p.Actions == [Action.assign, Action.unused]);
    }

    {
        // a: Unused, b: B          --> B
        alias p = sequence_folder!(eps, attr!42);
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == int));
        static assert(p.Index == [-1, 0]);
        static assert(p.Actions == [Action.unused, Action.assign]);
    }

    {
        // a: Unused, b: Unused     --> Unused
        alias p = sequence_folder!(eps, eps);
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Unused));
        static assert(p.Index == [-1, -1]);
        static assert(p.Actions == [Action.unused, Action.unused]);
    }

    {
        // a: A, b: A               --> A[]
        alias p = sequence_folder!(ch!'a', ch!'b');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }

    {
        // a: A[], b: A             --> A[]
        alias p = sequence_folder!(repeatMore1!(ch!'a'), ch!'c');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }

    {
        // a: A, b: A[]             --> A[]
        alias p = sequence_folder!(ch!'c', repeatMore1!(ch!'a'));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }

    {
        // a: A[], b: A[]           --> A[]
        alias p = sequence_folder!(repeatMore1!(ch!'a'), repeatMore1!(ch!'a'));
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == char[]));
        static assert(p.Index == [0, 0]);
        static assert(p.Actions == [Action.append, Action.append]);
    }

    // complex
    {
        // char, int, char[]
        alias p = sequence_folder!(attr!'a', attr!42, attr!'m', ch!'j');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(char, int, char[])));
        static assert(p.Index == [0, 1, 2, 2]);
        static assert(p.Actions == [Action.assign, Action.assign, Action.append, Action.append]);
    }

    // complex
    {
        // int[], char[]
        alias p = sequence_folder!(attr!42, attr!42, attr!'m', ch!'j');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int[], char[])));
        static assert(p.Index == [0, 0, 1, 1]);
        static assert(p.Actions == [Action.append, Action.append, Action.append, Action.append]);
    }

    // complex
    {
        // int, double, int, char[]
        alias p = sequence_folder!(attr!42, attr!(3.14), attr!42, attr!'m', ch!'j');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int, double, int, char[])));
        static assert(p.Index == [0, 1, 2, 3, 3]);
        static assert(p.Actions == [Action.assign, Action.assign, Action.assign, Action.append, Action.append]);
    }

    // complex
    {
        // int[], char[]
        alias p = sequence_folder!(attr!42, attr!42, attr!42, attr!'m', ch!'j');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int[], char[])));
        static assert(p.Index == [0, 0, 0, 1, 1]);
        static assert(p.Actions == [Action.append, Action.append, Action.append, Action.append, Action.append]);
    }

    // complex
    {
        // int[], double, char[]
        alias p = sequence_folder!(attr!42, attr!42, attr!(3.14), attr!'m', ch!'j');
        //pragma(msg, p.ValueType);
        //pragma(msg, p.Index);
        //pragma(msg, p.Actions);

        static assert(is(p.ValueType == Tuple!(int[], double, char[])));
        static assert(p.Index == [0, 0, 1, 2, 2]);
        static assert(p.Actions == [Action.append, Action.append, Action.assign, Action.append, Action.append]);
    }
}
