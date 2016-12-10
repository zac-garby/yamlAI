require 'yaml'
require 'colorize'
require 'io/console'
require './functions'


$find_data_pattern = /@\w[\w\d]*/ # Matches an at symbol followed by a valid Ruby variable identifier
$find_var_pattern = /(\?\d)/ # Matches a question mark followed by a digit
$find_set_data_pattern = /:\w[\w\d]*=\d:/ # Matches an valid Ruby identifier, followed by an equals sign and a digit, surrounded by colons
$find_set_string_pattern = /::\w[\w\d]*=.*::/ # Matches a valid Ruby identifier, followed by an equals then any text, surrounded by double colons
$find_random_pattern = /%([^%|][|]?)+%/ # Matches identifiers seperated by poles, surrounded by percentage signs
$find_function_call_pattern = /\{(\w[\w\d]*[\?\!]?)[^{}]*\}/ # Matches a Ruby function id followed by any non-brace characters, wrapped by braces
$find_command_call_pattern = /\[\*[^\[\]]+\]/ # Matches a star followed by any non-square bracket characters, wrapped by square brackets
$find_clear_pattern = /\s(\*-\*)\s/ # Matches a dash surrounded by two stars with whitespace on either side
$rule_split_pattern = /(\s|\*|\!)/ # Used for splitting a rule by whitespace, stars and exclaimation marks
$punctuation = /[^\w\s]/ # Some punctuation
$punc_no_apos = /[^\w\s']/ # Some punctuation excluding apostrophes

class String
  def is_pos_i?
    /\A[+]?\d+\z/ === self
  end
  
  def remove_punctuation!
    self.gsub(/[^\p{Alnum}\s]/, "")
  end
  
  def strip_ch(chars)
    chars = Regexp.escape(chars)
    self.gsub(/\A[#{chars}]+|[#{chars}]+\z/, "")
  end
  
  def strip_ch!(chars)
    chars = Regexp.escape(chars)
    self.gsub!(/\A[#{chars}]+|[#{chars}]+\z/, "")
  end
end

class AI
  def initialize(path)
    @path = path
    @data, @rules = parse(@path)
  end
  
  def run(text, ai_prefix="AI> ".red)
    text.gsub!($punc_no_apos, "")
    text.strip!
    return false if text == "exit" or text == "quit"
    text = expand_contractions(text)
    @rules.each do |name, response|
      options = name.split("|").each {|val| val.strip!}
      options.each do |op|
        if op != "__unknown" and op != "__exit" and op != "__load"
          matched, var = check(op, text)
          if matched
            execute_rule(name, ai_prefix, var)
            return true
          end
        end
      end
    end
    execute_rule("__unknown", ai_prefix, [])
    false
  end
  
  def execute_output_text(t, variables, verbose=false)
    text = t.dup
    puts "Original: #{text}" if verbose

    while text[$find_random_pattern] != nil do
      choices = text[$find_random_pattern].strip_ch("%").split("|")
      text[$find_random_pattern] = choices.sample
    end
    puts "Randoms evaluated: #{text}" if verbose

    while text[$find_var_pattern] != nil do
      var = text[$find_var_pattern][1].to_i
      text[$find_var_pattern] = variables[var]
    end
    puts "Variables evaluated: #{text}" if verbose

    while text[$find_data_pattern] != nil do
      found = text[$find_data_pattern]
      text[$find_data_pattern] = @data[found[1, found.length]].to_s
    end
    puts "Data fields evaluated: #{text}" if verbose

    while text[$find_function_call_pattern] != nil do
      found = text[$find_function_call_pattern].strip_ch("{}")
      name = found.split[0]
      arg = found[name.length+1..-1]
      result = send(name, arg, variables, @data)
      if result == nil
        puts "Closing program, because a function return result was nil".red
        exit
      end
      text[$find_function_call_pattern] = result.to_s
    end
    puts "Called functions! #{text}" if verbose
    
    while text[$find_set_data_pattern] != nil do
      found = text[$find_set_data_pattern]
      split = found.strip_ch(":").split("=")
      @data[split[0]] = variables[split[1].to_i]
      text[$find_set_data_pattern] = ""
    end
    text.strip!
    puts "Set data fields: #{text}" if verbose
    
    while text[$find_set_string_pattern] != nil do
      found = text[$find_set_string_pattern]
      split = found.strip_ch(":").strip_ch(":").split("=")
      @data[split[0]] = split[1].to_s
      text[$find_set_string_pattern] = ""
    end
    text.strip!
    puts "Set string data fields: #{text}" if verbose
    return text
  end
  
  def repl(prompt="You> ".green, ai_prefix="AI> ".red)
    self.on_load(ai_prefix)
    while true
      print prompt
      begin
        text = gets
      rescue Interrupt => e
        puts "REPL interrupted, closing.".light_red
        break
      else
        if text != nil
          text = text.downcase.strip
          if ["quit", "exit"].include?(text)
            self.on_exit(ai_prefix)
            save = ''
            while not ['y', 'n'].include? save do
              print "Do you want to save the data from this session? It will #{"overwrite".red} the data currently in '#{@path}'! [#{"y".green}/#{"n".light_red}] ".italic
              save = STDIN.getch # Uncomment to allow save choosing
              save = 'n'
              puts
            end
            if save == 'y' then
              self.save_data
              puts "\nDone!"
            end
            exit
          end
          self.run(text, ai_prefix)
        end
      end
    end
  end
  
  def on_load(prefix)
    execute_rule("__load", prefix, [], false)
  end

  def on_exit(prefix)
    execute_rule("__exit", prefix, [], false)
  end
  
  def execute_rule(rule, prefix, variables, print_if_empty=true)
    if @rules[rule] != nil then
      result = execute_output_text(@rules[rule], variables)
      if result.strip.length > 0 or print_if_empty then
        puts prefix + result
      end
    end
  end
  
  def save_data
    data = {
      "data" => @data,
      "rules" => @rules
    }
    File.open(@path, "w") { |file| YAML.dump(data, file) }
  end
end

def check(rule, string)
  vars = []
  split_rule = rule.split($rule_split_pattern) - ["", " ", "\t"]
  split_input = string.split($rule_split_pattern) - ["", " ", "\t"]
  rule_index = 0
  split_input.each.with_index do |token, index|
    rule_token = split_rule[rule_index]
    next_token = split_input[index + 1] # TODO: Make sure index + 1 is in range
    next_rule_token = split_rule[rule_index + 1] # TODO: Make sure rule_index + 1 is in range
    return false, [], "Too much input" if rule_token == nil
    if rule_token == "!"
      if next_rule_token.is_pos_i? and next_rule_token.length == 1
        vars[next_rule_token.to_i] = token
        rule_index += 2
      else
        return false, [], "Invalid variable name"
      end
    elsif rule_token == "*"
      # Skip if it will match properly next time
      if next_token == next_rule_token
        rule_index += 1
      end
    elsif rule_token == "."
      # Just skip doing anything, because it will allow anything
      rule_index += 1
    else
      if rule_token == token
        rule_index += 1
      else
        return false, [], "Rule token does not match input token"
      end
    end
  end
  return false, [], "Not enough input" if split_rule[rule_index + 1] != nil
  return true, vars, "No errors"
end

def parse(filename)
  ai = YAML.load(File.open(filename, "r").read)
  data, rules = ai["data"], ai["rules"]
end

def expand_contractions(text)
  cont = {
    "'tis" => "it is",
    "'tisn't" => "it is not",
    "ain't" => "is not",
    "aren't" => "are not",
    "can't" => "cannot",
    "cap'n" => "captain",
    "could've" => "could have",
    "couldn't" => "could not",
    "didn't" => "did not",
    "doesn't" => "does not",
    "don't" => "do not",
    "hadn't" => "had not",
    "hasn't" => "has not",
    "haven't" => "have not",
    "he'd've" => "he would have",
    "i'd" => "i would",
    "i'll" => "i will",
    "i'm" => "i am",
    "i've" => "i have",
    "isn't" => "is not",
    "it's" => "it is",
    "might've" => "might have",
    "mightn't" => "might not",
    "must've" => "must have",
    "mustn't" => "must not",
    "ne'er" => "never",
    "o'" => "of",
    "should've" => "should have",
    "shouldn't" => "should not",
    "wasn't" => "was not",
    "weren't" => "were not",
    "what's" => "what is",
    "won't" => "will not",
    "would've" => "would have",
    "wouldn't" => "would not",
    "you'd" => "you would",
    "you'll" => "you will",
    "you're" => "you are",
    "you've" => "you have",
    "she'd've" => "she would have"
  }
  cont.each do |contraction, proper|
    text.gsub!(contraction, proper)
  end
  return text
end
