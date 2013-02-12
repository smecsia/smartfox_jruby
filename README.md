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

    request(:BuyProduct,
                    :productId => data[:data].first[:id],
                    :serialize_opts => {:productId => :long}).
      expect(:BuyProductOK) { |data|
          puts "Whoa! I've bought product! #{data.to_json}"
      }
  }
}
adapter.disconnect!

```

Copyright (c) 2013 smecsia

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.