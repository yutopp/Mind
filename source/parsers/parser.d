module parsers.parser;


mixin template parser(AttrType)
{
    alias ValueType = AttrType;

    // for parser sequence
    // ">>"
    auto opBinaryRight(string op, P)(P p) inout if ( op == ">>" )
    {
        import std.typecons : Unqual;
        import operators.sequence;

        return sequence!(Unqual!(typeof(p)), Unqual!(typeof(this)))();
    }

    // 0 or more
    // "*"
    auto opUnary(string op)() inout if ( op == "*" )
    {
        import std.typecons : Unqual;
        import operators.repeat;

        return repeatMore0!(Unqual!(typeof(this)))();
    }

    // 1 or more
    // "+"
    auto opUnary(string op)() inout if ( op == "+" )
    {
        import std.typecons : Unqual;
        import operators.repeat;

        return repeatMore1!(Unqual!(typeof(this)))();
    }

    // 0 or 1
    // "-"
    auto opUnary(string op)() inout if ( op == "-" )
    {
        import std.typecons : Unqual;
        import operators.option;

        return option!(Unqual!(typeof(this)))();
    }
}
