require "hashdb/version"
require "hashdb/table"
require "zlib"
require "json"
require "thread"

module Hashdb
#=Introduction
#Hashdb is a small implementation of a database using a Hash and JSON for storage written in 100% pure ruby. It allows you to create, update, query and delete records.
#It also allows you to set specific data types for your fields, default values and validates input. In terms of queries you can set limits, select specific fields, sort by a field and also set a limit for the query.
#==Field rules
# Use string keys like ["products"] not [:products] due to JSON nature of storage
#==Data types
#The currently supported data types are
#   Hash, DateTime, Date, Boolean, Float, Integer, Array & String
#==Saving your work
# #=> Never forget to call  
# db.commit 
# #=> to save the current changes
#==Querying rules:
#   1. "this" is used to refrence the current row e.g: this["price"] indicates the current row price
#   2. The syntax this[.. is used for queries if not * for all rows
#   3. For equality use .eql? not ==..
#check the querying section for examples
#==Updating rules:
#   1. All rules for querying above apply
#   2. To edit the current value use $ e.g an Array do: {"array"=>"$.push('value')"}, $ refrences the current value and must be called in a string as the first character
#check the updating section for examples
#
#====CAUTION: Do not use Hashdb for extreme loads due to speed
#
#==Creating a table
#Creating a table is very easy as first you need to connect to a database file then:
#   require 'hashdb'
#   db = Hashdb.new('products.db') #This reads an existing database or creates a database
#   db.create_table("products",{
#       "name"=>{"type"=>"String","default"=>""}, #setting default prevents nil values
#       "price"=>{"type"=>"Float","default"=>0.0},
#       "quantity"=>{"type"=>"Integer","default"=>100},
#       "shipped"=>{"type"=>"Date"}
#   })
#This creates a simple table with three fields
#==Inserting Records
#The next step is just a simple as the one above, this is a continuation from above:
#   products = db.table("products") #this connects to the products table
#   products.insert({"name"=>"Iphone","price"=>100.67,"shipped"=>Date.new(2018,6,30)}) #insert a record
#   products.insert({"name"=>"Cable Tvs","price"=>390.67,"shipped"=>Date.new(2018,9,12),"quantity"=>400}) #insert another record
#   p products.data  #=> [{"name"=>"Iphone","price"=>100.67,"quantity"=>100,shipped=>"2018-6-30"},{"name"=>"Cable Tvs","price"=>390.67,"quantity"=>400,shipped=>"2018-9-12"}]
#==Querying records
#   #=>select_if('condtion * for all',[array of the fields you want * for all],limit -1 for no limit,"sort field must be in the fields array",desc=true/false)
#   #=> condition * indicates all rows
#   products.select_if('*',["name","price"]) #=> [{"name"=>"Iphone","price"=>100.67},{"name"=>"Cable Tvs","price"=>390.67}]
#   products.select_if('*',["name","price"],-1,"price") #=> [{"name"=>"Cable Tvs","price"=>390.67},{"name"=>"Iphone","price"=>100.67}]
#   products.select_if('*',["name","price"],-1,"price",true) #=> [{"name"=>"Iphone","price"=>100.67},{"name"=>"Cable Tvs","price"=>390.67}]
#   products.select_if('this["price"] > 300',['name','price']) #=> [{"name"=>"Cable Tvs","price"=>390.67}]
#   products.max("price") #=> 390.67
#   products.min("price") #=> 100.67
#   products.avg("price") #=> 245.67
#   products.sum("price") #=> 491.34
#==Updating records
#   #=> table.update('condition * for all',{new values})
#   #=> condition * indicates all rows
#   #Incase of a 15% price increase in products do this to update
#   products.update('*',{"price"=>"$ = this[\"price\"]*1.15"}) #=> Here you see how the $ symbol is used to update the existing value
#   products.update('this["name"].eql? "Iphone"',{"quantity"=>200})
#==Deleting records
#   #=> table.del_if('condition')
#   products.update('this["name"].eql? "Iphone"')
#   p products.data #=> [{"name"=>"Cable Tvs","price"=>390.67,"quantity"=>400,shipped=>"2018-9-12"}]
#==Adding fields
#   products.add_column("remaining",{"type"=>"Integer","default"=>0})
#   p products.base  #=> [{"name"=>{"type"=>"String","default"=>""},"price"=>{"type"=>"Float","default"=>0.0},"quantity"=>{"type"=>Integer","default"=>100}, "shipped"=>{"type"=>"Date","default"=>nil},{"remaining"=>{"type"=>"Integer","default"=>0}}]
#==Deleting fields
#   products.drop_column("remaining")
#   p products.base #=> [{"name"=>{"type"=>"String","default"=>""},"price"=>{"type"=>"Float","default"=>0.0},"quantity"=>{"type"=>Integer","default"=>100}, "shipped"=>{"type"=>"Date","default"=>nil}]
    class Db
    def initialize(a)
        @file = a
        @a  = {}
        thr = Thread.new do 
            if File::exists? a
                begin
                    Zlib::GzipReader.open(@file) do |gz|
                        x = JSON.parse(gz.read)
                        x.each{|k,v| @a.store(k,v)}
                    end
                rescue Zlib::Error
                    raise "We could not read any keys from #{a} the database may be corrupted"
                rescue JSON::ParserError    
                    @a = {}
                    trig_json(a)
                end 
            else
                Zlib::GzipWriter.open(a).close  
            end
        end
        thr.join    
    end
    def create_table(name,base)
        if @a.has_key? name
            raise "Table #{name} already exists"
        end
        tbase = name + "_base"
        @a.store(tbase,{})
        x = Table.new(name,base)
        @a[tbase] = base
        @a.store(name,[])
    end
    def drop_table(name)
        tbase = name + "_base"
        @a.delete(name)
        @a.delete(tbase)
    end
    def table(name)
        if @a.has_key? name and !name.match(/_base$/)
            tbase = name + "_base"
            x = Table.new(name,@a[tbase])
            x.inject(@a[tbase],@a[name])
            return x
        elsif name.match(/_base$/)
            raise "#{name} cannot be edited directly"
        else
            raise "Table #{name} does not exist"
        end
    end 
