#  G60, aka sexagesimal-encoded binary

##  Introduction

Encoding binary data into ASCII is a common need, and usually
includes avoiding “special” characters.  A common encoding,
base64, uses mostly letters (of both cases) and digits.  However,
letters and digits number only 62, whereas base64 relies on six
bits per ASCII character, meaning 64, so two more must be added.
The original spec uses slash `/` and plus `+` (as well as `=` for
padding), but this was troublesome in some domains, such as URLs,
and so variants were created, such as using underscore `_` and dash
`-` instead.  But none of these are trouble-free either.  A purely
alphanumeric encoding would remove all concerns.

There are encodings that use only 5 bits per ASCII character (or
32 distinct characters), the best probably being the Crockford
base-32 encoding.  These can even be case-insensitive because 26+10
is more than 32.  However, the encoding will be longer, and for many
applications one wants more or less the best possible.

**G60** is an encoding that uses 60 distinct ASCII characters,
specifically all letters and digits except for capital `I` and `O`.
Furthermore, it has several useful properties most other encodings
do not.  It can be thought of as rendering binary into base 60, also
known as _sexagesimal_, a number system used by the Sumerians as far
back as 2000 BC.  60 is a nice number because of its large number of
factors, which is leveraged in the design of G60.

Much as the system of encoding decimal digits into four bits is known
as “binary-encoded decimal”, G60 can be called sexagesimal-encoded
binary.

G60 encodes 8 bytes to 11 characters, increasing the length in bytes
by 37.5%, barely more than the 33⅓% for base64, and much less than
the 60% for base-32.

