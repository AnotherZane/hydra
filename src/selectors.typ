#import "/src/util.typ"

/// Create a custom selector for `hydra`.
///
/// - element (function, selector): The primary element to search for
/// - filter (function): The filter to apply to the element
/// - ancestor (function, selector): The ancestor elements, this should match the immediate
///   ancestor and all of its ancestors
/// - ancestor-filter (function): The filter applied to the ancestors
/// -> dictionary
#let custom(
  element,
  filter: none,
  ancestor: none,
  ancestor-filter: none,
) = {
  util.assert.types("element", element, (function, selector, label))
  util.assert.types("filter", filter, (none, function))
  util.assert.types("ancestor", ancestor, (none, function, selector, label))
  util.assert.types("ancestor-filter", ancestor-filter, (none, function))

  util.assert.queryable("element", element)

  if ancestor != none {
    util.assert.queryable("ancestor", ancestor)
  }

  if ancestor == none and ancestor-filter != none {
    panic("`ancestor` must be set if `ancestor-filter` is set")
  }

  (
    self: (func: element, filter: filter),
    ancestor: if ancestor != none { (func: ancestor, filter: ancestor-filter) },
  )
}

/// Create a heading selector for a given range of levels.
///
/// - ..exact (int): The exact level to consider as the primary element
/// - min (int): The inclusive minimum level to consider as the primary heading
/// - max (int): The inclusive maximum level to consider as the primary heading
/// -> dictionary
#let by-level(
  min: none,
  max: none,
  ..exact,
) = {
  let (named, pos) = (exact.named(), exact.pos())

  assert.eq(named.len(), 0,
    message: util.fmt("Unexected named arguments: `{}`", named),
  )

  assert(pos.len() <= 1,
    message: util.fmt("Unexected positional arguments: `{}`", pos),
  )

  exact = pos.at(0, default: none)

  util.assert.types("min", min, (int, none))
  util.assert.types("max", max, (int, none))
  util.assert.types("exact", exact, (int, none))

  if min == none and max == none and exact == none {
    panic("Use `heading` directly if you have no `min`, `max` or `exact` level bound")
  }

  if exact != none and (min != none or max != none) {
    panic("Can only use `min` and `max`, or `exact` bound, not both")
  }

  if exact == none and (min == max) {
    exact = min
    min = none
    max = none
  }

  let (self, self-filter) = if exact != none {
    (heading.where(level: exact), none)
  } else if min != none and max != none {
    (heading, (ctx, e) => min <= e.level and e.level <= max)
  } else if min != none {
    (heading, (ctx, e) => min <= e.level)
  } else if max != none {
    (heading, (ctx, e) => e.level <= max)
  }

  let (ancestor, ancestor-filter) = if exact != none {
    (heading, (ctx, e) => e.level < exact)
  } else  if min != none and min > 1 {
    (heading, (ctx, e) => e.level < min)
  } else {
    (none, none)
  }

  custom(
    self,
    filter: self-filter,
    ancestor: heading,
    ancestor-filter: ancestor-filter,
  )
}

/// Turn a selector or function into a hydra selector.
///
/// This function is considered unstable.
///
/// - sel (any): The selector to sanitize
/// -> dictionary
#let sanitize(name, sel, message: auto) = {
  let message = util.core.or-default(check: auto, message, () => util.fmt(
    "`{}` must be a `heading`, `heading.where(level: n)`, a level, or a hydra-selector", name,
  ))

  if type(sel) == selector {
    assert(repr(sel).starts-with("heading.where"), message: message)
    let parts = repr(sel).split(".")

    let fields = (:)
    let func = if parts.len() == 1 {
      eval(parts.first())
    } else {
      let args = parts.remove(parts.len() - 1)
      for arg in args.trim("where").trim(regex("\(|\)"), repeat: false).split(", ") {
        let (name, val) = arg.split(": ")
        fields.insert(name, eval(val))
      }

      eval(parts.join("."))
    }

    assert.eq(fields.len(), 1, message: message)
    assert("level" in fields, message: message)
    by-level(fields.level)
  } else if type(sel) == int {
    by-level(sel)
  } else if type(sel) == function {
    custom(sel)
  } else if type(sel) == dictionary and "self" in sel and "ancestor" in sel {
    sel
  } else {
    panic(message)
  }
}
