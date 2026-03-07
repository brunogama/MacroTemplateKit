let fetchUser = Template<Void>.variable("api")
  .method("fetch") {
    TemplateArgument<Void>.labeled("id", .variable("id"))
  }
  .tryAwait()
