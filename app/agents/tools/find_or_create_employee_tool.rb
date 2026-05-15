class FindOrCreateEmployeeTool
  def name
    "find_or_create_employee"
  end

  def definition
    {
      name: name,
      description: "Find or create an employee record by their Slack username.",
      input_schema: {
        type: "object",
        properties: {
          username: {
            type: "string",
            description: "The Slack username, e.g. 'sarah.park'"
          }
        },
        required: ["username"]
      }
    }
  end

  def call(input)
    username = input["username"]
    parts = username.split(".")
    first_name = (parts[0] || username).capitalize
    last_name  = parts[1..].map(&:capitalize).join(" ")

    employee = Employee.find_or_create_by(username: username) do |e|
      e.first_name = first_name
      e.last_name  = last_name
    end

    { id: employee.id }
  end
end
