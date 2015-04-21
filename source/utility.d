//
// Copyright yutopp 2015 - .
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//

struct Unused {}


template MoveTo(string src, string to) {
    enum MoveTo = `
        static if ( is(typeof(` ~ to ~ `) == Unused) ) {
            // pragma(msg, "type of ` ~ to ~ ` is Unused. @[ " ~ __FUNCTION__ ~ " ]");
        } else {
            // pragma(msg, "type of ` ~ to ~ ` is " ~ typeof(` ~ to ~ `).stringof );
            // TODO: fix it to use move
            ` ~ to ~ ` = ` ~ src ~`;
        }
    `;
}


template GetValueType(alias Parser)
{
    alias GetValueType = Parser.ValueType;
}


template isUnused(O) {
    immutable isUnused = is(O == Unused);
}

template isNotUnused(O) {
    immutable isNotUnused = !isUnused!(O);
}


template parseIntoContainer(alias Parser, R, Context, Attr) {
    import std.range;
    static assert(isForwardRange!R);

    //static if ( isContainer... ) {
    bool parseIntoContainer(ref R src, Context ctx, ref Attr attr) {
        static if ( !is(Attr == Unused) ) {
            alias ValueElementType = Parser.ValueType;
            ValueElementType element_attr;
        } else {
            alias ValueElementType = Unused;
            alias element_attr = attr;
        }

        immutable b = Parser.parse!(R, Context, ValueElementType)(src, ctx, element_attr);
        static if ( !is(Attr == Unused) ) {
            if ( b ) {
                attr ~= element_attr;
            }
        }

        return b;
    }
    // }
}

template toParserUnit(alias ParserGen)
{
    import std.traits;
    import std.typecons : Unqual;

    static if ( isCallable!ParserGen ) {
        // all parsers in Mind is aliased as function
        // , so extract ParserType from the function signature.
        alias toParserUnit = Unqual!(ReturnType!ParserGen);

    } else static if ( __traits(compiles, typeof(ParserGen)) ) {
        alias toParserUnit = Unqual!(typeof(ParserGen));

    } else {
        alias toParserUnit = Unqual!ParserGen;
    }
}
alias toParser = toParserUnit;

template toParser(ParserGen...)
{
    import std.typetuple : staticMap;

    alias toParser = staticMap!(toParserUnit, ParserGen);
}
