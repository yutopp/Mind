//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module variant.dynamicvariant;

import std.typetuple;
import std.traits : isInstanceOf;
import variant.any;


//
// Variant interface like Boost.Variant in Boost Libraries.
// But implemented by using Any(not shared buffer), so performance will be not good :(
// This Variant will be useful until std.variant supports CTFE...
// !!! * PROTO TYPE * !!!
//
struct DynamicVariant(Types...)
{
    alias ElementTypes = Types;

    this(T)(T v)
    {
        static if ( staticIndexOf!(T, Types) != -1 ) {
            any_ = v;
            index_ = staticIndexOf!(T, Types);
        } else {
            static assert(false, "Error: " ~ T.stringof ~ " is not included in " ~ Types.stringof);
        }
    }

    void opAssign(T)(T rhs) {
        static if ( staticIndexOf!(T, Types) != -1 ) {
            any_ = rhs;
            index_ = staticIndexOf!(T, Types);
        } else {
            static assert(false, "Error: " ~ T.stringof ~ " is not included in " ~ Types.stringof);
        }
    }

    bool opEquals(R)(auto ref const R s) inout if ( is(R.ElementTypes == Types) ) {
        if ( index_ != s.index_ ) {
            return false;
        }

        return any_ == s.any_;
    }

    auto type() const
    {
        if ( !hasValue ) return null;

        return any_.type;
    }

    bool isSameType(T)() const
    {
        if ( !hasValue ) return false;

        return staticIndexOf!(T, Types) == index_;
    }

    @property bool hasValue() const pure nothrow
    {
        return index_ != -1;
    }

    @property auto ref peek(T)() inout if ( staticIndexOf!(T, Types) != -1 ) {
        version( Debug ) {
            assert(any_.isValid());
            assert(index_ != -1);
        }

        if ( !hasValue ) {
            assert(false);
        }

        return any_.peek!T;
    }

private:
    Any any_;
    int index_ = -1;
}

template compareTypeInVariant(alias V, T) if ( isInstanceOf!(DynamicVariant, typeof(V)) )
{
    enum compareTypeInVariant = V.isSameType!(T);
}


private:
unittest {
    void test() {
        {
            auto v = DynamicVariant!(int, double)(3.3);
            assert(v.peek!double == 3.3);
        }

        {
            auto v = DynamicVariant!(char, char[])(['a', 'b']);
            assert(v.peek!(char[]) == ['a', 'b']);
        }

        {
            auto v = DynamicVariant!(char[], char)(['a', 'b']);
            assert(v.peek!(char[]) == ['a', 'b']);
        }

        {
            auto v = DynamicVariant!(char, char[])(['a', 'b']);
            v = ['a', 'b'];
            assert(v.peek!(char[]) == ['a', 'b']);
            v = 'a';
            assert(v.peek!(char) == 'a');
        }

        {
            auto v1 = DynamicVariant!(char[], char, int)(['a', 'b']);
            auto v2 = DynamicVariant!(char[], char, int)(['a', 'b']);

            assert( v1 == v2 );
            assert( !(v1 != v2) );

            v1 = 'a';
            assert( v1 != v2 );
        }

        {
            immutable v = DynamicVariant!(char[], char, int)(42);
        }

        {
            immutable v = DynamicVariant!(char[], char)(['1', '1', '1']);
        }

        {
            enum b = DynamicVariant!(char[], char)('2');
        }

        {
            // regards another types
            immutable v1 = DynamicVariant!(char[], char)(['1', '1', '1']);
            immutable v2 = DynamicVariant!(char, char[])(['1', '1', '1']);

            assert(!__traits(compiles, v1 == v2));
        }
    }

    //
    test();
    static assert({ test(); return true; }());
}
