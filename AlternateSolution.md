## Main alternate solution

The clear way to avoid having to use my code and still not have an issue with other parsers comes down to expansion. Whenever an external parser (in my case, the TikZ parser) encounters a command that it cannot natively expand, an error is thrown and nothing is compiled. The obvious solution is: 

\NewDocumentCommand{}{}{} --> \NewExpandableDocumentCommand{}{}{}

Or alternatively:

\cs_new_protected:Npn --> \cs_new:Npn

Which will, in most usages, completely resolve all issues with no new problems. However, not all commands can magically become expandable. In my "Example 3:", you could put everything onto one line and skip all of the \pgfmathsetmacro's, allowing \cBezMain to be expanded. The \getCartesian macro, on the other hand, cannot be expanded at all. As a result, changing either or both of the macro definitions to \NewExpandableDocumentCommand{}{}{} would not work. Keep in mind that most macros that one would define for use in TikZ would be substantially simpler and expandable, and so this simple change would likely work, but unfortunately that is not the case with my example.

<br>

### Other workarounds: 

1. The easiest is just eliminating optional arguments and giving everything an "m" arg spec. This will eliminate conflicts, but then you will have much less flexibility
2. To make sure that external parsers do not run alongside the TeX xparse parser, just use them on seperate lines. I could define \cBezMain to save a path into a control sequence and then call that control sequence in a \draw statement on the next line, but quite frankly, I do not like that syntax. No other reason, I genuinely spent however long coding this to occasionally save one line and some awkward syntax.
3. Make a second macro, like \cBezDefault, that works exactly the same except the optional arguments always return their default values, and the original macro turns the optional arguments into mandatory ones. I do not see the purpose of this solution, if you had time to type "Default," then you could have just provided the default value yourself.