For when avoiding special characters is less of an issue, I created the
encoding [G86](https://github.com/galenhuntington/g86).  G60 supersedes
my previous encoding [G56](https://github.com/galenhuntington/g56).


##  Description (v0.1)

To encode, divide the source binary into blocks of eight bytes.
The last block may need to be padded with zeroes to make a full block;
these serve only as placeholders and will be stripped back off at the
end.  For each block, label the bytes _ABCDEFGH_, with each a number
from 0 to 255.  Divide _D_ into the high bit _Dₕ_, either 0 or 1,
and the low seven bits _Dₗ_, from 0 to 127, and calculate the integer

14·60⁹·_A_ +
3·60⁸·_B_ +
20·60⁶·(2·_C_ + _Dₕ_) +
9·60⁵·_Dₗ_ +
2·60⁴·_E_ + 24·60²·_F_ + 5·60·_G_ + _H_.

This number is then written in base-60 using exactly eleven
“digits” (with leading zeroes if need be), using these characters
as sexagesimal digits:

`0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`

(All letters and numbers but `IO`.)

If _k_ zeroes were initially padded on to make a full block,
_k_+⌊3·_k_/8⌋ (rounded down) `0` characters are removed
from the end, to yield the final encoding.

By inspecting the coefficients, the mapping to integers may be seen
to be collision-free, so this encoding is reversible.

##  Implementation

The integer constructed can be large enough to not fit even into
a 64-bit register.  However, as we shall see, the coefficients are
chosen to facilitate breaking the calculation into small parts.

The above polynomial uses exponents of 60 to show the placement in
base-60, but it may be even easier to see the values written out.
We show how to sum these up, using `00` to `59` as sexagesimal digits:

```
00 14 00 00 00 00 00 00 00 00 00  × A

      03 00 00 00 00 00 00 00 00  × B

            40 00 00 00 00 00 00  × C

            20 00 00 00 00 00 00  × Dₕ
               09 00 00 00 00 00  × Dₗ

                  02 00 00 00 00  × E

                        24 00 00  × F

                           05 00  × G

                              01  × H
```

We sum these to get the final value, which is then encoded into the
above 60-character digit set.

Visually, it is clear the later digits are not affected by the earlier
bytes, an example of effects being “localized”, which also goes
the other way, as discussed below.

To demonstrate this, the Haskell reference implementation in this repo
uses only _16-bit_ variables throughout to both encode and decode G60.


##  Features

G60 has these features:

1.  G60 preserves lexicographic sort order.  This can be useful
for having canonical orderings or for using encoded binary as keys.
When the byte strings are of equal length, this can be achieved simply
by having the alphabet be in ASCII order; however, many encodings,
including base64, do not even do this.  For strings of unequal length,
it is not always so easy.

2.  There is a direct correspondence between the data
length and the encoded data length.  _n_ bytes expands to
_n_+⌈3·_n_/8⌉ (meaning rounding up) characters, or
equivalently ⌈11·_n_/8⌉.

3.  It has the “initial segment property”.  If you have the first
⌈11·_m_/8⌉ bytes of a G60 encoding, you can deduce the
first _m_ bytes of the binary data.  This is actually a consequence
of the above two features.

4.  As noted above, the calculation can be broken into small parts
due to the locality of effects, which will be discussed next.


##  Examples

The string `Hello, world!` (as bytes) has length 13, and so should
expand to 18 characters.  Indeed, it expands to this:

```
Gt4CGFiHehzRzjCF16
```

To see locality in action, compare what `Hella, would???` encodes to:

```
Gt4CGFEHehzRzsCF26RHF
```

Consider next the fractional bits of π.  The first 128 becomes this
22-character string:

```
8TAB1GT5CjX4TGY6u6kxc8
```

This representation of 128 bits competes with UUIDs (36 characters),
base-32 (26 characters), and base64 (24 characters with padding,
22 without).

This is an exact number of blocks, so we can directly extend to add
the next 128 bits:

```
8TAB1GT5CjX4TGY6u6kxc8eGTdR7P3g8U1uLn3jsXM2H
```

This is one character longer than base64 without padding.

##  Design

This section is a deeper dive into how this encoding was designed.

###  Encoding sizes

An encoding that uses _χ_ characters requires at least an average
of log(256)/log(_χ_) characters to encode one byte.  When _χ_=64,
this is 3/2, which is what base64 does.  For G60 this ratio is about
1.354, which is less than 11/8, and thus we can encode 8 bytes in
11 characters.

We can compare other options.  For instance with only _χ_=57 the ratio
is still below 11/8 (but then the other features cannot be achieved).
And with _χ_=60, we can get better ratios with large block sizes,
as for example 19/14 is about 1.357.

Finally, we can go up further, say to _χ_=62, where we can get
marginally better ratios such as 23/17.

Such large blocks can be unwieldy, however, and, as explained below,
we’d miss key features.

###  Locality 1

Let us consider a miniature example: we want to encode three letters
as a single number written in decimal.  To parallel the above we’ll
consider them numbers _ABC_ each from 0 to 25.  The obvious most
compact encoding would be 26²·_A_+26·_B_+_C_, yielding a five-digit
number (with perhaps leading zeroes).

To encode `pzz`, using 15 for `p`, etc., we’d get 10815.  Then `qaa`
is 10816.  So, we cannot always deduce even the first letter without
knowing all the digits.  As the block size grows, avoiding this level
of dependency becomes increasingly helpful (see above comments about
integer sizes).

Another issue arises when encoding a partial block.  Say only `q`
is left in the final block.  How do we encode it?  If we set _B_
and _C_ to zero, we again get 10816.  But we’d like to use fewer
than five digits in this case, in order to (a) avoid a longer
encoding than necessary, (b) distinguish `q` from `qaa`, and (c)
have a correspondence between data length and encoded length.
Simply using the first two digits isn’t enough (both `p` and
`q` would decode to 10), so we have to say 108.  But while this is
lexicographically before 10816, it is also before 10185, or `pzz`,
so order is not preserved.  And, again, if we only know the first
three digits of a block, we don’t know if the first character is a
`p` or a `q`, even though those digits are the encoding for `q`
(this corresponds to property 3 above).

A bigger encoding would be 100²·_A_+100·_B_+_C_, yielding six
digits.  Then there is no problem: `pzz` is 152525, `q` is 16.
and `qaa` is 160000.  However, this adds a digit and so is less efficient.

Consider then the encoding 1000·_A_+30·_B_+_C_.  Since 26⩽30 and
26·30⩽1000, the data “fits”.  Note that only five digits are
produced, and yet the problems above are all solved.  `pzz` encodes
to 15775, `q` to 16, and `qaa` to 16000.

The key is that each letter value, working backwards, is multiplied
by a coefficient that includes increasingly more factors of 10.
This assures that final zeroes get encoded as final zeroes, so we can
have lexicographic order and the partial block features.  We’ll call
this requirement ZZ.

###  Locality 2

The restriction ZZ on coefficients isn’t free; it can result in
longer encodings.

As an example, the last encoding can be used to encode 2 letters
into 3 digits, and thus 4 letters into 6 digits, and so on.  However,
log(26)/log(10) is less than 10/7, so it is possible to pack 7 letters
into 10 digits.  But it cannot be done with ZZ.

To return to G60, log(256)/log(57) is less than 11/8, and so even
with _χ_=57 we could pack 8 bytes into 11 characters, but it is
not possible to with ZZ.  (We _can_, however, with 16 bytes into 22
characters, which asymptotically achieves the same ratio.)

Furthermore, we might want a stronger restriction.  ZZ only requires
that at least one zero is encoded for each final zero, but if our
pack ratio is 11/8, we should be able to do better.  If we have five
bytes of data, we’re three short of a full block, so the restriction
says we need only 8 (11&minus;3) characters.  But five bytes could
fit into ⌈11·5/8⌉=7 characters.  Similarly, two bytes should
require only ⌈11·2/8⌉=3 characters.  So can we achieve that?

The answer is that for _χ_=57, 58, or even 59 we cannot.  Only at
_χ_=60 can we reach the ideal that only the information-theoretic
minimum is needed in all cases.

###  Locality 3

Earlier I mentioned how in the original letter encoding one may need
to know all the digits to deduce even one digit.  Here, I consider the
reverse problem: how many letters (or bytes) one needs to get digits
(or characters) of the encoding.

To illustrate, let us consider a different letter encoding
(the last one is too good and fails to illustrate the point):
3000·_A_+70·_B_+_C_.  This makes a larger number, but it still fits
into five digits and satisfies ZZ, so from the theory developed so
far it is equally good.

But, `noa` is encoded as 39980, while `noz` is 40005.  So, while
the need to know all the digits to decode one letter is eliminated,
we have the opposite problem that it may be necessary to know all
the letters before one digit of the encoding can be known.  Again,
it is desirable to limit these effects.

The culprit is the factor of 7.  To illustrate, fix _B_ at 14.
Then 70·_B_+_C_ ranges from 980 to 1005.  So the effects of _C_
can reach into the thousands digit.  And, as we saw, it can reach
into the ten-thousands.  In general, if coefficient factor is not a
divisor of some number (such as 1000), then one of these ranges will
generally cross a multiple of it.

If the coefficient were 50, then for various fixed _B_ the range
might be 950 to 975, or 1000 to 1025.  In fact, none of the ranges
cross multiples of 100, so the value of _C_ would not even affect
the hundreds digit.

If the coefficient were 40, we get ranges such as 80 to 105, so the
hundreds digit might be affected by _C_, but since 40 divides 1000,
the thousands digit won’t be.

There can be more complex interactions, but the general idea is that
locality is maximized when a coefficient is a divisor of a power of 10
(or, for G60, of 60), hopefully a low power.

###  Picking coefficients

The benefit of a base of 60 should now be clear.  It is a
number rich with factors, a so-called [colossally abundant
number](https://en.wikipedia.org/wiki/Colossally_abundant_number).

When building a polynomial, there is sometimes flexibility in the
choice of coefficients.  We will take the powers of 60 as given,
and consider what’s left.

Options:  The coefficient on _G_ can be 5 or 6.  The coefficient on
_F_ can be 22 through 28 if _G_ is 5, and 26 through 28 if _G_ is 6.
The coefficient on _C_ can be 39 through 42.  The coefficient on _A_
can be 13 or 14.  The others are fixed: _H_ at 1 of course, _E_ at 2,
_D_ at 9, and _B_ at 3.  There are 80 choices in all.

The _A_ one doesn’t matter much since nothing is before it, but
being even reduces the affect on the first digit a little.  For _C_,
40 is clearly best, not quite dividing 60, but only being off by a
factor of two (which means only one bit of effect), and dividing 60².
The same is true of 24 for _F_, and for _G_ there is no reason to
choose 6 over 5 (both divisors of 60) when it removes such options.

###  Final tweaks

The restrictions on mapping values of _F_ to numeric values for
base-60 are simply that (a) we need a distance of at least 22 (times
60², but that will be implicit) between each numeric, and (b) they
have to be packed in enough so that the largest value (for _F_=255)
is at most 7178, which means the gaps can average at most about 28.15.

There doesn’t need to be any particular pattern to these gaps, but
the most natural and simple approach is to have them equal, that is,
the map just multiplies by a fixed number such as 24, which then can
be a coefficient in a polynomial.

In one case, however, it is beneficial to add complexity.  The factor
of 9 for _D_ and 40 for _C_ do not mix well, as they are relatively
prime.  The number 40 is not quite a factor of 60, but only off by
one bit.  E.g., for _C_=1 it covers a range of 40 to 80 (×60⁶),
and in general for any odd _C_ it splits the range in half, and
always in the same place, so one bit of data is needed from past _C_
to determine the fourth character.  However, with multiplying _D_ by 9,
data past _D_ may be needed too, because if _D_ is 133 and _C_ is 1, we
get a range from these two of 3597 to 3606 (×60⁵), which spans 60².

However, this is only a single “bad” value of _D_, so all we
have to do is modify the gapping so it shifts over it.  For example,
for _D_&#xfeff;⩾133 we can just add 3 to the numeric, and the
problem is solved.  As another option, instead of 9·_D_, we could
use ⌊75·_D_/8⌋, with a recurring pattern of gaps of 9 or 10.
But in my view the simplest is to divide the _D_ range in half;
at _D_=128, we shift up to 3600.  The top bit of _D_ is handled
separately from the rest, and can be put it in a polynomial.

None of the other coefficients have any such problem or can be improved
in such a way.


##  Future work?

It is good to have a finalized spec.  Are there any improvements that
might be made?

The choice of letters to _not_ use is probably optimal, as `I` and
`O` are invariably the most visually troublesome.

We could also ask if we do use all letters, with _χ_=62, can we
improve, say, locality?  We would part with using a polynomial and
looking for factors, and instead use a complex set of gaps to avoid
bad ranges.  However, it turns out this gains no benefit.

To see how it might, let’s go all the way to _χ_=63.  The gaps
between mappings from _G_ must still be at least 5, but we can get the
coefficient on _F_ down to 21, a divisor of 63.  Thus, we can have a
map where the 8th byte does not depend on _G_, not even by one bit
as in _χ_=60.  Also, the 9 coefficient on _D_ is a divisor of 63,
which further increases locality.  However, _χ_=62 is not enough to
get these benefits.

There might be some unforeseen reason why the dispensation of _D_
would be better handled, say, in one of the alternative ways mentioned.

Finally, without changing the spec, it may be clearer to dispense
with _Dₗ_ and write the polynomial entries as 40·60⁶·_C_ +
60⁵·(48·_Dₕ_ + 9·_D_), that is, with the rows as these:

```
               48 00 00 00 00 00  × Dₕ
               09 00 00 00 00 00  × D
```


##  Reference implementation

A demo is included, written in Haskell, which demonstrates how
locality allows all calculations to be done with 16-bit integers.
It produces a simple CLI executable that can encode or decode G60.
Encoded lines are split at 77 characters.

The binary can be built with `cabal install` or , for Stack users,
with `stack install`.  Usage is primitive:

```bash
$ g60-demo <binary >text
$ g60-demo -d <text >binary
```


##  See also

*  **[G86](https://github.com/galenhuntington/g86)**.  An encoding
built on similar principles for when nearly all ASCII characters can
be used.

