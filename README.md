A small blogengine using ruby, sinatra, sqlite and [Portier](https://portier.github.io/).

![ursprung example](https://onli.github.io/ursprung/public/ursprung-index_tiny.png)

# Features

 * Write Entries with Markdown
 * Comments, Pingbacks and Trackbacks
 * Bayesian spamfilter
 * Frontend-Administration
 * Autotitle (for links in entries, cached)
 * Support for other Designs (themeable)
 * Minimal design as default
 * Support for and shipping with some themes of [the classless project](https://github.com/websitesfortrello/classless/)

# Installation

Download the files from the repository. If you have ruby installed, make sure that the `bundle` gem is installed. Then, run

    bundle install

to install the needed gems, and

    rackup -E production -p PORT

to start the blog.

To log in after the instalallation, visit `/login`.


## Dependencies

 * ruby >= 2.0
