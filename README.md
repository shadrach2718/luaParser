# Alternative parser to LaTeX's xparse

In LaTeX3, the xparse algorithm that is built into the kernel allows the user to create custom macros with much greater control over how the arguments to the macro are handled, the main addition of which is the ability to use optional arguments. However, when used in conjunction with certain packages with their own parsers, most notably TikZ, xparse conflicts with the imported parser and fails to allow many features. There are ways to avoid the conflicts, but these workarounds would require awkward syntax changes or multiple additional macro definitions (see the file "AlternateSolution.md" for more). This project is a parsing algorithm written in Lua that replaces the problematic xparse features in a way that works with LuaTeX and will not conflict with external parsers. 

The idea of the code is simple. Say you want to create a macro `\<macroName>` with *n* arguments with individual specifications, and that macro has a definition `<def>`. First, you create a separate macro `\<macroNameInternalVersion>` with the definition `<def>` that accepts *n* mandatory arguments. You then create the macro called `<macroName>` that takes in **no** arguments, but rather only calls the Lua parser. The parser will perform its duties and will place `\<macroNameInternalVersion>` followed by the *n* parsed arguments delimited by curly braces into the TeX input stream. As a result, you see a macro call with the desired argument types, while TeX sees a different macro call with only mandatory arguments, which will prevent conflicts with any external packages or parsers.

**Technical note:** xparse is no longer "independent" from the TeX kernel in LaTeX3. Whenever I mention xparse in this project, I am referring to all of the features in the current kernel that were in the separate xparse package in LaTeX2e before L3 began integration with the kernel. The xparse package ended up being so useful that the macro argument parser was fully built into LaTeX3, making the independent package completely obsolete. In much the same way, I will refer to the current version of LaTeX2e with the L3 programming layer, xparse, and many other features built into the kernel as LaTeX3, even though LaTeX3 does not exist in an independent sense as well.

## Installation

The first subsection explains how to change the compiler to lualatexmk in the VSCode LaTeX workshop extension to allow Lua files to run in your TeX environment. If you already are compiling with support for Lua, then skip the following section

### Changing the Compiler in the VSCode Extension "LaTeX Workshop"

Open your .json file (either for your local directory or your global preferences depending on the scope that you intend to use lualatexmk) and add the following:

```json
"latex-workshop.latex.tools": [
    {
        "name": "lualatexmk",
        "command": "latexmk",
        "args": [
            "-synctex=1",
            "-interaction=nonstopmode",
            "-file-line-error",
            "-lualatex",
            "%DOC%"
        ]
    }
],
"latex-workshop.latex.recipes": [
    {
        "name": "lualatexmk",
        "tools": ["lualatexmk"]
    }
],
"latex-workshop.latex.recipe.default": "lualatexmk"
```
If you already have a `"latex-workshop.latex.tools":` array or a `"latex-workshop.latex.recipes":` array, then simply add the contents here to that array rather than overwriting your curent one.

This will allow usage of Lua files and the luacode package in LaTeX, which is necessary to be able to use this project.

### Adding the File to your Desired Directory

If you intend to use this algorithm in a directory that already has a Lua file, then you can simply copy and paste the contents of the "luaParser.lua" file at the bottom of your current file. All of the functions and global variable names are contained in namespaces, and so there should be no naming conflicts with your current code. There is a section of local variable declarations on lines 5-14 of the code, and on the off chance that you have an identically named variable, then simply find/replace all instances of that specific variable in my code.

If you do not have a current Lua file set up or you would like to keep this project separate from your own work, then download the "luaParser.lua" file and place it in your current directory. Add the following to your LaTeX preamble (before any macro definitions that use this project):

```latex
\usepackage{luacode}

\begin{luacode*}
    dofile("luaParser.lua")
\end{luacode*}
```


## Features

This code is only meant to replace the argument specification and parsing of xparse. The other features, such as `\NewDocumentCommand` or other internal uses are not recreated. For a full background on xparse and how the argument specification works, search for "**LaTeX for authors current version**" in your browser and skim through section 2, as I will assume that you have a basic knowledge of how argument specification works in LaTex3. In the following section, `<t1>` and `<t2>` will be used to represent arbitrary tokens, and `<Default>` will represent a provided default value for the argument.

<br>

### Recreated Argument Specifications and Features

* `m`: for a mandatory argument delimited by curly braces

    Will throw an error if the argument is not found

<br>

* `o`: for an optional argument delimited by square brackets

    Will return the special xparse `\-NoValue-` token if the argument is not found

<br>

