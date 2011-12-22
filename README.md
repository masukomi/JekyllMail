# JekyllMail #

JekyllMail enables you to post to your [Jekyll](https://github.com/mojombo/jekyll) 
or [Octopress](http://octopress.org/) powered blog by email. 

## How it Works ##
Once configured (see below) JekyllMail will log into a POP3 account, check for messages with 
a pre-defined secret in the subject line, convert them into appropriately named files, and 
save them in your `_posts` directory. Images will be extracted and saved in a date specific 
directory under your `images` directory. 

Once it's placed those files there it will (optionally) also add them to your blog's git repo. 
This will work even if it's a bare repo and the `source` directory you had it save files under 
is in a detached worktree.



## Usage ##
The magic is all in the subject line. In order to differentiate your email from the spam that's almost guaranteed to find your account eventually suck in the appropriate metadata A subject line for JekyllMail has two parts the title (of your post) and the metadata which will go into the YAML frontmatter Jekyll needs. The metadata is a series of key value pairs separated by slashes. One of those key value pairs *must* be "secret" and the secret listed in your configuration. Note that the keys must contain no spaces and be immediately followed by a colon. 

	<subject> || key: value / key: value / key: value, value, value
An example:

	My Awesome Post || secret: more-1337 / tags: awesome, excellent, spectacular

Your secret should be short, easy to remember, easy to type, and very unlikely to show up in an e-mail from another human or spammer. 

Your e-mail can be formatted in Markdown, Textile, or HTML.

### Subject Metadata ###
There are a handful of keys that JekyllMail is specifically looking for in the subject.  
**All of these are optional except "secret"**:

* published: defaults to true. Set this to "false" to prevent the post from being published.
* markup: can be: html, markdown, md, textile, txt (textile)
* tags: expects a comma separated list of tags for your post
* slug: the "slug" for the file-name. E.g. yyyy-mm-dd-*slug*.extension 

### Images ###
Image attachments will be extracted by JekyllMail and placed in dated directory 
that corresponds with the date of the posting.

For example If you attached flag.jpg to a post sent on July 4th 2012 it would be 
stored in <images_dir>/2012/07/04/flag.jpg


JekyllMail will look for the image tags in your document that reference the image 
filename and update them to point to the correct published file path. For example 
it will convert \!\[alt text\]\(flag.jpg\) in a Markdown document to 
\!\[alt text\]\(http://example.com/path/to/images/dir/2012/07/04/flag.jpg\). 
Textile and HTML posts are also supported. 

In practice this simply means that if you insert a \!\[alt text\]\(flag.jpg\) 
tag and attach an image named flag.jpg to the same email everything will 
show up as expected in your post even though JekyllMail has moved that image 
off to a dated subdirectory (just like the post's url).

## Installation ## 
Checkout this git repo on your server, cd into the resulting directory, and 
run `bundle install` to make sure all the required gems are present.


## Configuration ##
JekyllMail is configured via a \_config.yml file in its root directory. 
Within this are a series of "blog" stanzas one for each blog you'll have 
it checking mail for. 

A single blog config file will look something like this

	blogs: 
	- jekyll_repo: /full/path/to/jekyll/repo
	  source_dir: /full/path/to/jekyll/source
	  pop_server: mail.example.com
	  pop_user: jekyllmail@example.com
	  pop_password: mypassword
	  secret: a_secret
	  markup: markdown
	  site_url: http://blog.example.com
	  commit_after_save: true

### Configuration Notes ###
The `secret` is a short piece of text that must appear in the subject of 
each email. This is used to filter out the spam and will never be posted.

If `commit_after_save` is true JekyllMail will add and commit any new post 
and images to the repo specified in `jekyll_repo`.

The `source_dir` must be the absolut paths to the directory containing 
the `_posts` and `images` directories. JekyllMail does not 
currently support a configuration where these directories live elsewhere.
However, this is where 

Please note that paths must *not* end with a slash.
Your `pop_user` doesn't have to be an e-mail address. It might just be 
"jekyllmail", or whatever username you've chosen for the e-mail account. 
It all depends on how your server is configured. It's probably best to use
something other than "jekyllmail" though. 

## Cron Jobs ##
You need to schedule two tasks to run regularly: JekyllMail itself, and 
a script to kick-off the generation of new HTML files once JekyllMail has 
done its job and commited the new files to your blog's git repo.

There are a variety of ways to accomplish this. The simplest way is 
probably to create a shell script.

To kick of JekyllMail it might look something like this:

	#!/bin/sh
	cd /full/path/to/jekyllmail
	bundle exec ruby jekyllmail.rb

To kick off the generation of the new HTML you'll need a second 
script like this: 

	#!/bin/sh
	cd /full/path/to/blogs/worktree
	bundle exec rake generate

Depending on your server's ruby / gem configuration you may have to add some 
additional info to the top of those ( just below the `#!/bin/sh` ). On a system 
with a locally installed RVM and gems directory the top of your script might 
look something like this:

	#!/bin/sh
	[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
	GEM_PATH=$GEM_PATH:/home/my_username/.gems
	PATH=$PATH:/home/my_username/.gems/bin

To help get you started check out the `run_jekyllmail.sh` and `build_site.sh` 
scripts that come along with the repo.

For more information on configuring Jekyll/Octopress to generate HTML server-side 
see this post on [Serving Octopress from a Self-Hosted Git Repository](http://weblog.masukomi.org/2011/12/19/serving-octopress-from-a-self-hosted-git-repository/)

Save the file anywhere that isn't served up to the public, make it executable, 
and add a new line to your [crontab](http://crontab.org/) to run it every five 
minutes or so. 


## Warning ##
At the end of every run JekyllMail *deletes every e-mail* in the account. 
This is for two reasons: 

1. We don't want to have to maintain a list of what e-mails we've already ingested and posted
2. Once an e-mail's been ingested we don't need it
3. There are probably 400 spam e-mails in the account that should be deleted anyway. 
4. less e-mail in the box means faster runs

Ok, four reasons.


### Known Issues ###
Check out the [Issues page](https://github.com/masukomi/JekyllMail/issues) on 
Github for the current list of known issues (if any). 

## Credit where credit is due ##
JekyllMail was based on a [post & gist](http://tedkulp.com/2011/05/18/send-email-to-jekyll/) 
by [Ted Kulp](http://tedkulp.com/), but has come a long way since then.

## License ##
JekyllMail is distributed under the [MIT License](http://www.opensource.org/licenses/mit-license.php).


