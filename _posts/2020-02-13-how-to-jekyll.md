---
layout: post
title: How to make a blog by using Jekyll
date: 2020-02-13
categories: [Manual]
tags: []
last_modified_at: 2020-02-13
---

### Installing Ruby
<p class="message">
  <small>Ruby version 2.7.0</small>
</p>

{% highlight shell %}
$ sudo apt install curl
$ curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
$ curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
$ echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

$ sudo apt-get update
$ sudo apt-get install git-core zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev nodejs yarn
{% endhighlight %}

**Installing with Using rbenv**
{% highlight shell %}
$ cd
$ git clone https://github.com/rbenv/rbenv.git ~/.rbenv
$ echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
$ echo 'eval "$(rbenv init -)"' >> ~/.bashrc
$ exec $SHELL
 
$ git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
$ echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
$ exec $SHELL
 
$ rbenv install 2.7.0
$ rbenv global 2.7.0
$ ruby -v
{% endhighlight %}

**Install bundler**
{% highlight shell %}
$ gem install bundler
$ rbenv rehash
{% endhighlight %}

**Install Jekyll & Make a new site**
{% highlight shell %}
$ gem install jekyll
$ jekyll new my-blog
$ cd my blog
$ bundle exec jekyll serve  # browse to http://localhost:4000
{% endhighlight %}

### Reference
* [Go Rails](https://gorails.com/setup/ubuntu/18.04)
* [Jekyll](https://jekyllrb.com/)
