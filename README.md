# SmartFox Server client library for JRuby (extension requests testing).

This is a small library helping you to interact with a SmartFox server.
It's main purpose is to test the backend extension using the requests.
It requires JRuby and some jar-dependencies in a classpath.

## What it gives

You can easily connect and interact with a SmartFox server to test your server extension requests

```ruby
adapter = SmartfoxJruby::SfsAdapter.new
adapter.login_as("user", "password")
adapter.connect!(
    :host => "localhost",
    :port => 9933,
    :zone => "test-zone"
)

adapter.process! {
  # create extension request
  request(:GetProducts, :productType => :ITEM).expect(:GetProductsOK) { |data|
    puts "Whoa! I've got the following products: #{data.to_json}"

    request(:BuyProduct, {:productId => data[:data].first[:id]},
                        :serialize_opts => {:productId_type => :long}
      ).expect(:BuyProductOK) { |data|
          puts "Whoa! I've bought product! #{data.to_json}"
      }
  }
}
adapter.disconnect!

```

## How to install

```
jruby -S gem install smartfox_jruby
```

## How to run [requirements]

You can run it manually by downloading and requiring all the dependent jars in your ruby code, or you can use the tool
called [Doubleshot](https://github.com/sam/doubleshot). You can also use [JrmvnRunner](https://github.com/smecsia/jrmvnrunner)
to specify these java libraries as a dependencies:

* com.smartfox2x.client:sfs2x-client-core:jar:1.0.4
* com.smartfox2x.client:sfs2x-api-java:jar:1.0.4
* org.slf4j:slf4j-log4j12:jar:1.5.10
* io.netty:netty:jar:3.5.3.Final
* commons-beanutils:commons-beanutils:jar:1.7.0
* net.sf.ezmorph:ezmorph:jar:1.0.6
* net.sf.json-lib:json-lib:jar:jdk5:2.2.3
* commons-lang:commons-lang:jar:2.5
* commons-collections:commons-collections:jar:3.2.1
* commons-logging:commons-logging:jar:1.1.1

Copyright (c) 2013 smecsia

```
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
       http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

