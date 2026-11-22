///|
priv struct TraitSource {
  filename : String
  declaration : @syntax.TraitDecl
}

///|
priv struct Hierarchy {
  methods : Array[Signature]
  empty_traits : Array[String]
}

///|
fn index_traits(
  index : Map[String, Array[TraitSource]],
  source : String,
  filename : String,
) -> Unit raise GenerationError {
  let (declarations, errors) = @parser.parse_string(
    source,
    name=filename,
    parser=Handrolled,
  )
  if !errors.is_empty() {
    let details = errors.map(report => {
      let at = report.loc.start
      "\{filename}:\{at.lnum}:\{at.column()}: parse_error: \{report.msg}"
    })
    raise GenerationError(details.join("\n"))
  }
  for entry in declarations.iter() {
    if entry is @syntax.TopTrait(declaration) {
      let name = declaration.name.name
      let source = { filename, declaration, }
      match index.get(name) {
        Some(matches) => matches.push(source)
        None => index[name] = [source]
      }
    }
  }
}

///|
fn locate_trait(
  index : Map[String, Array[TraitSource]],
  name : String,
  reference : String,
  missing_code : String,
) -> TraitSource raise GenerationError {
  guard index.get(name) is Some(matches) else {
    raise GenerationError("\{reference}: \{missing_code}: \{name}")
  }
  guard matches is [source] else {
    let locations = matches.map(source => {
      let at = source.declaration.name.loc.start
      "\{source.filename}:\{at.lnum}:\{at.column()}"
    })
    raise GenerationError(
      "\{reference}: ambiguous_trait: \{name} 声明于 " +
      locations.join("、"),
    )
  }
  source
}

///|
priv struct HierarchyWalk {
  index : Map[String, Array[TraitSource]]
  active : Array[String]
  collected : Map[String, Bool]
  owners : Map[String, (String, String)]
  result : Hierarchy
}

///|
fn HierarchyWalk::visit(
  self : HierarchyWalk,
  source : TraitSource,
  reference : String,
) -> Unit raise GenerationError {
  let { filename, declaration, } = source
  let name = declaration.name.name
  if self.collected.contains(name) {
    return
  }
  if self.active.contains(name) {
    let path = self.active.join(" -> ") + " -> " + name
    raise GenerationError("\{reference}: trait_cycle: " + path)
  }
  if self.active.length() >= 128 {
    raise GenerationError(
      "\{reference}: resource_limit: 继承深度最多 128 层",
    )
  }
  if declaration.is_declare || !(declaration.attrs is @list.Empty) {
    unsupported(
      filename,
      declaration.loc,
      "暂不支持仅声明或带属性的 trait",
    )
  }
  self.active.push(name)
  for parent in declaration.supers.iter() {
    let at = parent.loc.start
    let parent_site = "\{filename}:\{at.lnum}:\{at.column()}"
    match parent.trait_ {
      Ident(name=parent_name) => {
        let parent_source = locate_trait(
          self.index,
          parent_name,
          parent_site,
          "supertrait_not_found",
        )
        self.visit(parent_source, parent_site)
      }
      Dot(..) =>
        unsupported(filename, parent.loc, "超 trait 必须在同一个包内")
    }
  }
  if declaration.methods is @list.Empty {
    self.result.empty_traits.push(name)
  }
  for declared_method in declaration.methods.iter() {
    let method_name = declared_method.name.name
    let at = declared_method.loc.start
    let site = "\{filename}:\{at.lnum}:\{at.column()}"
    if self.owners.get(method_name) is Some((other, previous_site)) {
      raise GenerationError(
        "\{site}: method_conflict: \{other}.\{method_name}（\{previous_site}）与 \{name}.\{method_name}（\{site}）同名",
      )
    }
    self.owners[method_name] = (name, site)
    self.result.methods.push(collect_signature(declared_method, filename, name))
  }
  self.active.pop() |> ignore
  self.collected[name] = true
}

///|
fn collect(
  source : String,
  name : String,
  file : String,
  additional_sources : Array[(String, String)],
) -> Hierarchy raise GenerationError {
  let index : Map[String, Array[TraitSource]] = Map([])
  index_traits(index, source, file)
  let root = locate_trait(index, name, file, "trait_not_found")
  for (extra_file, extra_source) in additional_sources {
    index_traits(index, extra_source, extra_file)
  }
  let root = locate_trait(index, name, root.filename, "trait_not_found")
  let walk : HierarchyWalk = {
    index,
    active: [],
    collected: Map([]),
    owners: Map([]),
    result: { methods: [], empty_traits: [], },
  }
  walk.visit(root, file)
  if walk.result.methods.is_empty() {
    unsupported(
      file,
      root.declaration.loc,
      "trait 及其继承链没有可生成的方法",
    )
  }
  walk.result
}
