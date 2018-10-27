require "hashdb/version"
require "zlib"
require "json"

module Hashdb
#=Introduction
#This is a simple key and value database based on a hash that gives with rich data manipulating methods,
#It inherits a Hash hence all the methods of a hash are possible plus the methods below.
#
#For flexibility and convenience of keys due to the json nature of storage use:
#  {"name"=>"Me"} not {:name =>"Me"} or {name:"Me"}
#When adding or doing any operation on the hashdb
#=About
#Although this is a key and value based database i prefer to call it a key and hash based database with support for web routes like queries using hpath:
#  db   #=> {"ruby"=>{"author"=>"Matz","since"=>1993,"contributors"=>['kro','blah'],"popular"=>"back end"}}
#Taking the example above you can use hpath_get which imitates website routes e.g:
#  db.hpath_get("ruby/author")  #=> "Matz"
#  db.hpath_get("ruby/contributors")  #=> ['kro','blah']
#  db.hpath_get("ruby/popular")  #=> "back end"
#Equally setting methods are supported e.g:
#  db.hpath_set("ruby/author","Yukihoro Matsumoto")
#  db.hpath_set("ruby/contributors",['Me','You'])
#  db   #=> {"ruby"=>{"author"=>"Yukihoro Matsumoto","since"=>1993,"contributors"=>['Me','You'],"popular"=>"back end"}}   
    class Db < Hash
#Initialize a Hashdb with <b>if name is not pass as it tells that you do not want to load all values from one hashdb but from various</b>:
#  require 'hashdb'
#  db = Hashdb.new("data") #This reads or create a database in the file  
    def initialize(a)
        @file = a
        @a  = super
        if !a.eql? "pass"
            if File::exists? a
                begin
                    Zlib::GzipReader.open(@file) do |gz|
                        x = JSON.parse(gz.read)
                        x.each{|k,v| @a.store(k,v)}
                    end
                rescue JSON::ParserError,Zlib::Error
                    raise "We could not read any keys from #{a} the database may be corrupted"
                    @a = super
                end    
            else
                Zlib::GzipWriter.open(a).close  
            end
        end    
    end
#This loads a key and value from another hashdb to the working hashdb
#  db  #=> {}
#  db.from("data","one")  #=> {"one"=>1}
#  db.from("letters","a") #=> {"one"=>1,"a"=>"A"}   
    def from(db,key)
        if File::exists? db
            begin
                Zlib::GzipReader.open(db) do |gz|
                    x = JSON.parse(gz.read)
                    val = x[key]
                    @a.store(key,val)
                end
            rescue JSON::ParserError,Zlib::Error
                puts "Error in reading #{key} from #{db}"
            end    
        else
            raise "#{db} does not exist"  
        end
    end
#This adds data to a hashdb apart from the current one
#  db  #=> {}
#  db.send("data","Ruby")  #=> this adds this key and it's value to data from your current hashdb
    def send(db,key)
        if File::exists? db
            x = {}
            begin
                Zlib::GzipReader.open(db) do |gz|
                    x = JSON.parse(gz.read)
                end
                val = @a[key]
                x.store(key,val)
                Zlib::GzipWriter.open(db) do |gz|
                    gz.write(JSON.generate(x))
                end
            rescue JSON::ParserError,Zlib::Error
                raise "An Error occured and we could not send your data to #{db}"
            end    
        else
            raise "Your database does not exist"  
        end
    end
#This adds data to another hashdb inform of a hash
#  db  #=> {}
#  db.send("data",{"name"=>"Ruby"})  #=> this adds this hash to data hashdb
    def send_hash(db,key)
        if File::exists? db
            x = {}
            begin
                Zlib::GzipReader.open(db) do |gz|
                    x = JSON.parse(gz.read)
                end
                x = {}   
                key.each{|k,v| x.store(k,v)}
                Zlib::GzipWriter.open(db) do |gz|
                    gz.write(JSON.generate(x))
                end
            rescue JSON::ParserError,Zlib::Error
                raise "An error occured an we could not send your hash to #{db}"
            end    
        else
            raise "Your database does not exist"  
        end
    end
#This adds a hash to the Hashdb
#  db.feed({"name"=>"Ruby"}) #This can be aliased as db.store("name","Ruby") or db["name"] = "Ruby"
#  db  #=> {}
#  db.feed({"name"=>"Ruby","age"=>23})  #=> {"name"=>"Ruby","age"=>23}  
    def feed(a)
        a.each_key do |e|
            @a.store(e,a[e])
        end
    end
