# Capitalizes the first letter of a string
# Used for capitalizing names
def upper(arg, vars, data)
  arg.capitalize
end

# Increments the variable 0
def increment(arg, vars, data)
  data[arg.split[0]] += arg.split[1].to_i
end

def exists(arg, vars, data)
  return (vars[arg.to_i] != nil).to_s
end