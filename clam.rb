#!/usr/bin/env ruby

require 'shellwords'
require 'readline'
require 'fileutils'
require 'socket' # for Socket::get_hostname

class String
	def start_sub!(search, replacement)
		len = search.length
		if self[0, len] == search
			self[0, len] = replacement
		end
		self
	end
	
	# Calculates the length not including ANSI escape codes
	def length_escape
		gsub(/\e\[[0-9;]*m/, '').length
	end
end


module Clam
	BUILTINS = {
		'cd' => lambda { |dir=nil|
			dir ||= Dir.home
			Dir.chdir(dir)
		},
		'exit' => lambda { |code=0| exit(code.to_i)},
		'set' => lambda { |args|
			key, value = args.split('=')
			ENV[key] = value
		},
	}
	
	PROMPT_REPLACEMENTS = {
		'\W' => lambda {
			pwd = Dir.pwd
			pwd.start_sub!(Dir.home, '~')
			pwd
		},
		'\u' => lambda {ENV['USER'] || ''},
		'\h' => lambda {Socket.gethostname},
	}
	
	def self.load_config
		config_path = Dir.join(Dir.home, '.config/plastic/config')
		if Dir.exists?(config_path)
			file = File.open(config_path, 'r')
		else
			FileUtils.mkdir_p(File.dirname(config_path))
			FileUtils.touch(config_path)
		end
	end
	
	# Read-eval-print-loop
	def self.repl
		input = ''
		loop do
			p = prompt()
			p = ' ' * p.length_escape unless input.empty?
			
			begin
				line = Readline.readline(p, true)
			rescue Interrupt
				puts
				next
			end
			
			break unless line
			input += line
			
			begin
				args = Shellwords.shellsplit(input)
				# BUG
				# `echo '~'` prints "/home/username"
				# should print "'~'"
				args.each {|a| a.start_sub!('~', Dir.home)}
			rescue ArgumentError
				input += "\n"
				next
			end
			
			execute(args) unless input.empty?
			input = ''
		end
	end
	
	# Generates the prompt string
	def self.prompt
		str = String.new(ENV['PROMPT'])
		PROMPT_REPLACEMENTS.each {|k, v| str[k] &&= v.call}
		str
	end
	
	# Runs an array of arguments
	# TODO
	# Support piping and file redirection
	def self.execute(args)
		cmd = args.shift
		
		method = $methods[cmd] || BUILTINS[cmd]
		if method
			method.call(*args)
		else
			pid = fork do
				begin
					exec(cmd, *args)
				rescue => e
					$stderr.puts e.message
				end
			end
			Process.wait(pid)
		end
	end
end



ENV['PROMPT'] ||= "\e[35m\\u@\\h \e[1;34m\\W\e[0;32m~>\e[39m "
$methods = {}

Clam.repl
puts
