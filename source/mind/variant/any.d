//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

module variant.any;
import std.stdio;


// Please do not use this class directly when you are in CTFE world(some error checkings are excluded...)
struct Any
{
    this(T)(T v)
    {
        value_holder_ = new AnyValueHolder!T(v);
    }

    void opAssign(T)(T rhs)
    {
        value_holder_ = new AnyValueHolder!T(rhs);
    }

    void init(T)(T v)
    {
        //auto vv = new AnyValueHolder!T(v);
        //value_holder_ = vv;
    }

    bool opEquals(ref const Any s) const
    {
        if ( value_holder_ is null && s.value_holder_ is null ) {
            return true;
        }

        if ( value_holder_ is null || s.value_holder_ is null ) {
            return false;
        }

        if ( !__ctfe ) {    // workaround...
            if ( type != s.type ) { // only runtime...
                return false;
            }
        }

        return value_holder_.compare(s.value_holder_);
    }

    auto ref peek(T)() inout {
        assert( isValid );
        if ( !__ctfe ) {    // workaround...
            assert(type == typeid(inout(T)));
        }

        return *cast(inout(T)*)value_holder_.getAddressOfValue();
    }

    @property auto ref type() const
    {
        return value_holder_.getTypeid;
    }

    @property bool isValid() const
    {
        return !( value_holder_ is null );
    }

private:
    AnyValueHolderBase value_holder_;

    class AnyValueHolderBase
    {
        TypeInfo getTypeid() inout { return null; }
        inout(void)* getAddressOfValue() inout { return null; }

        bool compare(ref const AnyValueHolderBase rhs) const { return false; }

        AnyValueHolderBase clone() const { return null; }
    }

    class AnyValueHolder(T) : AnyValueHolderBase
    {
        this() {}

        this(T v) {
            this.value = v;
        }

        override TypeInfo getTypeid() inout {
            return typeid(value);
        }

        override inout(void)* getAddressOfValue() inout {
            return &value;
        }

        override bool compare(ref const AnyValueHolderBase rhs) const {
            return value == (cast(typeof(this))rhs).value;
        }

        T value;
    }
}


unittest {
    {
        Any a;
        a = 10;
        assert(a.peek!int == 10);
    }

    {
        immutable a = Any();
        assert(!a.isValid);
    }

    {
        immutable a = Any("ゴボボ！w");
        assert(a.isValid);
    }

    {
        auto a = Any(42);
        auto b = a;

        a.peek!int = 72;

        // TODO: support deep copy...
        // assert(a.peek!int != b.peek!int);
    }

    {
        const a = Any(42);
        const b = a;

        // assert(!(a is b));
    }

    {
        struct Hoge {
            Any a;
        }

        immutable h = Hoge();
    }

    {
        struct Hoge2 {
            this(T)(T v) {}

            Any a;
        }

        immutable h = Hoge2(72);
    }

    {
        struct Hoge3(Type...) {
            this(T)(T v) { this.a = v; }

        private:
            Any a;
        }

        immutable h = Hoge3!(int, double)(72);
    }

    static assert({
            {
                Any a;
                a = 10;
                assert(a.peek!int == 10);

                a = "turami";
                assert(a.peek!string == "turami");

                a = ['h', 'a', 'g', 'e'];
                assert(a.peek!(char[]) == ['h', 'a', 'g', 'e']);

                a = 3.14f;
                assert(a.peek!float == 3.14);
            }

            {
                immutable a = Any();
                assert(!a.isValid);
            }

            return true;
        }());
}
