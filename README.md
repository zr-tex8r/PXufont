PXufont Package
===============

LaTeX: To emulate non-Unicode Japanese fonts using Unicode fonts

The set of the Japanese logical fonts (JFMs) that are used as standard
fonts in pTeX and upTeX contains both Unicode JFMs and non-Unicode JFMs.
This bundle provides an alternative set of non-Unicode JFMs that are tied
to the virtual fonts (VFs) that refer to the glyphs in the Unicode JFMs.
Moreover it provides a LaTeX package that redefines the NFSS settings of
the Japanese fonts of (u)pLaTeX so that the new set of non-Unicode JFMs
will be employed. As a whole, this bundle allows users to dispense with
the mapping setup on non-Unicode JFMs.

Such setup is useful in particular when users want to use such OpenType
fonts (such as Source Han Serif) that have a glyph encoding different from
Adobe-Japan1, because mapping setup from non-Unicode JFMs to such physical
fonts are difficult to prepare.

### System requirement

  * TeX format: LaTeX.
  * TeX engine: pTeX / upTeX.
  * DVI drivers: Anything that supports JFMs and VFs.
  * Dependent packages:
      - ifptex

### Installation

  - `*.sty`     → $TEXMF/tex/platex/pxufont/
  - `tfm/*.tfm` → $TEXMF/fonts/tfm/public/pxufont/
  - `vf/*.vf`   → $TEXMF/fonts/vf/public/pxufont/

### License

This package is distributed under the MIT License.


The pxufont Package
-------------------

### Package Loading

    \usepackage{pxufont}

There are no package options available. Once the package is loaded, the
NFSS settings for the standard Japanese fonts will be redeclared.

Note: When you use both this package and the japanese-otf package, then
you must load japanese-otf earlier.

### Usage

For present, this package has no public commands. All the settings are
done through the package option.


The pxufont-ruby Package
------------------------

This package is an alternative to the pxufont package. The difference
between the two is the way the “ruby notation fonts” of the japanese-otf
package are handled; pxufont disables the ruby fonts and substitutes then
with ordinary fonts, whereas pxufont-ruby supports also the ruby fonts.
This feature however requires extra settings of font mapping.

### Package Loading

    \usepackage{pxufont-ruby}

Note that pxufont and pxufont-ruby are mutually exclusive; when both
packages are loaded, then the one loaded earlier will be effective.

NB. Developers can test whether pxufont-ruby is effective by testing
whether `\pxufontUseRubyFont` is defined.


Revision History
----------------

  * Version 0.6  〈2020/02/09〉
      - Suuport for `b` series.

  * Version 0.5  〈2019/02/28〉
      - Support for the fonts of ruby notation forms.

  * Version 0.4  〈2019/02/15〉
      - Support for the fonts of `min10` series.
      - Fix erroneous `zu-jisg.vf`.

  * Version 0.3  〈2017/07/07〉
      - Emulate also some Unicode fonts which VFs map to non-Unicode fonts.
  * Version 0.2  〈2017/06/28〉
      - The first public version.

--------------------
Takayuki YATO (aka. "ZR")  
https://github.com/zr-tex8r
