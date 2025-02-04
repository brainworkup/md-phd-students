// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}

#import "@preview/touying:0.5.3": *
#import "@preview/fontawesome:0.3.0": *

#let new-section-slide(self: none, body)  = touying-slide-wrapper(self => {
  let main-body = {
    set align(left + horizon)
    set text(size: 2em, fill: self.colors.primary, weight: "bold", font: self.store.font-family-heading)
    utils.display-current-heading(level: 1)
  }
  self = utils.merge-dicts(
    self,
    config-page(margin: (left: 2em, top: -0.25em)),
  ) 
  touying-slide(self: self, main-body)
})

#let slide(
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  ..bodies,
) = touying-slide-wrapper(self => {
  // set page
  let header(self) = {
    set align(top)
    show: components.cell.with(inset: (x: 2em, top: 1.5em))
    set text(
      size: 1.4em,
      fill: self.colors.neutral-darkest,
      weight: self.store.font-weight-heading,
      font: self.store.font-family-heading,
    )
    utils.call-or-display(self, self.store.header)
  }
  let footer(self) = {
    set align(bottom)
    show: pad.with(.4em)
    set text(fill: self.colors.neutral-darkest, size: .8em)
    utils.call-or-display(self, self.store.footer)
    h(1fr)
    context utils.slide-counter.display() + " / " + utils.last-slide-number
  }

  // Set the slide
  let self = utils.merge-dicts(
    self,
    config-page(
      header: header,
      footer: footer,
    ),
  )
  touying-slide(self: self, config: config, repeat: repeat, setting: setting, composer: composer, ..bodies)
})


#let clean-theme(
  aspect-ratio: "16-9",
  handout: false,
  header: utils.display-current-heading(level: 2),
  footer: [],
  font-size: 20pt,
  font-family-heading: ("Roboto"),
  font-family-body: ("Roboto"),
  font-weight-heading: "light",
  font-weight-body: "light",
  font-weight-title: "light",
  font-weight-subtitle: "light",
  font-size-title: 1.4em,
  font-size-subtitle: 1em,
  color-jet: rgb("131516"),
  color-accent: rgb("107895"),
  color-accent2: rgb("9a2515"),
  ..args,
  body,
) = {
  set text(size: font-size, font: font-family-body, fill: color-jet,
           weight: font-weight-body)

  show: touying-slides.with(
    config-page(
      paper: "presentation-" + aspect-ratio,
      margin: (top: 4em, bottom: 1.5em, x: 2em),
    ),
    config-common(
      slide-fn: slide,
      new-section-slide-fn: new-section-slide,
      handout: handout,
      enable-frozen-states-and-counters: false, // https://github.com/touying-typ/touying/issues/72
      show-hide-set-list-marker-none: true,
      show-strong-with-alert: false
    ),
    config-methods(
      init: (self: none, body) => {
        show link: set text(fill: self.colors.primary)
        // Unordered List
        set list(
          indent: 1em,
          marker: (text(fill: self.colors.primary)[ #sym.triangle.filled ],
                    text(fill: self.colors.primary)[ #sym.arrow]),
        )
        // Ordered List
        set enum(
          indent: 1em,
          full: true, // necessary to receive all numbers at once, so we can know which level we are at
          numbering: (..nums) => {
            let nums = nums.pos()
            let num = nums.last()
            let level = nums.len()

            // format for current level
            let format = ("1.", "i.", "a.").at(calc.min(2, level - 1))
            let result = numbering(format, num)
            text(fill: self.colors.primary, result)
          }
        ) 
        // Slide Subtitle
        show heading.where(level: 3): title => {
          set text(
            size: 1.1em,
            fill: self.colors.primary,
            font: font-family-body,
            weight: "light",
            style: "italic",
          )
          block(inset: (top: -0.5em, bottom: 0.25em))[#title]
        }

        set bibliography(title: none)

        body
      },
      alert: (self: none, it) => text(fill: self.colors.secondary, it),
    ),
    config-colors(
      primary: color-accent,
      secondary: color-accent2,
      neutral-lightest: rgb("#ffffff"),
      neutral-darkest: color-jet,
    ),
    // save the variables for later use
    config-store(
      header: header,
      footer: footer,
      font-family-heading: font-family-heading,
      font-family-body: font-family-body,
      font-size-title: font-size-title,
      font-size-subtitle: font-size-subtitle,
      font-weight-heading: font-weight-heading,
      font-weight-title: font-weight-title,
      font-weight-subtitle: font-weight-subtitle,
      ..args,
    ),
  )

  body
}

#let title-slide(
  ..args,
) = touying-slide-wrapper(self => {
  let info = self.info + args.named()
  let body = {
    set align(left + horizon)
    block(
      inset: (y: 1em),
      [#text(size: self.store.font-size-title,
             fill: self.colors.neutral-darkest,
             weight: self.store.font-weight-title,
             font: self.store.font-family-heading,
             info.title)
       #if info.subtitle != none {
        linebreak()
        v(-0.3em)
        text(size: self.store.font-size-subtitle,
             style: "italic",
             fill: self.colors.primary,
             weight: self.store.font-weight-subtitle,
             font: self.store.font-family-body,
             info.subtitle)
      }]
    )

    set text(fill: self.colors.neutral-darkest)

    if info.authors != none {
      let count = info.authors.len()
      let ncols = calc.min(count, 3)
      grid(
        columns: (1fr,) * ncols,
        row-gutter: 1.5em,
        ..info.authors.map(author =>
            align(left)[
              #text(size: 1em, weight: "regular")[#author.name]
              #if author.orcid != [] {
                show link: set text(size: 0.7em, fill: rgb("a6ce39"))
                link("https://orcid.org/" + author.orcid.text)[#fa-orcid()]
              } \
              #text(size: 0.7em, style: "italic")[
                #show link: set text(size: 0.9em, fill: self.colors.neutral-darkest)
                #link("mailto:" + author.email.children.map(email => email.text).join())[#author.email]
              ] \
              #text(size: 0.8em, style: "italic")[#author.affiliation]
            ]
        )
      )
    }

    if info.date != none {
      block(if type(info.date) == datetime { info.date.display(self.datetime-format) } else { info.date })
    }
  }
  self = utils.merge-dicts(
    self,
    config-common(freeze-slide-counter: true)
  )
  touying-slide(self: self, body)
})



