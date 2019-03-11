class Blog
	DIRECTORY_KEYS=['jekyll_blog_dir',
				 'images_dir_under_jekyll',
				 'posts_dir_under_jekyll'
				 ]

	attr_reader :data
	# TODO: CORRECT THE FOLLOWING COMMENTS
	# the blog hash contains
	# local_repo => absolute path to the root of a repo/dir
    #               exclusively for JekyllMail's use
	# origin_repo => where JekyllMail should push new files to
	# origin_repo_branch => (optional) the name of the branch to push to
	# pop_server => domain name
	# pop_user => username
	# pop_password => plaintext password
	# secret => the secret that must appear in the email subject
	# markup => markup or textile
	# site_url => the http://.... url to the root of the public web site
	# commit_after_save => boolean
	# git_branch => the name of the git branch to commit to
	## git_branch is Unused until we get Grit working correctly
	def initialize(yaml_data, logger)
		@data = yaml_data
		@logger = logger
		@data['images_dir_under_jekyll'] ||= 'assets/img'
		@data['posts_dir_under_jekyll'] ||= '_posts'
		@data['jekyll_blog_dir'] ||= 'source'
		@data['name'] ||= 'default blog'
		@data['origin_repo_branch'] ||= 'master'
		@data['markup'] ||= 'markdown'
		DIRECTORY_KEYS.each do | key |
			@data[key].sub!(/\/$/, '') # remove any trailing slashes from directory paths
		end
		@data.each do |key, value|
			@logger.log( "#{@data['name']} #{key}: #{value}" ) if @logger
		end
		confirm_local_repo(@data)
	end

	def confirm_local_repo(data)
		unless Dir.exists? data['jekyll_blog_dir']
			raise "Can't find jekyll_blog_dir for #{data['name']} at #{data['jekyll_blog_dir']}"
		end
	end

	def jekyll_dir
		return @data['jekyll_blog_dir']
	end
	def posts_dir
		return jekyll_dir() + "/#{@data['posts_dir_under_jekyll']}"
	end
	def images_dir
		return jekyll_dir() + "/#{@data['images_dir_under_jekyll']}"
	end
	def images_dir_under_jekyll
		return @data['images_dir_under_jekyll']
	end
	def images_dir_under_site_url
		return @data['images_dir_under_site_url']
	end

	def pop_server
		return @data['pop_server']
	end

	def pop_user
		return @data['pop_user']
	end

	def pop_password
		return @data['pop_password']
	end

	def markup
		return @data['markup']
	end

	def secret
		return @data['secret']
	end

	def site_url
		return @data['site_url']
	end

	def add_to_git?
		true
	end

	def commit(files_to_commit, slug)
		Dir.chdir(@data['jekyll_blog_dir'])
		files_to_commit.each do |file|
			# relative_file_name = file.sub(/.*?source\//, 'source/')
			@logger.log("adding #{file}")
			#index.add(relative_file_name, open(file, "rb") {|io| io.read })
						#repo_specific_file_name, binary_data
			# git doesn't care if you use absolute file paths
			# from within a repo
			`git add #{file}`
		end
		@logger.log("committing")
		#sha = index.commit("Adding post #{slug} via JekyllMail", parents, JEKYLLMAIL_USER, nil, blog['git_branch'])
		#puts "sha = #{sha}" if @@globals[:debug]
		`git commit -m "Adding post #{slug} via JekyllMail"`
		# `git pull --rebase origin #{@data['origin_repo_branch']}`
		if (@data['jekyll_blog_dir'] != @data['origin_repo'])
			result = `git push origin #{@data['origin_repo_branch']} 2>&1`
			if (result.match(/\[rejected\]/))
				@logger.log("error pushing #{@data['name']}'s new post to git:", true)
				result.split(/\n/).each do | line |
					@logger.log(line, true)
				end
			end
		end

	end

end