#The hashdb runs as a hash at runtime until it is commited where the changed hash is saved
#  db.commit #saves the database  
    def commit
        Zlib::GzipWriter.open(@file) do |gz|
            gz.write(JSON.generate(@a))
        end
    end
#This automatically adds and commits the hashdb:
#  db.save({"age"=>23}) #this feeds and commits 
    def save(a)
        self.feed(a)
        self.commit
    end
#This is the same as feed eg: 
#  db = {"age" => 18}
#  db + {"name"=>"Ruby"}  #=> {"age" => 18,"name"=>"Ruby"}
    def +(a)
        self.feed(a)
    end
#This loads and parses a file in json adding the keys and values to the hash
#  db << "data.json"  
    def <<(a)
        self.read_json(a)
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
#This returns a hash from selected key
#  db.get_hash("name") #=> {"name"=>"Ruby"}  
    def get_hash(a)
        JSON.parse(self.get_json(a))
    end
#This returns xml from a selected key
#   db.get_xml("name") #=> <name>Ruby</name>     
    def get_xml(a)
        r = ""
        if ishash(@a[a])
            r = self.xmlhash(a,@a[a])
        elsif isarray(@a[a])
            r = self.xmlarray(a,@a[a])
        else
           r = "<#{a}>#{@a[a]}</#{a}>"
        end    
    end    
#This writes the hashdb to a file in json format
#  db.writejson("data.json")  #=> it is equal to db >> "data.json" 
    def write_json(a)
        s = File.open(a,'w')
        s << self.json
        s.close
    end
#This swaps values in the database
#  db  #=> {"name"=>"Ruby","Age"=>23}
#  db.swap("name","age")  #=> {"name"=>23,"Age"=>"Ruby"}
    def swap(a,b)
        x = @a[a]
        @a[a] = @a[b]
        @a[b] = x
    end
#This joins two keys <b>CAUTION</b> the data must be of the same class
#  db #=> {"val" => [1,2,3],"vals" => [4,5,6]}
#  db.join("vals","val")  #=> {"vals" => [4,5,6,1,2,3]}
    def join(a,b)
        result = @a[a].class
        if result.eql? Hash
            @a[a] = @a[a].merge(@a[b])
        else
            @a[a] = @a[a]+@a[b]
        end
        @a.delete(b)
    end
#This adds data to a value at the end <b>CAUTION</b> the data must be of the same class
#  db #=> {"vals" => [1,2,3]}
#  db.append("vals",[4,5,6])  #=> {"vals" => [1,2,3,4,5,6]}  
    def append(a,data)
        result = @a[a].class
        if result.eql? Hash
            @a[a] = @a[a].merge(data)
        else
            @a[a] = @a[a]+data
        end
    end
#This adds data to a value at the start <b>CAUTION</b> the data must be of the same class
#  db #=> {"vals" => [1,2,3]}
#  db.prepend("vals",[4,5,6])  #=> {"vals" => [4,5,6,1,2,3]}   
    def prepend(a,data)
        result = @a[a].class
        if result.eql? Hash
            @a[a] = data.merge(@a[a])
        else
            @a[a] = data+@a[a]
        end
    end
#This joins several keys to a certain key <b>CAUTION</b> the key values must be of the same class
#  db  #=> {"a"=>"A","b"=>"B","c"=>"C","d"=>"D","e"=>"E"}
#  db.concat("b","e","d","c")  #=> {"a"=>"A","b"=>"BEDC"}
    def concat(a,*args)
        result = @a[a].class
        args.each{|e|
            if result.eql? Hash
                @a[a] = @a[a].merge(@a[e])
            else
                @a[a] = @a[a]+@a[e]
            end
            @a.delete(e)
        }
    end
#This changes the key of a hash and the new key is moved to the end of the hash
#  db  #=> {"a"=>"A","b"=>"Z","c"=>"C"}
#  db.move("b","z")  #=>  {"a"=>"A","c"=>"C","z"=>"Z"}
    def move(a,b)
        @a[b] = @a[a]
        @a.delete(a)
    end
#This copies the value of a key to another key
#  db  #=> {"a"="A","b"=>"B"}
#  db.copy("a","b")  #=>  {"a"="A","b"=>"A"}
    def copy(a,b)
        @a[b] = @a[a]
    end
#This prints json from the hashdb same as to_json:
#  db  #=> {"a"="A","b"=>"B"} 
#  db.json  #=> {"a":"A","b":"B"} 
    def json
        JSON.generate(@a)
    end
#This allows you to manually add json data into the hashdb
#  db = {}
#  db.feed_json({"a":"A","b":"B"})  #=> {"a"=>"A","b"=>"B"}
    def feed_json(a)
        begin
            x = JSON.generate(a)
            self.feed(JSON.parse(x))
        rescue JSON::ParserError
            raise "We could not add your json data to the database"
        end    
    end
