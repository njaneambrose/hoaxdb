require "hashdb/version"
require "zlib"
require "json"

module Hashdb
#This is a simple database based on a hash that gives various data manipulating methods,
#It inherits a Hash hence all the methods of a hash are possible plus the methods below.
#
#For flexibility and convience of keys due to the json nature of storage use:
#  {"name"=>"Me"} not {:name =>"Me"} or {name:"Me"}
#When adding doing any operation on the hashdb
    class Db < Hash
#Initialize a Hashdb with:
#  require 'hashdb'
#  db = Hashdb.new("data") #This reads or create a database in the file
    def initialize(a)
        @file = a
        @a  = super
        if File::exists? a
            Zlib::GzipReader.open(@file) do |gz|
                x = JSON.parse(gz.read)
                x.each{|k,v| @a.store(k,v)}
            end
        else
            Zlib::GzipWriter.open(a).close  
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
#  db.save({"age"=>23}) #this feeds the commits 
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
        self.readjson(a)
    end
#This writes your hash to a file in json format
#  db >> "data.json"  
    def >>(a)
        self.writejson(a)
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
#  db.getjson("name") #=> {"name":"Ruby"} 
    def getjson(a)
        x = {}
        x.store(a,@a[a])
        JSON.generate(x)
    end
#This returns a hash from selected key
#  db.gethash("name") #=> {"name"=>"Ruby"}  
    def gethash(a)
        JSON.parse(self.getjson(a))
    end 
#This writes the hashdb to a file in json format
#  db.writejson("data.json")  #=> it is equal to db >> "data.json" 
    def writejson(a)
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
#  db #=> {"vals" = [1,2,3]}
#  db.append("vals",[4,5,6])  #=> {"vals" = [1,2,3,4,5,6]}  
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
#  db.feedjson({"a":"A","b":"B"})  #=> {"a"=>"A","b"=>"B"}
    def feedjson(a)
        x = JSON.generate(a)
        self.feed(JSON.parse(x))
    end
#This reads values into the hashdb from a file in json format    
#  db.readjson("data.json")  #=> it is equal to db << "data.json" 
    def readjson(e)
        File.open(e) do |d|
            self.feed(JSON.parse(d.read))
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
#This function is supposed to load another hashdb from a file and merge it to the current
# db #=> {}
# db.load("data")  #=> {"a"=>"A"}
    def load(a)
        if File::exists? a
            Zlib::GzipReader.open(a) do |gz|
                x = JSON.parse(gz.read)
                x.each{|k,v| @a.store(k,v)}
            end
        else
            raise "Your database does not exist"  
        end
    end
#This ofloads the hashdb to a file other than the current file   
    def offload(a)
        Zlib::GzipWriter.open(a) do |gz|
            gz.write(JSON.generate(@a))
        end
    end
#Tests an array    
    def isarray(e)
        if e.class == Array
            return true
        else
            return false
        end    
    end
#Tests a Hash     
    def ishash(e)
        if e.class == Hash
            return true
        else
            return false
        end    
    end
#generates xml from an array    
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
#This is the main xml generator method    
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
#This function tries to generate xml data from the hashdb <b>!CAUTION! Avoid complex structures</b>
#  db   #=> {"name"=>"Myself"}
#  db.xml("here")  #=> <here><name>Myself</name></here>
#<b>Below notice the prefixed 's' eg 'snames' for an array</b>
#  db.xml("here")  #=> {"names"=>[1,3],"Me"=>"Myself"}  #=> <here><names><snames>1</snames><snames>2</snames></names><Me>Myself</Me></here>
#  db.xml("here") #=>  {"name"=>{"1"=>"Ruby",2="JRuby"}} #=> <here><name><1>Ruby</1><2>JRuby</2></name> 
    def xml(a)
        main = xmlhash(a,@a)
        main
    end    
end
end

x = Hashdb::Db.new("data")
puts x