* `r<t1><t2>`: for a mandatory argument with an opening delimiter of `<t1>` and a closing delimiter of `<t2>`

    Will throw an error if the argument is not found

<br>

* `d<t1><t2>`: for an optional argument with an opening delimiter of `<t1>` and a closing delimiter of `<t2>`

    Will return the special xparse `\-NoValue-` token if the argument is not found

<br>

* `s`: for an optional star argument "*"

    Will return the special xparse `\BooleanTrue` token if the star is present and the `\BooleanFalse` token if absent

<br>

* `t<t1>`: for an optional single token argument "`<t1>`"

    Will return the special xparse `\BooleanTrue` token if the token is present and the `\BooleanFalse` token if absent

<br>

* `O{<Default>}`: for an optional argument delimited by square brackets

    Will return the specified default value `<Default>` if the argument is not found.

<br>

* `D<t1><t2>{<Default>}`: for an optional argument with an opening delimiter of `<t1>` and a closing delimiter of `<t2>`

    Will return the specified default value `<Default>` if the argument is not found.

<br>

* `!`: Putting this token before an argument specification will cause the code to ignore the next argument if a spacing token is found before the argument.
    
    This should only be used at the end of your argument specification and before optional arguments only, as ignoring mandatory arguments will throw an error. There is nothing in the code to prevent the aforementioned usage cases if you want to enforce more strict formatting requirements, but it is not recommended.

<br>

* `#<n>`: Because of the way TeX handles catcode 6, you **must**  type two hashtags, "##<n>" if the reference is in a default value for an O or D-type argument. Putting two hashtags followed by a number *n* will cause the hashtags and the number to be replaced by the *n*th argument. If you want to reference another argument in the document body, then you only use 1 hashtag
    
    See "Example 2" for more

<br>

### Non-recreated Argument Specifications and Features

Feel free to skip this section:
<br>

* `R<t1><t2>{Default}`: I quite frankly do not understand the need to have a mandatory argument with a defined default value if missing, as the entire concept just seems to be overly generous to incredibly poor code. The entire point of this project is to make optional arguments work, and so if you ever intend to have a custom-delimited argument with a fallback value if absent, there is no reason to not just use the `D` type specification.

<br>

* `v`: This parses an argument verbatim between two identical tokens, which protects from TeX expansion. This parser does not do any expansion in the way that TeX does, and because of the way values are returned, there is nothing more that my project can do to protect verbatim arguments. Because this code strips tokens away from the TeX input stream and returns the tokens in a different format, the conversion of tokens to only catcode 10, 12 and 13 feels unnecessarily risky. If you need an argument to be passed into a macro verbatim, then the standard LaTeX2e macro `\verb` inside of any other argument specification should work just fine

<br>

* `e{<Tokens>}` and `E{<Tokens>}{Defaults}`: While I understand the usecases for these specifications, they were very difficult to implement in an efficient way that did not substantially increase computation time or memory usage due to the number of "moving parts" that needed to be kept track of internally. If you want a similar effect, you can use a combination of `t` followed by `o` arguments specifications and do some conditional logic inside of the macro body to get a similar result (minus the ability to change the order of embellishments).

<br>

* `+`: Prefixing a + before an argument specification allows a "long" argument with line breaks and multiple paragraphs. Keeping in mind that this project is mainly to define macros in-line with other parsers, I feel that allowing long arguments just promotes bad practice of keeping vast amounts of code on one line.

<br>

* `b`: For the same reason as above. This project is meant to be used in-line, and adding entire environments as in-line macro arguments is both bad practice and unnecessary.

<br>

* `l`, `u`, `g`, and `G{<Default>}`: According to the xparse documentation, these are no longer recommended, and I can see why. `l` and `u` are just silly, and the `g` type specifications would require a full parse to see how many arguments are provided and then return back to determine which optional arguments should be provided, which not only unnecessary computation but also visibly confusing in the document body.

<br>

* `>{\Processor} <arg spec char>`: These apply a processing macro to an argument after the argument has been parsed. The main reason that processors are necessary is to avoid putting code in the body of a `\NewExpandableDocumentCommand`. However, if you read the "AlternateSolution.md" file, you would see that this project intends to allow non-expandable commands to interact with other parsers, and so I see no reason not to either use xparse's processors on the internal macro version or simply define and apply a similar processing macro to your argument inside of the macro body.

<br>

## Usage

This section has both a theoretical explaination to explain the concepts and general usage, followed by actual concrete examples for clarity and to show how features interact.

<br>

### Theoretical explaination

Everything delimited by <> represents a spot where you would put your own names and definitions.

