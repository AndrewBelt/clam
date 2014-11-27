#!/usr/bin/env ruby

require 'shellwords'
require 'readline'


class Shell
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
			# TODO
			# Make sure we're replacing from the beginning
			pwd.sub(Dir.home, '~')
		},
	}
	
	def initialize
		@input = ''
		@methods = {}
	end
	
	def run
		loop do
			begin
				line = Readline.readline(prompt, true)
			rescue Interrupt
				puts
				next
			end
				
			break unless line
			@input += line
			
			begin
				args = Shellwords.shellsplit(@input)
				args.each {|a| a.sub!(/^~/, Dir.home)}
			rescue ArgumentError
				@input += "\n"
				next
			end
			
			execute(args) if @input != ''
			@input = ''
		end
	end
	
	# Generates the prompt string
	def prompt
		str = String.new(ENV['PROMPT'])
		PROMPT_REPLACEMENTS.each {|k, v| str[k] &&= v.call}
		str = '... ' if @input != ''
		str
	end
	
	# Runs an array of arguments
	# TODO
	# Support piping and file redirection
	def execute(args)
		cmd = args.shift
		
		method = @methods[cmd] || BUILTINS[cmd]
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



ENV['PROMPT'] ||= "\x1b[1;34m\\W\x1b[0;32m=>\x1b[39m "

shell = Shell.new
shell.run
puts
