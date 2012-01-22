#!/usr/bin/env ruby
# -*- coding: utf-8 -*- #specify UTF-8 (unicode) characters

#Email to Jekyll script
#(c)2011 Ted Kulp <ted@tedkulp.com> 
# Portions copyright 2011 masukomi <masukomi@masukomi.org>
# POP3 support and Git config integration added by masukomi
#MIT license -- Have fun
#Most definitely a work in progress

# TODO
# error handling:
# - complain if any of the required blog are not defined

$LOAD_PATH.push File.expand_path(File.join(File.dirname(__FILE__), "lib"))

require 'rubygems'
require 'yaml'
require 'net/pop'
require 'mail'
require 'nokogiri'
require 'fileutils'
#require 'grit'
#include Grit


require 'j_m_logger'
require 'blog'
require 'j_mail'

# The following constants can all be overridden in the config file
@@globals={:debug=>false, :delete_after_run=>true}

#JEKYLLMAIL_USER= Actor.from_string("JekyllMail Script <jekyllmail@masukomi.org>")


directory_keys = ['jekyll_repo', 'source_dir', 'site_url']
yaml = YAML::load(File.open('_config.yml'))
@@globals[:delete_after_run] = yaml['delete_after_run'] ? true : false
@@globals[:workspace] = yaml['workspace']


@@logger = JMLogger.new(yaml['log_file'], yaml['debug'])


blogs = yaml['blogs']
blogs.each do | blog_data | 
	blog = Blog.new(blog_data, @@logger)

	#TODO break this out into its own class
	Mail.defaults do
	  retriever_method :pop3, :address    => blog.pop_server,
							  :port       => 995,
							  :user_name  => blog.pop_user,
							  :password   => blog.pop_password,
							  :enable_ssl => true
	end

	emails = Mail.all

	if (emails.length == 0 )
		@@logger.log( "No Emails found")
		next #move on to the next blog's config
	else
		@@logger.log( "#{emails.length} email(s) found" )
	end



	emails.each do | mail |
		jmail = JMail.new(blog, @@logger)
		good_mail = jmail.process_mail(mail)

	end
	Mail.delete_all() unless @@globals[:debug] == true or  @@globals[:delete_after_run] == false
		# when debugging it's much easier to just leave the emails there and re-use them

end