1. First, decide on a macro that you want to use. This means deciding on a name, "`<macroName>`, the argument specifications, "`<xargs>` or `<arg specs>`", and the macro's definition, "`<def>`". We will let *n* denote the number of arguments that you want your macro to accept .

<br>

2. Decide on a new macro name for the "internal verion" of the macro. This can be any name provided that it does not refer to any existing macro. This will be your "`<macroNameInternalVersion>`".

<br>

3. Add the following to your document's preamble (do NOT put inside of a `luacode` environment. Can be placed in an `\ExplSyntaxOn` block or a `\makeatletter` block, but does not need to be): 

<br>

```latex
\NewDocumentCommand{\<macroNameInternalVer>}{<n copies of the letter "m">}{
    <def>
}

\directlua{
    luaParsing.argSpec("<macroName>", "<arg specs>")
}

\NewDocumentCommand{\<macroName>}{}{%
  \directlua{luaParsing.parse("<macroName>")}%
}
```

<br>

[Note that LaTeX does not understand what is meant here by "`\<macroNameInternalVer>`" or "`\<macroName>`" as the tokens "<>" have a catcode of 12, meaning they cannot be part of a macro name. This is never an issue in practice as the macro names will not actually contain <>, but in this abstract example, it may cause improper coloring when rendered.]

[There is a note at the bottom of the "Examples" section on the `%` signs that appear in the definition for `<macroName>`]

<br>

4. Repeat for as many macros as you wish to create. Nothing special needs to be done when calling the macros, you just need to write `\<macroName> <arguments>`.

<br>

### Examples

<br>

As previously mentioned, read through "luaParser.tex" for all of the examples shown below, and read through "luaParser.pdf" for the full output of all of the examples

<br>

#### Example 1:

This example showcases the basic use, defining a macro and calling it.



<br>



```latex
\documentclass{minimal}
\usepackage{luacode}

\begin{luacode*}
    dofile("luaParser.lua")
\end{luacode*}





% First macro, takes the sum of a mandatory argument and an optional argument
% returns just the mandatory arg if no optional arg is given

\NewDocumentCommand{\sumTwoNumsIntVer}{m m}{%
  \IfNoValueTF{#2}{#1}{\fpeval{#1 + #2}}
}



\NewDocumentCommand{\sumTwoNums}{}{%
  \directlua{luaParsing.parse("sumTwoNumsIntVer", "m o")}%
}


% Second macro, takes two optional arguments and returns their product
% Arg #2 defaults to 1, Arg #3 defaults to the value of Arg #2 + 1
% If a star is present, it chooses to divide instead of multiply
% Note that the name of the internal macro does not need to be related to the calling macro, but the names should be similar in practical uses for clarity

\NewDocumentCommand{\thisNameCanBeAnything}{mmm}{{%
  \IfBooleanTF{#1}{%
    \def\exponent{-1}%
    \typeout{Evaling (#2) / (#3}
  }{%
    \def\exponent{1}%
    \typeout{Evaling #2 * #3}
  }%
  \fpeval{#2 * ((#3)^\exponent)}%
}}


% Note that two hashtags are required to reference Argument #2
\NewDocumentCommand{\multiplyTwoNums}{}{%
  \directlua{luaParsing.parse("thisNameCanBeAnything", "s O{1} O{##2 + 1}")}%
}









\begin{document}

Example 1:


% Standard use of the first macro
1. The result of 1 + 2 is \sumTwoNums{1}[2]


% Argument #2 becomes \NoValue.
% There are no issues with using the macro in math mode or in a group
2. The result of 1 + <nothing> is {$\sumTwoNums{1}$}


% Arguments can reference each other when called in-document, no matter their order
% Only one hashtag is needed when referencing other arguments in the document
3. The result of 4 + 4 + 4 is \sumTwoNums{#2 + 4}[4]


% Standard use of the second macro
4. The result of 2 * 3 is \multiplyTwoNums[2][3]


% Argument #3 defaults to the value of Argument #2 plus 1
5. The result of 7 * 8 is \multiplyTwoNums[7]


% Argument #2 defaults to 1, Argument #3 defaults to 2
6. The result of 1 / 2 is \multiplyTwoNums*[1]


\end{document}
```













<br>

This will output: 

<br>

```
Example 1:
1. The result of 1 + 2 is 3
2. The result of 1 + <nothing> is 1
3. The result of 4 + 4 + 4 is 12
4. The result of 2 * 3 is 6
5. The result of 7 * 8 is 56
6. The result of 1 / 2 is 0.5
```

