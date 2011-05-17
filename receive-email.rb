#!/usr/bin/env ruby
# -*- coding: utf-8 -*- #specify UTF-8 (unicode) characters

#Email to Jekyll script
#(c)2011 Ted Kulp <ted@tedkulp.com>
#MIT license -- Have fun
#Most definitely a work in progress

#Mail is an awesome gem. Install it.
require 'rubygems'
require 'mail'
require 'nokogiri'

#Change me
path_to_posts = '/Users/tedkulp/Dropbox/tedkulp.com/_posts'
path_to_drafts = '/Users/tedkulp/Dropbox/tedkulp.com/_drafts'

path_to_posts = '/home/tedkulp/Dropbox/tedkulp.com/_posts'
path_to_drafts = '/home/tedkulp/Dropbox/tedkulp.com/_drafts'

#Grab message that was piped
message = $stdin.read

#If there is no working message, bail
exit if message.nil? or message.strip.empty?

#Parse it, baby
mail = Mail.new(message)

markup_extensions = {:html => 'html', :markdown => 'markdown', :md => 'markdown', :textile => 'textile', :txt => 'textile'}
keyvals = {:tags => '', :markup => 'html', :slug => '', :draft => false, :layout => 'post'}
subject = mail.subject

#Regex to grab all the of ((key: value)) sets in the subject
tags_regex = /\(\((\w+): ?([^\)]+)\)\)/

#Loop through and put them into the keyvals if we care about that key
subject.scan(tags_regex) do |key,value|
	keyvals[key.to_sym] = value if !key.empty? and keyvals.has_key?(key.to_sym)
end

#And now strip the subject of those so that it's just the text we
#want for the post's subject
subject = subject.gsub(tags_regex, '').strip

#If the draft keyval has anything over than false, use the drafts folder instead
path_to_posts = path_to_drafts if keyvals[:draft] != false

#If there is no working subject, bail
exit if subject.empty?

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
filename = path_to_posts + '/' + name

exit unless File.writable?(path_to_posts)

open(filename, 'w') do |str|
	str << "---\n"
	str << "layout: #{keyvals[:layout]}\n"
	str << "title: '#{subject}'\n"
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
