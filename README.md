# Vidibus::Permalink [![](http://travis-ci.org/vidibus/vidibus-permalink.png)](http://travis-ci.org/vidibus/vidibus-permalink) [![](http://stillmaintained.com/vidibus/vidibus-permalink.png)](http://stillmaintained.com/vidibus/vidibus-permalink)

This gem allows changeable permalinks. That may be an oxymoron, but it's really useful from a SEO perspective.

This gem is part of [Vidibus](http://vidibus.org), an open source toolset for building distributed (video) applications.

## Installation

Add the dependency to the Gemfile of your application:

```
  gem "vidibus-permalink"
```

Then call bundle install on your console.

## TODO

* Add controller extension for automatic dispatching.
* Limit length of permalinks.
* Refactor codebase so that incrementation is not limited to Permalink class.

## Ideas (for a separate gem)

* Catch 404s and store invalid routes.
* Make invalid routes assignable from a web interface.
* Try to suggest a matching Linkable by valid parts of the request path.

## Copyright

Copyright (c) 2010-2013 Andre Pankratz. See LICENSE for details.