<br>

#### Example 2:

<br>

This example shows more uses and different argument specifications:

<br>

```latex
\documentclass{minimal}
\usepackage{luacode, expl3}

\begin{luacode*}
    dofile("luaParser.lua")
\end{luacode*}










% First macro, takes in three words and shows their relation
\NewDocumentCommand{\comparisonWordsNotCalledByUser}{mmm}{
  The base word is \textbf{#1}, the comparative version is \textbf{#2}, and the superlative version is \textbf{#3}.
}


% Note that because the reference to Argument #1 is in a default value, two hashtags must be used
\NewDocumentCommand{\comparisonWords}{}{%
  \directlua{luaParsing.parse("comparisonWordsNotCalledByUser", "r() D(){##1er} D(){##1est}")}%
}

% Second macro, works like the first but in reverse. Takes a superlative form in Arg #2 (represented by (base)est)
% Prints "(#1): (base)est (#1): (base)er (#1): (base) (#3)"
% No spaces between arguments are allowed due to the exclamation mark in the arg specs
% Defining in expl3 for token list manipulation, the code works perfectly in an expl syntax block

\ExplSyntaxOn
\tl_new:N \l_baseWord_tl

\cs_new_protected:Npn \comparisonWordsRevInExpl #1#2#3 {
  % tl_range doesnt expand for some reason, which i learned from writing this
  \tl_set:Ne \l_baseWord_tl {#1:~ \exp_not:n {\tl_range:nnn {#2}{1}{-4}}}
  \tl_use:N \l_baseWord_tl
  \tl_put_left:Nn \l_baseWord_tl {~}
  \tl_put_right:Nn \l_baseWord_tl {er~}
  \tl_use:N \l_baseWord_tl
  \tl_set:Nn \l_tmpb_tl {#1:~#2~#3~}
  \tl_use:N \l_tmpb_tl
}
\ExplSyntaxOff


\NewDocumentCommand{\comparisonWordsRev}{}{%
  \directlua{luaParsing.parse("comparisonWordsRevInExpl", "D<>{Next} r<> !D<>{ Finished.}")}%
}









\begin{document}
Example 2:

% Standard use
1. \comparisonWords(fast)


% Notice that the outermost delimiters only are stripped.
% Spaces between arguments are ignored, but spaces within arguments are kept

2. \comparisonWords(good) ((better ) )      ((pattern break here!) best)


% Standard use
3. \comparisonWordsRev<NextWord><Fastest>< Completed!>


% There is a space between the second and third argument, and the third argument's specification is prefixed with an exclamation
% The parser will ignore the third argument and instead use the default value
4. \comparisonWordsRev<wordz><Quickest> < Completed.>



% The following line will NOT work
% Both the mandatory and the optional argument are delimited by <>
% The parser is unable to tell whether a single argument delimited by <> is the mandatory or optional argument
% It will not try to "interpret" what is meant in such a case. There is no way to tell if the lack of a second argument was a mistake or intentional
% The first <> delimited arg is assigned to the optional argument and then an error is thrown because a mandatory arg is missing
% To avoid this, do not set the delimiters for optional arguments to be the same as mandatory argument delimiters

5. (would produce an error) % \comparisonWordsRev<Slowest>



% In much the same way, it is impossible for the parser to tell that the first argument should default rather than the third
% Which will result in a very skewed output
6. (Skewed output) \comparisonWordsRev<Slowest>< Done.>

\end{document}
```

<br>

This will output (bolding not included):

<br>

```
Example 2:
1. The base word is fast, the comparative version is faster, and the superlative version is fastest.
2. The base word is good, the comparative version is (better ) , and the superlative version is (pattern break here!) best.
3. NextWord: Fast NextWord: Faster NextWord: Fastest  Completed!
4. wordz: Quick wordz: Quicker wordz: Quickest  Finished. <Completed.>
5. (would produce an error)
6. (Skewed output) Slowest:  Do Slowest:  Doer Slowest:  Done. Finished
```

<br>

#### Example 3:

<br>

This is the final example, showing how the Lua parser avoids conflict with the TikZ parser. Because the output is visual and I did not want to upload an extra image file here, the output is only viewable in "luaParser.pdf"

<br>

