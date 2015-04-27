A small blogengine using ruby, sinatra, sqlite and browserid.

![ursprung example](https://onli.github.io/ursprung/public/ursprung-index_tiny.png)

# Features

 * Write Entries with Markdown
 * Comments, Pingbacks and Trackbacks
 * Bayesian spamfilter
 * Frontend-Administration
 * Autotitle (for links in entries)
 * Support for other Designs (themeable)
 * Minimal design as default
 * Cached

# Installation

Download the files from the repository. If you have ruby installed, make sure that the `bundle` gem is installed. Then, run

    bundle install

to install the needed gems, and

    rackup -E production -p PORT

to start the blog.


## Dependencies

 * ruby >= 2.0
 * libxml2-dev 
 * libxslt1-dev