#This reads keys and values into the hashdb from a file in json format    
#  db.read_json("data.json")  #=> it is equal to db << "data.json" 
    def read_json(e)
        begin
            File.open(e) do |d|
                self.feed(JSON.parse(d.read))
            end
        rescue
            raise "We could not complete #{e} transaction"
        end    
    end
#This removes data from the hashdb if the key is found and the value also matches
#  db  #=> {"a"="A","b"=>"B"}
#  db - {"a"=>"X","b"=>"B"}  #=> {"a"="A"}  
    def -(a)
        a.each{|e,v|
            if @a[e] == v
                @a.delete(e)
            end     
        }
    end
#This function is supposed to load another hashdb from a file and merge it to the current can also be used for restore
# db #=> {}
# db.load("data")  #=> {"a"=>"A"}
    def load(a)
        if File::exists? a
            begin
                Zlib::GzipReader.open(a) do |gz|
                    x = JSON.parse(gz.read)
                    x.each{|k,v| @a.store(k,v)}
                end
            rescue JSON::ParserError,Zlib::Error
                raise "An error occured we could not load #{a}"
            end    
        else
            raise "Your database does not exist"  
        end
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
            rescue JSON::ParserError,Zlib::Error
                raise "We could not reload #{@file} it may be corrupted"
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
# db.xmlarray("array",[2,5])  #=> <array><sarray>2</sarray><sarray>5</sarray></array>
    def xmlarray(k,a)
        sub = "<#{k}>"
        a.each{|o|
            if isarray(o)
                sub << xmlarray("array",o);
            elsif ishash(o)
                sub << xmlhash("hash",o)
            else
                sub << "<s#{k}>#{o}</s#{k}>"
            end    
        }
        sub << "</#{k}>"
        sub    
    end
#This is the method generates xml from a hash not just from the hashdb but from anywhere
# ex  #=> {"name"=>"Ruby","since"=>1993}
# db.xmlhash("data",ex)  #=> <data><name>Ruby</name><since>1993</since></data>   
    def xmlhash(x,k)
        sub = "<#{x}>"
        k.each do |q,v|
            if isarray(v)
                sub << xmlarray(q,v);
            elsif ishash(v)
                sub << "<#{q}>"
                v.each{|t,b|
                    if isarray(b)
                        sub << xmlarray(t,b)
                    elsif ishash(b)
                        sub << xmlhash(t,b);
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
#This function tries to generate xml data from the hashdb <b>!CAUTION! Avoid very complex structures</b>
#  db   #=> {"name"=>"Myself"}
#  db.xml("here")  #=> <here><name>Myself</name></here>
#<b>Below notice the prefixed 's' eg 'snames' for an array</b>
#  db.xml("here")  #=> {"names"=>[1,3],"Me"=>"Myself"}  #=> <here><names><snames>1</snames><snames>2</snames></names><Me>Myself</Me></here>
#  db.xml("here") #=>  {"name"=>{"1"=>"Ruby",2="JRuby"}} #=> <here><name><1>Ruby</1><2>JRuby</2></name></here> 
    def xml(a)
        main = xmlhash(a,@a)
        main
    end
#This helps you traverse through a tree of hashes
#  db #=> {"1"=>{"name"=>"Ruby","langs"=>"{"1"=>"JRuby",2=>"CRuby"}}}
#  #You can get CRuby by two methods as below:
#  db["1"]["langs"]["2"]  #=> opt1
#  db.hpath_get("1/langs/2")  #=> hpath option     
    def hpath_get(a)
        e = a.split("/")
        x = @a[e[0]]
        for u in 1...e.length
            x = x[e[u]]
        end
        return x
    end
#This helps you edit values to your hashdb
#  db #=> {"1"=>{"name"=>"Ruby","langs"=>"{"1"=>"JRuby",2=>"CRuby"}}}
#  #You can edit CRuby by two methods as below:
#  db["1"]["langs"]["2"] = "DRuby"  #=> opt1
#  db.hpath_set("1/langs/2","DRuby")  #=> hpath option    
    def hpath_set(a,b)
        e = a.split("/")
        x = e.length
        if x == 1 then @a[e[0]] = b
        elsif x == 2 then @a[e[0]][e[1]] = b
        elsif x == 3 then @a[e[0]][e[1]][e[2]] = b
        elsif x == 4 then @a[e[0]][e[1]][e[2]][e[3]] = b
        else
            raise "Maximum nesting exceeded"
        end
    end
    end
end