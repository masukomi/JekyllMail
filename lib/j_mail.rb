class JMail
	MARKUP_EXTENSIONS= {:html => 'html', :markdown => 'markdown', :md => 'markdown', :textile => 'textile', :txt => 'textile'}
	@files_to_commit = []
	attr_reader :files_to_commit

	def initialize(blog, logger)
		@blog = blog
		@logger = logger
	end

	def process_mail(mail)
		@files_to_commit = []
		keyvals = {:tags => '', :markup => @blog['markup'], :slug => '', :published => true, :layout => 'post'}
		subject = mail.subject
		@logger.log( "processing email with subject: #{subject}")
		return false if subject.empty?

		keyvals[:title], raw_data = extract_data_from_subject(subject, keyvals) #updates the contents of keyvals

		# if it doesn't contain the secret we can assume it to be spam
		unless keyvals[:secret] == @blog.secret
			@logger.log("skipping email with invalid / non-existent secret.\n\tSubject:#{subject}\n\tSecret was: \"#{keyvals[:secret]}\"", true)
			return false
		end
		keyvals[:markup] ||= @blog.markup

		keyvals.delete(:secret) # we don't want that in the post's Frontmatter
		keyvals[:slug] ||= keyvals[:title].gsub(/[^[:alnum:]]+/, '-').downcase.strip.gsub(/\A\-+|\-+\z/, '')
		time = Time.now
		keyvals[:name] = "%02d-%02d-%02d-%s.%s" % [time.year, time.month, time.day, keyvals[:slug], MARKUP_EXTENSIONS[keyvals[:markup].to_sym]]
		keyvals[:time] = time
		body=''
		images_needing_replacement={}
		if mail.multipart?
			process_multipart_mail(mail, body, images_needing_replacement, keyvals)
		else
			#Just grab the body no matter what it is
			body = mail.body.decoded
		end
		#If we have no body after all that, bail
		return false if body.strip.empty?


		#If it's html, run it through nokogiri to make sure it's clean
		if keyvals[:markup] == 'html'
			#body.gsub!(/[”“]/, '"')
			#body.gsub!(/[‘’]/, "'")
			body = Nokogiri::HTML::DocumentFragment.parse(body.strip).to_html
		end
		if (images_needing_replacement.length() > 0)
			#TODO break this out into a method for testability
			images_needing_replacement.each do | filename, path |
				if keyvals[:markup] == 'markdown'
					body.gsub!(/(\(|\]:\s|<)#{Regexp.escape(filename)}/, "\\1#{path}")
				elsif keyvals[:markup] == 'textile'
					body.gsub!(/!#{Regexp.escape(filename)}(!|\()/, "!#{path}\\1")
				elsif keyvals[:markup] == 'html'
					body.gsub!(/(src=(?:'|")|href=(?:'|"))#{Regexp.escape(filename)}/i, "\\1#{path}")
					# WARNING: won't address urls in css
					# Is case insensitive so it won't differentiatee FOO.jpg from foo.jpg or FoO.jpg
					# people shouldn't be using the same name for different files anyway. :P
				end
			end
		end

		write_to_disk(body, keyvals)

		if @files_to_commit.size() > 0
			message = "ingested these files:"
			@files_to_commit.each do | f |
			message += "\n\t#{f}"
		end
			@logger.log(message, true)
		end

		@blog.commit(@files_to_commit, keyvals[:slug]) if @blog.add_to_git? and @files_to_commit.size() > 0

		return true
		end


def extract_data_from_subject(subject, keyvals)
	(title, raw_data) = subject.split(/\|\|/) # two pipes separate subject from data
	title.gsub!(/^\s+|\s+$/, '')
	unless raw_data.nil?
	datums = raw_data.split('/')
	datums.each do |datum|
	next if datum.nil?
(key, val) = datum.split(/:\s?/)
	key.gsub!(/\s+/, '')
	val.gsub!(/\s+$/, '')
	keyvals[key.to_sym] = val
	end
	end
	return [title, raw_data]
	end

def process_multipart_mail(mail, body, images_needing_replacement, keyvals)
	html_part = -1
	txt_part = -1

#Figure out which part is html and which
#is text
	mail.parts.each_with_index do |p,idx|
	if p.content_type.start_with?('text/html')
	html_part = idx
	elsif p.content_type.start_with?('text/plain')
	txt_part = idx
	end
	end

	mail.attachments.each do |attachment|
#TODO: break this out into a separate method.
	if (attachment.content_type.start_with?('image/'))
	fn = attachment.filename
	images_dir = @blog.images_dir + ("/%02d/%02d/%02d" % [keyvals[:time].year, keyvals[:time].month, keyvals[:time].day])
	local_images_dir = "#{@blog.source_dir}/#{images_dir}"
	puts "local_images_dir: #{local_images_dir}"
	images_needing_replacement[fn] = "#{@blog.site_url}/#{images_dir}/#{fn}"
	puts "image url: #{images_needing_replacement[fn]}"
unless Dir.exists?(local_images_dir)
	log( "creating dir #{local_images_dir}")
FileUtils.mkdir_p(local_images_dir)
	end
	begin
	local_filename = "#{@blog.source_dir}/#{images_dir}/#{fn}"
	log("saving image to #{local_filename}")
unless File.writable?(local_images_dir)
	$stderr.puts("ERROR: #{local_images_dir} is unwritable. Exiting.")
	end
	File.open( local_filename, "w+b", 0644 ) { |f| f.write attachment.body.decoded }
	@files_to_commit << "source/#{images_dir}/#{fn}"
	rescue Exception => e
	$stderr.puts "Unable to save data for #{fn} because #{e.message}"
	end
	end
	end


#If the markup isn't html, try and use the
#text if it exists. Anything else, use the html
#version
	if txt_part > -1 and keyvals[:markup] != 'html'
	body = mail.parts[txt_part].body.decoded
	elsif html_part > -1
	body = mail.parts[html_part].body.decoded
	end

	end


def write_to_disk(body, keyvals)
	post_filename =  "#{@blog.posts_dir}/#{keyvals[:name]}"

	if File.writable?("#{@blog.posts_dir}")
	@logger.log("saving post to #{post_filename}")
	else
	$stderr.puts "ERROR: #{@blog.posts_dir} is not writable"
	exit 0
	end
	open(post_filename, 'w') do |str|
	str << "---\n"
	str << "title: '#{keyvals[:title]}'\n"
	str << "date: %02d-%02d-%02d %02d:%02d:%02d\n" % [keyvals[:time].year, keyvals[:time].month, keyvals[:time].day, keyvals[:time].hour, keyvals[:time].min, keyvals[:time].sec]
	keyvals.keys.sort.each do |key|
	if key != :tags  and key != :slug
					str << "#{key}: #{keyvals[key]}\n"
				elsif key == :tags
					unless keyvals[:tags].empty?
						str << "tags: \n"
						keyvals[:tags].split(',').each do |string|
							str << "- " + string.strip + "\n"
						end
					end
				end
			end
			str << "---\n"
			str << body
		end
		@files_to_commit << post_filename
	end



end
