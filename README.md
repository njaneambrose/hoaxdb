# Hashdb

Hashdb is a simple implementation of a database written in 100% pure ruby. It offers an interface to insert,update,query and delete records like any other databse but does not offer complex features of a database. You set specific data types for your fields and you can also have default values on top of that it validates the records you enter. In terms of queries you can choose specific fields, limits and also sort according to a specific field which can be ascending or descending. Queries are written using ruby hence no external knowledge is needed.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hashdb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hashdb

## Usage

Using the hashdb is very simple once you have installed it, the following are the basics:
#### Creating a table

    require 'hashdb'
    db = Hashdb.new('products.db') #This reads an existing database or creates a database
    db.create_table("products",{
       "name"=>{"type"=>"String","default"=>""}, #setting default prevents nil values
       "price"=>{"type"=>"Float","default"=>0.0}
    })
#### Inserting a record

    products.insert({"name"=>"Iphone","price"=>100.67}) #insert a record
    
#### Updating  a record

     products.update('this["name"].eql? "Iphone"',{"quantity"=>200})
    
#### Selecting records    
     
     products.select_if('this["name"].eql? "Iphone"')
     
#### Deleting records

    products.del_if('this["name"].eql? "Iphone"')

More information is available via rdoc when the gem is installed
    
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/njaneambrose/hashdb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
