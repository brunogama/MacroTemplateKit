let callback = Template<Void>.closure(
  attributes: [.sendable],
  params: [(name: "value", type: "Int")],
  returnType: "Void",
  body: [
    .expression(
      .call(
        "handle",
        arguments: [
          .unlabeled(.variable("value"))
        ]
      )
    )
  ]
)
