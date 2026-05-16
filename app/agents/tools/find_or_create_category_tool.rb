class FindOrCreateCategoryTool
  def name
    "find_or_create_category"
  end

  def definition
    {
      name: name,
      description: "Find or create a kudos category by name. Use the exact category names listed in your instructions.",
      input_schema: {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "The category name, e.g. 'Teamwork', 'Technical Excellence', 'Ambiguous'"
          }
        },
        required: ["name"]
      }
    }
  end

  def call(input)
    category = Category.find_or_create_by(name: input["name"]) do |c|
      c.description = ""
    end
    { name: category.name }
  end
end
