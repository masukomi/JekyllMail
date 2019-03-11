class JMail
  MARKUP_EXTENSIONS = { :html => "html", :markdown => "md", :md => "md", :textile => "textile", :txt => "textile" }
  @files_to_commit = []
  attr_reader :files_to_commit

  def initialize(blog, logger)
    @blog = blog
    @logger = logger
  end


  #TODO: OMG THIS IS WAY TOO LONG
  def process_mail(mail)
    @files_to_commit = []
    keyvals = {
      :tags      => "", # a YAML array
      :markup    => @blog.markup,
      :slug      => nil,
      :published => true,
      :layout    => "post",
    }

    subject = mail.subject

    return false unless is_subject_valid?(subject, keyvals)

    # vvv -- updates the contents of keyvals
    # and adds kevals[:title]
    keyvals = extract_data_from_subject(subject, keyvals)
    return false unless is_secret_valid?(@blog, keyvals[:secret], subject)
    @logger.log("XXX secret was valid")
    keyvals = update_and_infer_keyvals(@blog, keyvals)
    body = ""
    images_needing_replacement = {}
    if mail.multipart?
      #vvv updates images_needing_replacement
      body = process_multipart_mail(mail, body, images_needing_replacement, keyvals)
    else
      #Just grab the body no matter what it is
      body = mail.body.decoded
    end
    #If we have no body after all that, bail
    @logger.log("XXX will return if body empty")
    return false if body.strip.empty?

    @logger.log("XXX body wasn't empty")

    body = cleanup_html_and_replace_images(
      body,
      keyvals[:markup],
      images_needing_replacement
    )

    @logger.log("XXX calling write_to_disk")
    write_to_disk(body, keyvals)
    @logger.log("XXX wrote to disk")

    log_files_to_commit(@files_to_commit) if @files_to_commit.size > 0


    if @blog.add_to_git? and @files_to_commit.size() > 0
      @blog.commit(@files_to_commit, keyvals[:slug])
    end

    return @files_to_commit.size > 0
  end

  def log_files_to_commit(files_to_commit)
    message = "JekyllMail ingested these files:"
    files_to_commit.each do |f|
      message += "\n\t#{f}"
    end
    @logger.log(message, true)
    message
  end

  def cleanup_html_and_replace_images(body, markup, images_needing_replacement)
    body = cleanup_html(body, markup)
    body = replace_all_images(
      images_needing_replacement,
      body,
      markup
    )
    body
  end

  def cleanup_html(body, markup)
    return body if markup != 'html'
    Nokogiri::HTML::DocumentFragment.parse(body.strip).to_html
  end

  def replace_all_images(images_needing_replacement, body, markup)
    images_needing_replacement.each do |filename, path|
      body = replace_images(body, markup, filename, path)
    end
    body
  end

  def replace_images(body, markup, filename, path)
    case markup
    when 'markdown'
      return replace_markdown_images(body, markup, filename, path)
    when 'textile'
      return replace_textile_images(body, markup, filename, path)
    when 'html'
      return replace_html_images(body, markup, filename, path)
    else
      raise "Unrecognized markup for image replacement: \"#{markup}\""
    end
  end

  def set_name_and_time(keyvals)
    time = Time.now
    keyvals[:name] = "%02d-%02d-%02d-%s.%s" % [time.year, time.month, time.day, keyvals[:slug], MARKUP_EXTENSIONS[keyvals[:markup].to_sym]]
    keyvals[:time] = time
    keyvals
  end

  def set_slug(keyvals)
    keyvals[:slug] ||= keyvals[:title].gsub(/[^[:alnum:]]+/, "-").downcase.strip.gsub(/\A\-+|\-+\z/, "")
    @logger.log("new slug: #{keyvals[:slug]} from title: #{keyvals[:title]}")
    keyvals
  end

  def update_and_infer_keyvals(blog, keyvals)
    keyvals.delete(:secret)
    keyvals = set_slug(keyvals)
    keyvals = set_name_and_time(keyvals) # needs a slug
    keyvals
  end

  def is_secret_valid?(blog, test_secret, subject)
    # if it doesn't contain the secret we can assume it to be spam
    valid = (blog.secret == test_secret)
    @logger.log(
      "skipping email with invalid / non-existent secret.\n\tSubject:#{subject}\n\tSecret was: \"#{test_secret}\"",
      true) unless valid
    return valid
  end

  def is_subject_valid?(subject, keyvals)
    # <subject> || key: value / key: value / key: value, value, value
    @logger.log("processing email with subject: #{subject}")
    return false if subject.strip.empty?
    return false unless /\s*\S+.*\|\|/.match(subject)
    return false unless /[\/ ]secret: \S+/.match(subject)
    return true
  end
  def extract_data_from_subject(subject, keyvals)
    (title, raw_data) = subject.split(/\|\|/) # two pipes separate subject from data
    title.gsub!(/^\s+|\s+$/, "")
    unless raw_data.nil?
      datums = raw_data.split("/")
      datums.each do |datum|
        next if datum.nil?

        (key, val) = datum.split(/:\s?/)
        key.gsub!(/\s+/, "")
        val.gsub!(/\s+$/, "")
        keyvals[key.to_sym] = val
      end
    end
    keyvals[:title] = title
    keyvals
  end

  # TODO: refactor me into multiple methods
  def process_multipart_mail(mail, body, images_needing_replacement, keyvals)
    html_part = -1
    txt_part = -1

    #Figure out which part is html and which
    #is text
    mail.parts.each_with_index do |p, idx|
      if p.content_type.start_with?("text/html")
        html_part = idx
      elsif p.content_type.start_with?("text/plain")
        txt_part = idx
      end
    end

    mail.attachments.each do |attachment|
      #TODO: break this out into a separate method.
      if (attachment.content_type.start_with?("image/"))
        attachment_filename = attachment.filename
        images_dir = @blog.images_dir_under_jekyll + ("/%02d/%02d/%02d" % [keyvals[:time].year, keyvals[:time].month, keyvals[:time].day])
        local_images_dir = "#{@blog.jekyll_dir}/#{images_dir}"
        FileUtils.mkdir_p(local_images_dir)
        puts "local_images_dir: #{local_images_dir}"
        images_needing_replacement[attachment_filename] = "/#{images_dir}/#{attachment_filename}"
        puts "image url: #{images_needing_replacement[attachment_filename]}"
        begin
          local_filename = "#{@blog.jekyll_dir}/#{images_dir}/#{attachment_filename}"
          @logger.log("saving image to #{local_filename}")
          unless File.writable?(local_images_dir)
            $stderr.puts("ERROR: #{local_images_dir} is unwritable. Exiting.")
          end
          File.open(local_filename, "w+b", 0644) { |f| f.write attachment.body.decoded }
          # @files_to_commit << "#{images_dir}/#{attachment_filename}"
          @files_to_commit << local_filename
        rescue Exception => e
          $stderr.puts "Unable to save data for #{attachment_filename} because #{e.message}"
        end
      end
    end

    #If the markup isn't html, try and use the
    #text if it exists. Anything else, use the html
    #version
    if txt_part > -1 and keyvals[:markup] != "html"
      body = mail.parts[txt_part].body.decoded
    elsif html_part > -1
      body = mail.parts[html_part].body.decoded
    end
    body
  end

  def write_to_disk(body, keyvals)
    post_filename = "#{@blog.posts_dir}/#{keyvals[:name]}"

    if File.writable?("#{@blog.posts_dir}")
      @logger.log("saving post to #{post_filename}")
      open(post_filename, 'w'){|f|
        f.puts body
      }
    else
      $stderr.puts "ERROR: #{@blog.posts_dir} is not writable"
      exit 0
    end
    open(post_filename, "w") do |str|
      str << "---\n"
      str << "title: '#{keyvals[:title]}'\n"
      str << "date: %02d-%02d-%02d %02d:%02d:%02d\n" % [keyvals[:time].year, keyvals[:time].month, keyvals[:time].day, keyvals[:time].hour, keyvals[:time].min, keyvals[:time].sec]
      keyvals.keys.sort.each do |key|
        if key != :tags and key != :slug
          str << "#{key}: #{keyvals[key]}\n"
        elsif key == :tags
          unless keyvals[:tags].empty?
            str << "tags: \n"
            keyvals[:tags].split(",").each do |string|
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

  private

  def replace_markdown_images(body, markup, filename, path)
    return body if markup != 'markdown'
    body.gsub(/(\(|\]:\s|<)#{Regexp.escape(filename)}/, "\\1#{path}")
  end

  def replace_textile_images(body, markup, filename, path)
    return body if markup != 'textile'
    body.gsub(/!#{Regexp.escape(filename)}(!|\()/, "!#{path}\\1")
  end

  def replace_html_images(body, markup, filename, path)
    return body if markup != 'html'
    body.gsub(/(src=(?:'|")|href=(?:'|"))#{Regexp.escape(filename)}/i, "\\1#{path}")
    # WARNING: won't address urls in css
    # Is case insensitive so it won't differentiatee FOO.jpg from foo.jpg or FoO.jpg
    # people shouldn't be using the same name for different files anyway. :P
  end
end