#Lists all the tables in the database
    def tables
        @a.keys
    end
#Deletes all tables in the database
    def clear
        @a.clear
    end
#This saves chages made in the current session
#  db.commit #saves the database  
    def commit
        thr = Thread.new do
            Zlib::GzipWriter.open(@file) do |gz|
                gz.write(JSON.generate(@a))
            end
        end 
        thr.join    
    end
#This writes your database to a file in json format
#  db >> "data.json"  
    def >>(a)
        f = File.open(a,'w')
        f << @a.to_json
        f.close
    end
#This returns the path to your database
#  db.path  
    def path
        @file
    end
#This renames your database
#  db.rename("hash.db")  
    def rename(a)
        File.rename(@file,a)
        @file = a
    end
#This deletes your database
#  db.del 
    def del
        File.delete(@file)
    end
#This returns JSON from selected table
#  db.get_json("products")
    def get_json(a)
        x = {}
        x.store(a,@a[a])
        JSON.generate(x)
    end
#This returns XML from a selected table
#   db.get_xml("products")   
    def get_xml(a)
        r = ""
        if ishash(@a[a])
            r = self.hash_to_xml(a,@a[a])
        elsif isarray(@a[a])
            r = self.array_to_xml(a,@a[a])
        else
           r = "<#{a}>#{@a[a]}</#{a}>"
        end
        r    
    end    
#This offloads the hashdb to a file other than the current file and  can also be used for backup pourposes
#  db.offload("backup.db")
    def offload(a)
        Zlib::GzipWriter.open(a) do |gz|
            gz.write(JSON.generate(@a))
        end
    end
#This reloads data from the file and discards unsaved changes  
    def reload
        @a.clear
        if File::exists? @file
            begin
                Zlib::GzipReader.open(@file) do |gz|
                    x = JSON.parse(gz.read)
                    x.each{|k,v| @a.store(k,v)}
                end
            rescue Zlib::Error
                raise "We could not reload #{@file} it may be corrupted"
            rescue JSON::ParserError
                trig_json(@file)
            end    
        else
            Zlib::GzipWriter.open(a).close  
        end
    end
    def isarray(e)
        if e.class == Array
            return true
        else
            return false
        end    
    end    
    def ishash(e)
        if e.class == Hash
            return true
        else
            return false
        end    
    end
    def array_to_xml(k,a)
        sub = "<#{k}>"
        a.each{|o|
            if isarray(o)
                sub << array_to_xml("array",o);
            elsif ishash(o)
                sub << hash_to_xml("hash",o)
            else
                sub << "<s#{k}>#{o}</s#{k}>"
            end    
        }
        sub << "</#{k}>"
        sub    
    end 
    def hash_to_xml(x,k)
        sub = "<#{x}>"
        k.each do |q,v|
            if isarray(v)
                sub << array_to_xml(q,v);
            elsif ishash(v)
                sub << "<#{q}>"
                v.each{|t,b|
                    if isarray(b)
                        sub << array_to_xml(t,b)
                    elsif ishash(b)
                        sub << hash_to_xml(t,b);
                    else
                        sub << "<#{t}>#{b}</#{t}>"
                    end
                }
                sub << "</#{q}>"
            else
               sub << "<#{q}>#{v}</#{q}>" 
            end    
        end
        sub << "</#{x}>"
        sub
    end   
    def trig_json(line)
        err = "JSON Error at #{line} if data/file is null continue else verify your data/file"
        puts err        
    end
    end
end