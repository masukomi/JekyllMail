class Blog
	DIRECTORY_KEYS=['local_repo', 'source_dir', 'site_url']

	attr_reader :data
	# the blog hash contains
	# local_repo => absolute path to the root of a repo/dir 
    #               exclusively for JekyllMail's use
	# origin_repo => where JekyllMail should push new files to
	# origin_repo_branch => (optional) the name of the branch to push to
	# source_dir => (optional) relative path (under local_repo) 
	#               to the directory containing _posts, _drafts, and images
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
		@data['images_dir'] ||= 'images'
		@data['posts_dir'] ||= '_posts'
		@data['source_dir'] ||= 'source'
		@data['name'] ||= 'default blog'
		@data['origin_repo_branch'] ||= 'master'
		DIRECTORY_KEYS.each do | key |
			@data[key].sub!(/\/$/, '') # remove any trailing slashes from directory paths
			@logger.log( "#{@data['name']} #{key}: #{@data[key]}" ) if @logger
		end
		setup_local_repo()
	end

	def setup_local_repo
		#FileUtils.rm_rf(source_dir())
		unless Dir.exists?(source_dir())
			FileUtils.mkdir_p(source_dir())
			FileUtils.mkdir_p(posts_dir())
			Dir.chdir(@data['local_repo'])
			if (@data['commit_after_save'] and @data['origin_repo'])
				unless Dir.exists?('.git')
					`git init`
					`git remote add origin #{@data['origin_repo']}`
				end
			elsif (@data['commit_after_save'] and not @data['origin_repo'])
				@logger.log("can't commit after save to #{@data['name']} without an origin_repo specified")
			end
		else
			@logger.log("local repo wasn't deleted before run #{source_dir()}. Continuing on and hoping for the best.", true)
		end
	end

	def source_dir
		return "#{@data['local_repo']}/#{@data['source_dir']}"
	end
	def posts_dir
		return source_dir() + "/#{@data['posts_dir']}"
	end
	def images_dir
		return source_dir() + "/#{@data['images_dir']}"
	end

	def add_to_git?
		return ( @data['commit_after_save'] and  @data['origin_repo'] and (@data['local_repo'] != @data['origin_repo']))
	end
	
	def method_missing(method, *args, &block)
		return @data[method.to_s]
	end

	def commit(files_to_commit, slug)
		Dir.chdir(@data['local_repo'])
		files_to_commit.each do |file|
			relative_file_name = file.sub(/.*?source\//, 'source/')
			@logger.log("adding #{relative_file_name}")
			#index.add(relative_file_name, open(file, "rb") {|io| io.read })
						#repo_specific_file_name, binary_data
			`git add #{relative_file_name}`
		end
		@logger.log("committing")
		#sha = index.commit("Adding post #{slug} via JekyllMail", parents, JEKYLLMAIL_USER, nil, blog['git_branch'])
		#puts "sha = #{sha}" if @@globals[:debug]
		`git commit -m "Adding post #{slug} via JekyllMail"`
		`git pull --rebase origin #{@data['origin_repo_branch']}`
		if (@data['local_repo'] != @data['origin_repo'])
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
