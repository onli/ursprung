A small blogengine, using ruby, sinatra, browserid.

Originally, this was a basic, pre-alpha implementation of a distributed social network blog system,
created as an assessed assignment for the lecture [Security in Online Social Networks](http://www.uni-siegen.de/fb5/itsec/lehre/ss12/sec-osn-ss12/index.html), Siegen, summer semester 2012.

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

 * ruby (1.9.3 or 2.0 or 2.1.1)
 * libxml2-dev 
 * libxslt1-dev