// Custom Functions
#let fg = (fill: rgb("e64173"), it) => text(fill: fill, it)
#let bg = (fill: rgb("e64173"), it) => highlight(
    fill: fill,
    radius: 2pt,
    extent: 0.2em,
    it
  )
#let _button(self: none, it) = {
  box(inset: 5pt,
      radius: 3pt,
      fill: self.colors.primary)[
    #set text(size: 0.5em, fill: white)
    #sym.triangle.filled.r
    #it
  ]
}

#let button(it) = touying-fn-wrapper(_button.with(it))

#show: clean-theme.with(
  aspect-ratio: "16-9",
    // Typography ---------------------------------------------------------------
            // Colors --------------------------------------------------------------------
        // Title slide ---------------------------------------------------------------
      )

#title-slide(
  title: [A title],
  subtitle: [A subtitle],
  authors: (
                    ( name: [Your Name],
            affiliation: [Your Institution],
            email: [alias\@email.com],
            orcid: [0000-0000-0000-0000]),
            ),
  date: [February 4, 2025],
)

= Section Slide as Header Level 1
<section-slide-as-header-level-1>
== Slide Title as Header Level 2
<slide-title-as-header-level-2>
=== Subtitle as Header Level 3
<subtitle-as-header-level-3>
You can put any content here, including text, images, tables, code blocks, etc.

- first unorder list item
  - A sub item

+ first ordered list item
  + A sub item

Next, we’ll brief review some theme-specific components.

- Note that #emph[all] of the standard Quarto + Typst #link("https://quarto.org/docs/output-formats/typst.html")[features] can be used with this theme
- Also, all the #link("https://touying-typ.github.io")[Touying] features can be used by #strong[Typst native code]

== Additional Theme Classes
<additional-theme-classes>
=== Some extra things you can do with the clean theme
<some-extra-things-you-can-do-with-the-clean-theme>
Special classes for emphasis

- `.alert` class for default emphasis, e.g.~#alert()[the second accent color].
- `.fg` class for custom color, e.g.~#fg(fill: rgb("#5D639E"))[with `options='fill: rgb("#5D639E")'`].
- `.bg` class for custom background, e.g.~#bg()[with the default color].

Cross-references

- `.button` class provides a Beamer-like button, e.g. #link(<sec-summary>)[#button()[Summary]]

== Summary
<sec-summary>
=== A Minimalistic Presentation Theme for Quarto + Typst with Touying
<a-minimalistic-presentation-theme-for-quarto-typst-with-touying>
Add the theme to an existing project

```bash
quarto install extension kazuyanagimoto/quarto-clean-typst
```

… or, create a new project using this slide deck as a lean template

```bash
quarto use template kazuyanagimoto/quarto-clean-typst
```

=== Longer Demo
<longer-demo>
For a more comprehensive demo, see the #link("https://kazuyanagimoto.com/quarto-slides-typst/slides/quarto-clean-typst/clean.pdf")[demo slides] and #link("https://github.com/kazuyanagimoto/quarto-slides-typst/blob/main/slides/quarto-clean-typst/clean.qmd")[code];!
