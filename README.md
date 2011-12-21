# JekyllMail #

JekyllMail enables you to post to your [Jekyll](https://github.com/mojombo/jekyll) / [Octopress](http://octopress.org/) powered blog by email. 

## How it Works ##
Once configured (see below) JekyllMail will log into a POP3 account, check for messages with a pre-defined secret in the subject line, convert them into appropriately named files, and save them in your _posts or _drafts directory. After that your normal Jekyll watcher process can take over and do its thing.

**Warning:** At the end of every run JekyllMail *deletes every e-mail* in the account. This is for two reasons: 1) we don't want to have to maintain a list of what e-mails we've already ingested and posted 2) once an e-mail's been ingested we don't need it 3) there are probably 400 spam e-mails in the account that should be deleted. 4) less e-mail in the box means faster runs.... ok four reasons.

## Usage ##
The magic is all in the subject line. In order to differentiate your email from the spam that's almost guaranteed to find your account eventually suck in the appropriate metadata A subject line for JekyllMail has two parts the title (of your post) and the metadata which will go into the YAML frontmatter Jekyll needs. The metadata is a series of key value pairs separated by slashes. One of those key value pairs *must* be "secret" and the secret listed in your configuration. Note that the keys must contain no spaces and be immediately followed by a colon. 

	<subject> || key: value / key: value / key: value, value, value
An example:

	My Awesome Post || secret: more-1337 / tags: awesome, excellent, spectacular

Your secret should be short, easy to remember, easy to type, and very unlikely to show up in an e-mail from another human or spammer. 

Your e-mail can be formatted in Markdown, Textile, or HTML.

### Subject Metadata ###
There are a handful of keys that JekyllMail is specifically looking for. All of these are optional except "secret":

* published: defaults to true. Set this to "false" if you want this post to be saved in the _drafts folder.
* markup: can be: html, markdown, md, textile, txt (textile)
* tags: expects a comma separated list of tags for your post
* slug: the "slug" for the file-name. E.g. yyyy-mm-dd-*slug*.extension 

### Images ###
Image attachments will be extracted by JekyllMail and placed in dated directory that corresponds with the date of the posting.

For example If you attached flag.jpg to a post sent on July 4th 2012 it would be stored in <images_dir>/2012/07/04/flag.jpg

*Eventually* JekyllMail will look for the image tags in your document that reference the image filename and update them to point to the correct published file path. For example it would convert \!\[alt text\]\(flag.jpg\) in a Markdown document to  \!\[alt text\]\(http://path/to/images/dir/2012/07/04/flag.jpg\). **But** for the moment you're going to have to manually reference the easily predictable location where it will be stored. 

## Configuration ##
If you're using Jekyll you're using git. JekyllMail is configured via its own section of you global [git config](http://kernel.org/pub/software/scm/git/docs/git-config.html).

	[jekyllmail]
		postsDir = /path/to/my\_jekyll\_site/source/_posts
		draftsDir = /path/to/my\_jekyll\_site/source/_drafts
		imagesDir = /path/to/my\_jekyll_site/images
		popServer = mail.example.com
		popPassword = 1x2x3fdc3
		popUser = jekyllmail@example.com
		secret = easy-to-remember-hard-to-guess
		defaultMarkup = markdown

You can add these to your ~/.gitconfig by editing it directly or by commands like the following: 

	git config --global add jekyllmail.postsDir /path/to/my_jekyll_site/source/_posts

Please note that paths must *not* end with a slash.
Your popUser doesn't have to be an e-mail address. It might just be "jekyllmail", or whatever username you've chosen for the e-mail account. It all depends on how your server is configured. 

### Known Issues ###
Check out the [Issues page](https://github.com/masukomi/JekyllMail/issues) on Github for the current list of known issues. 

## Credit where credit is due ##
JekyllMail was based on a [post & gist](http://tedkulp.com/2011/05/18/send-email-to-jekyll/) by [Ted Kulp](http://tedkulp.com/). He did all the heavy lifting. JekyllMail is simply a more generic version that speaks POP3, is more spam resistent, and should work for anyone.

## License ##
JekyllMail is distributed under the [MIT License](http://www.opensource.org/licenses/mit-license.php).


