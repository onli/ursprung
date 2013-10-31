A small blogengine, using ruby, sinatra, browserid.

Originally, this was a basic, pre-alpha implementation of a distributed social network blog system,
created as an assessed assignment for the lecture [Security in Online Social Networks](http://www.uni-siegen.de/fb5/itsec/lehre/ss12/sec-osn-ss12/index.html), Siegen, summer semester 2012.

# Features

 * Frontend-Administration
 * Pingbacks and Trackbacks
 * Bayesian spamfilter
 * Autotitle (for links in entries)
 * Minimal design
 * Uses a template language, fully customizable
 * Integrated design selector
 * Cached

# Installation

If you have ruby installed, make sure that the `bundle` gem is installed. Then, run

    bundle install

to install the needed gems, and

    bundle exec ruby server.rb

to start the blog.


## Dependencies

 * ruby (1.9.3 or 2.0)
 * libxml2-dev 
 * libxslt1-dev