```latex
\documentclass{minimal}
\usepackage{luacode, expl3, tikz}

% this package is just allowing big fonts to use in the tikz pic, no real importance
\usepackage{lmodern}


\begin{luacode*}
    dofile("luaParser.lua")
\end{luacode*}







% This is the exact macro that I was using when i found the bug

\makeatletter

% as the name suggests, this macro takes in a TikZ point and returns its Cartesian coordinates
% The macro takes in an optional argument in Argument #2, and stores the Cartesian coords in \(#2)X and \(#2)Y
% the astute amongst you would notice that i am using standard xparse here...
% but its not an issue, as getCartesian is only called in a pgfextra block that will not be read by the TikZ parser
% no need to reinvent the wheel, so we'll save some lines by not running the lua code

\NewDocumentCommand{\getCartesian}{m O{gc}}{%
  \begingroup
    \tikz@scan@one@point\pgf@process#1\relax
    \pgfmathsetmacro\PointX{\pgf@x/1cm}\pgfmathsetmacro\PointY{\pgf@y/1cm}%
    \edef\GCName{\expandafter\string#2}%
    \expandafter\xdef\csname\GCName X\endcsname{\PointX}%
    \expandafter\xdef\csname\GCName Y\endcsname{\PointY}%
  \endgroup
}

% This macro takes in a point, an optional angle, and another point to generate a specific type of cubic Bezier path
% For the visual explaination of what curve this macro generates, i made a desmos graph of it while playing around
% https://www.desmos.com/calculator/bz6hypjuv4
% Essentially, the macro creates a Bezier curve such that the "departure" angle from the first point is 180 degrees from the "arrival" angle to the second point

\NewDocumentCommand{\cBezMain}{mmm}{%
  \pgfextra{%
    \getCartesian{(#1)}[pOne]%
    \getCartesian{(#3)}[pTwo]%
    \pgfmathsetmacro{\t}{#2}%
    \pgfmathsetmacro{\bMax}{min(abs(\pOneX-\pTwoX),abs(\pOneY-\pTwoY))}%
    \pgfmathsetmacro{\cBezCOneX}{\bMax*cos(\t)+(\pOneX)}%
    \pgfmathsetmacro{\cBezCOneY}{\bMax*sin(\t)+(\pOneY)}%
    \pgfmathsetmacro{\cBezCTwoX}{-\bMax*cos(\t)+(\pTwoX)}%
    \pgfmathsetmacro{\cBezCTwoY}{-\bMax*sin(\t)+(\pTwoY)}%
    \pgfpathmoveto{\pgfpoint{\pOneX cm}{\pOneY cm}}%
    \pgfpathcurveto%
      {\pgfpoint{\cBezCOneX cm}{\cBezCOneY cm}}%
      {\pgfpoint{\cBezCTwoX cm}{\cBezCTwoY cm}}%
      {\pgfpoint{\pTwoX cm}{\pTwoY cm}}%
  }%
}

\makeatother


\NewDocumentCommand{\cBez}{}{%
  \directlua{luaParsing.parse("cBezMain", "r() O{0} r()")}%
}











\begin{document}

Example 3:


\begin{tikzpicture}
  \useasboundingbox (0,0) rectangle (10,10);
  \draw[help lines] (0,0) grid (10,10);


  % Standard use
  % Note that the macro is called in-line where the TikZ parser is already working
  \draw[line width=7pt] \cBez (0,0) [15] (2.5,10);
  % makes for a nice integral sign :p


  \node[font=\fontsize{35pt}{1pt}\selectfont] (q) at (6,5) {$x^2 dx = \frac13 x^3 + C$};

  % no conflicts with other \draw arguments either
  \draw[color=red!50, ->, dashed, line width=4pt] \cBez (6,1.2) [150] (10, 4.5);

  \node[font=\fontsize{25pt}{1pt}\selectfont] (z) at (6,1) {Important!};

\end{tikzpicture}

\end{document}
```

<br>

Note on percent signs: You may notice that on the end of most macro declaration lines, a percent sign appears. For the most part, these are completely unnecessary, as they just tell TeX to continue reading the next line (which it was going to do anyways). However, the percent signs do prevent extraneous spaces from being added to your macro or your document. This is most important when you are using the ! prefix to an argument specification, as any additional spaces will completely throw off the entire system. I would advise staying in the habit of adding the percent signs to the end of every line, but it is not necessary 

## Other Info

This project is completely free to use. I am always open to collaboration if anyone happens to be passionate about this code. If you encounter any bugs, send me your usage and I will patch this repo.

AI assistance disclosure: All of the example content (.tex and .pdf files, as well as the alternate solution file) and the README was entirely written by me. All of the core code logic, layout, and commentary was also entirely my own ideas. There were a few instances with very persistent bugs where I used AI to find the source of the issue, but only after I had exhausted every other approach. At an absolute maximum, 5% of the code in the .lua file came from AI. 