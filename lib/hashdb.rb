require "hashdb/version"
require "./hashdb/table"
require "zlib"
require "json"

module Hashdb
    class Db < Hash
#  require 'hashdb'
#  db = Hashdb.new("data.db") #This reads or creates a database in the file  
    def initialize(a)
        @file = a
        @a  = super
        if File::exists? a
            begin
                Zlib::GzipReader.open(@file) do |gz|
                    x = JSON.parse(gz.read)
                    x.each{|k,v| @a.store(k,v)}
                end
            rescue Zlib::Error
                raise "We could not read any keys from #{a} the database may be corrupted"
            rescue JSON::ParserError    
                @a = super
                trig_json(a)
            end    
        else
            Zlib::GzipWriter.open(a).close  
            end    
    end
#Creating a table
    def create_table(name,base)
        tbase = name + "_base"
        @a.store(tbase,{})
        x = Table.new(name,base)
        @a[tbase] = base
        @a.store(name,[])
    end
#Deleting tables
    def delete_table(name)
        tbase = name + "_base"
        @a.delete(name)
        @a.delete(tbase)
    end
#Connect to a table
    def table(name)
        if @a.has_key? name
            tbase = name + "_base"
            x = Table.new(name,@a[tbase])
            x.inject(@a[tbase],@a[name])
            return x
        end
    end 
#List Tables
    def tables
        @a.keys
    end    
#This saves chages made in the current session
#  db.commit #saves the database  
    def commit
        Zlib::GzipWriter.open(@file) do |gz|
            gz.write(JSON.generate(@a))
        end
    end
#This writes your hash to a file in json format
#  db >> "data.json"  
    def >>(a)
        self.write_json(a)
    end
#This returns the path to your database
#  db.path  
    def path
        @file
    end
#This renames your database
#  db.rename("hash")  
    def rename(a)
        File.rename(@file,a)
        @file = a
    end
#This deletes your database
#  db.del 
    def del
        File.delete(@file)
    end
#This returns json from selected key
#  db.get_json("name") #=> {"name":"Ruby"} 
    def get_json(a)
        x = {}
        x.store(a,@a[a])
        JSON.generate(x)
    end
#This returns xml from a selected key
#   db.get_xml("name") #=> <name>Ruby</name>     
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
#  db.offload("data")
    def offload(a)
        Zlib::GzipWriter.open(a) do |gz|
            gz.write(JSON.generate(@a))
        end
    end
#This reloads data from the file
#  db  #=> {"name"=>"Ruby"}
#  db.clear   #=> {}
#  db.reload  #=> {"name"=>"Ruby"}   
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
#Tests an array not for external use 
    def isarray(e)
        if e.class == Array
            return true
        else
            return false
        end    
    end
#Tests a Hash not for external use     
    def ishash(e)
        if e.class == Hash
            return true
        else
            return false
        end    
    end
#This method generates xml from an array <b>note the prefixed 's' below</b> 
# db.array_to_xml("array",[2,5])  #=> <array><sarray>2</sarray><sarray>5</sarray></array>
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
#This is the method generates xml from a hash not just from the hashdb but from anywhere
# ex  #=> {"name"=>"Ruby","since"=>1993}
# db.hash_to_xml("data",ex)  #=> <data><name>Ruby</name><since>1993</since></data>   
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
#This is a JSON read Error    
    def trig_json(line)
        err = "JSON Error at #{line} if data/file is null continue else verify your data/file"
        puts err        
    end
    end
end