#!/usr/bin/env ruby

require_relative 'yamlai'

prefix = "AI> ".green.italic

puts "-------------------- RUNNING --------------------".red.bold

ai = AI.new("ai.yml")
ai.repl()