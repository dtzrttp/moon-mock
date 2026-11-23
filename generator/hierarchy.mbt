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
fn parse_traits(
  source : String,
  filename : String,
) -> Array[TraitSource] raise GenerationFailure {
  let (declarations, errors) = @parser.parse_string(
    source,
    name=filename,
    parser=Handrolled,
  )
  if !errors.is_empty() {
    let diagnostics = errors.map(report => {
      SourceSite::new(filename, at=report.loc.start).diagnostic(
        "parse_error",
        report.msg,
      )
    })
    raise GenerationFailure(diagnostics)
  }
  let traits = []
  for entry in declarations.iter() {
    if entry is @syntax.TopTrait(declaration) {
      traits.push({ filename, declaration, })
    }
  }
  traits
}

///|
fn index_traits(
  index : Map[String, Array[TraitSource]],
  source : String,
  filename : String,
) -> Unit raise GenerationFailure {
  for entry in parse_traits(source, filename) {
    let name = entry.declaration.name.name
    match index.get(name) {
      Some(matches) => matches.push(entry)
      None => index[name] = [entry]
    }
  }
}

///|
fn locate_trait(
  index : Map[String, Array[TraitSource]],
  name : String,
  reference : SourceSite,
  missing_code : String,
) -> TraitSource raise GenerationFailure {
  guard index.get(name) is Some(matches) else {
    return reference.reject(missing_code, name)
  }
  guard matches is [source] else {
    let locations = matches.map(source => {
      SourceSite::new(source.filename, at=source.declaration.name.loc.start).text()
    })
    return reference.reject(
      "ambiguous_trait",
      "\{name} 声明于 " + locations.join("、"),
    )
  }
  source
}

///|
priv struct HierarchyWalk {
  index : Map[String, Array[TraitSource]]
  active : Array[String]
  collected : Map[String, Bool]
  owners : Map[String, (String, SourceSite)]
  result : Hierarchy
}

///|
fn HierarchyWalk::visit(
  self : HierarchyWalk,
  source : TraitSource,
  reference : SourceSite,
) -> Unit raise GenerationFailure {
  let { filename, declaration, } = source
  let name = declaration.name.name
  if self.collected.contains(name) {
    return
  }
  if self.active.contains(name) {
    let path = self.active.join(" -> ") + " -> " + name
    reference.reject("trait_cycle", path)
  }
  if self.active.length() >= 128 {
    reference.reject("resource_limit", "继承深度最多 128 层")
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
    let parent_site = SourceSite::new(filename, at=parent.loc.start)
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
    let site = SourceSite::new(filename, at=declared_method.loc.start)
    if self.owners.get(method_name) is Some((other, previous_site)) {
      site.reject(
        "method_conflict",
        "\{other}.\{method_name}（\{previous_site.text()}）与 \{name}.\{method_name}（\{site.text()}）同名",
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
  prepared : PreparedSources,
  name : String,
) -> Hierarchy raise GenerationFailure {
  let { filename, primary, all_traits: index, } = prepared
  let reference = SourceSite::new(filename)
  locate_trait(primary, name, reference, "trait_not_found") |> ignore
  let root = locate_trait(index, name, reference, "trait_not_found")
  let walk : HierarchyWalk = {
    index,
    active: [],
    collected: Map([]),
    owners: Map([]),
    result: { methods: [], empty_traits: [], },
  }
  walk.visit(root, reference)
  if walk.result.methods.is_empty() {
    unsupported(
      filename,
      root.declaration.loc,
      "trait 及其继承链没有可生成的方法",
    )
  }
  walk.result
}
