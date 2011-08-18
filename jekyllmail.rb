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
# - complain if any of the required prefs are not defined

require 'rubygems'
require 'net/pop'
require 'mail'
require 'nokogiri'
require 'fileutils'

#Change me
prefs = {
	:path_to_posts => `git config jekyllmail.postsDir`.chomp,
	:path_to_drafts => `git config jekyllmail.draftsDir`.chomp,
	:pop_server => `git config jekyllmail.popServer`.chomp,
	:pop_user => `git config jekyllmail.popUser`.chomp,
	:pop_password => `git config jekyllmail.popPassword`.chomp,
	:secret => `git config jekyllmail.secret`.chomp,
		# secret must appear in the subject line or the message will be deleted unread
	:markup => `git config jekyllmail.defaultMarkup`.chomp,
}


Mail.defaults do
  retriever_method :pop3, :address    => prefs[:pop_server],
                          :port       => 995,
                          :user_name  => prefs[:pop_user],
                          :password   => prefs[:pop_password],
                          :enable_ssl => true
end

emails = Mail.all

if (emails.length == 0 )
	puts "No Emails found"
	exit 0
else
	puts "#{emails.length} email(s) found"
end



emails.each do | mail |

	markup_extensions = {:html => 'html', :markdown => 'markdown', :md => 'markdown', :textile => 'textile', :txt => 'textile'}
	keyvals = {:tags => '', :markup => prefs[:markup], :slug => '', :draft => false, :layout => 'post'}
	subject = mail.subject

	#If there is no working subject, bail
	next if subject.empty?
	
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
	
	
	# if it doesn't contain the secret we can assume it to be spam
	next unless keyvals[:secret] == prefs[:secret]


	#Now remove any hash tags (like from Instagram)
	subject = subject.gsub(/ \#\w+/, '').strip

	body = ''

	#Is this multipart?
	if mail.multipart?
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

		#If the markup isn't html, try and use the
		#text if it exists. Anything else, use the html
		#version
		if txt_part > -1 and keyvals[:markup] != 'html'
			body = mail.parts[txt_part].body.decoded
		elsif html_part > -1
			body = mail.parts[html_part].body.decoded
		end
	else
		#Just grab the body no matter what it is
		body = mail.body.decoded
	end

	#If we have no body after all that, bail
	exit if body.strip.empty?

	#If it's html, run it through nokogiri to make sure it's clean
	if keyvals[:markup] == 'html'
		#body.gsub!(/[”“]/, '"')
		#body.gsub!(/[‘’]/, "'")
		body = Nokogiri::HTML::DocumentFragment.parse(body.strip).to_html
	end

	slug = subject.gsub(/[^[:alnum:]]+/, '-').downcase.strip.gsub(/\A\-+|\-+\z/, '')
	time = Time.now
	name = "%02d-%02d-%02d-%s.%s" % [time.year, time.month, time.day, slug, markup_extensions[keyvals[:markup].to_sym]]
	draft_filename = prefs[:path_to_drafts] + '/' + name
	post_filename = prefs[:path_to_posts] + '/' + name

	exit unless File.writable?(prefs[:path_to_posts])

	open(draft_filename, 'w') do |str|
		str << "---\n"
		str << "layout: #{keyvals[:layout]}\n"
		str << "title: '#{title}'\n"
		str << "date: %02d-%02d-%02d %02d:%02d:%02d\n" % [time.year, time.month, time.day, time.hour, time.min, time.sec]
		unless keyvals[:tags].empty?
			str << "tags: \n"
			keyvals[:tags].split(',').each do |string|
				str << "- " + string.strip + "\n"
			end
		end
		str << "---\n"
		str << body
	end
	# if this isn't a draft move it over to the posts directory
	unless keyvals[:draft] == 'true'
		FileUtils.mv(draft_filename, post_filename)
	end

end

Mail.delete_all()
