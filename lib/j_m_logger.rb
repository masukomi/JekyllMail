class JMLogger
	
	def initialize(log_file, debug)
		@debug = debug ? true : false
		@log_file = log_file ? File.open(log_file, "a") : nil
		if (@debug)
			log("initialized logger")
		end
	end

	def log(message, write_to_file=false)
		puts message if @debug
		if @debug or (@log_file and write_to_file)
			t = Time.now
			@log_file.puts "[#{t.strftime("%m/%d/%y %H:%M:%S")}] #{message}"
		end
	end
	
	

end
