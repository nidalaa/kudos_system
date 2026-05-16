categories = [
  { name: "Teamwork",             description: "Helping others, collaboration, unblocking someone" },
  { name: "Technical Excellence", description: "Quality work, clever solutions, shipping reliably" },
  { name: "Customer Impact",      description: "Going the extra mile for a client, solving a customer problem" },
  { name: "Leadership",           description: "Mentoring, stepping up, driving decisions" },
  { name: "Innovation",           description: "Creative approaches, trying new things, improving processes" },
  { name: "Above & Beyond",       description: "Effort that clearly exceeds what was expected" },
]

categories.each do |attrs|
  Category.find_or_create_by!(name: attrs[:name]) do |c|
    c.description = attrs[:description]
  end
end

puts "Seeded #{Category.count} categories."
