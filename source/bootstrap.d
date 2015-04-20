import std.stdio;

import std.range : isInputRange;
import std.string;

import std.typecons, std.typetuple;

import utility;
import parsing;

import parsers;
import operators;
import directives;

/*
enum testcase = q{
    program     <- hoge eoi;

    hoge        <- "aaa"
};
*/



enum testcase = q{
    program <- hoge eoi;
};

// bootstrap parser!!

alias MindBootstrap = rule!(rep0!RuleUnit);
alias RuleUnit = rule!(skipWrapper!Identifier);
alias Gen = rule!(repeatMore0!(RuleUnit));

alias Identifier =
    rule!(
        sequence!(
            charRangeSeq!(['a', 'z'], ['A', 'Z'], '_'),
            repeatMore0!(
                charRangeSeq!(['a', 'z'], ['A', 'Z'], ['0', '9'], '_')
                )
            )
        );

alias seq = sequence;
alias rep0 = repeatMore0;

pragma(msg, testcase);
pragma(msg, MindBootstrap.ValueType);
pragma(msg, parse!(MindBootstrap)(testcase));

pragma(msg, Identifier.ValueType);
pragma(msg, parse!(Identifier)("azAZ_09"));
