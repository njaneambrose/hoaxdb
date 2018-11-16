require 'date'

module Hashdb

class Query
    def parse(query)
        query.strip!
        if query.match(/row\[|@data|@base|[^\>\<]=/)
            raise "This syntax is not allowed for querying" 
        else
            if query.match(/this\[/)
                query = query.gsub(/this\[/,"row[")
            elsif query.eql? "*"
                query = "true"
            else
                raise "Unfamiliar query used"
            end
        end
        query
    end
    def parse_complex(query)
        query.strip!
        if query.match(/@data|@base|;|row/)
            raise "This syntax is not allowed for querying" 
        else
            query = query.gsub(/this\[/,"row[")
        end
        query
    end
end

class Table
    def initialize(name,args)
        @name = name
        @base = {}
        if !args.class.eql? Hash
            raise "Incorrect base for your database"
        else
            args.each{|k,v|
                if self.valid_type(v["type"])
                    self.validate(v)
                    @base.store(k,v)
                else
                    raise "Invalid data type #{v}"
                end    
            }
        end
        @data = []
    end
    def validate(v)
        if v["type"].eql? 'Date' or v["type"].eql? 'DateTime' and v["default"]
            v["default"] = "#{v["default"]}"
        elsif v["type"].eql? 'Boolean' and !v["default"].nil?
            if v["default"].class.eql? TrueClass or v["default"].class.eql? FalseClass
            else
                raise "Invalid default #{v["default"]} to #{v["type"]}"
            end
        else
             if !v["default"].nil? and !v["default"].class.eql? eval(v["type"])
                raise "Invalid default #{v["default"]} to #{v["type"]}"
            end
        end
        if v["default"].nil? then v["default"] = nil end
    end
    def data
        @data.clone
    end
    def base
        @base.clone
    end
    def valid_type(type)
        types = ['String','Integer','Float','DateTime','Date','Boolean','Array','Hash']
        found = false
        types.each{|e| if e.eql? type then found = true;break end}
        found
    end
    def load(data)
        data.each do |row|
            row.each do |k,v|
                if !v.nil?
                    if @base[k]['type'].eql? 'Date'
                        row[k] = Date.parse(v)
                    elsif @base[k]['type'].eql? 'DateTime'
                        row[k] = DateTime.parse(v)
                    elsif !@base[k]['type'].eql? 'String' and v.class.eql? String
                        row[k] = eval(v)
                    end
                end  
            end
        end
        data
    end
    def load_hash(data)
         data.each do |k,v|
            if !v.nil?
                if @base[k]['type'].eql? 'Date'
                    data[k] = Date.parse(v)
                elsif @base[k]['type'].eql? 'DateTime'
                    data[k] = DateTime.parse(v)
                elsif !@base[k]['type'].eql? 'String' and v.class.eql? String
                    data[k] = eval(v)
                end
            end  
        end
    end
    def dump_array(data)
        data.each do |row|
            row.each do |k,v|
                if @base[k]['type'].eql? 'Date' or @base[k]['type'].eql? 'DateTime'
                    row[k] = "#{v}"
                end    
            end
        end
        data
    end
    def dump_hash(data)
        data.each do |k,v|
            if @base[k]['type'].eql? 'Date' or @base[k]['type'].eql? 'DateTime'
                data[k] = "#{v}"
            end    
        end
        data
    end
    def insert(data)
        data.each{|k,v|
            if @base[k]
                if @base[k]['type'].eql? 'Boolean'
                    if v.class.eql? FalseClass or v.class.eql? TrueClass
                        correct = true
                    else
                        raise "#{v} is not a Boolean value"
                    end
                elsif !v.class.eql? eval(@base[k]['type'])
                    raise "Incorrect data type for #{v} to #{@base[k]}"     
                end
            else
                raise "This field #{k} is not in #{@name} table"
            end    
        }
        data = self.dump_hash(data)
        dt = {}
        @base.each_key{|k|
            if !data[k] then dt.store(k,@base[k]['default'])
            else
                dt.store(k,data[k])
            end    
        }
        @data.push(dt)         
    end
    def add_column(col,type)
        if valid_type(type['type'])
            self.validate(type)
            @base.store(col,type)
            @data.each do |row|
                row.store(col,@base[col]['default'])
            end
        end    
    end
    def update(query,values)
        @data = self.load(@data)
        @data.each{|row|
            if eval(Query.new.parse(query))
                values.each{|k,v|
                    if v.class.eql? String and v[0].eql? "$"
                        f = Query.new.parse_complex(v.delete("$"))                       
                        temp = (row[k]).clone
                        eval("temp#{f}")
                        if temp.class.eql? eval(@base[k]['type'])
                            row[k] = temp
                        else
                            raise "Invalid data #{temp} to #{@base[k]['type']}"
                        end
                    else
                       if v.class.eql? eval(@base[k]['type'])
                            row[k] = v
                       else
                            raise "Invalid data #{v} to #{@base[k]['type']}"
                       end
                    end
                }
            end
        }
        @data = self.dump_array(@data)
    end
    def drop_column(col)
        @base.delete(col)
        @data.each do |row|
            row.delete(col)
        end
    end
    def rename_column(col,ncol)
        if @base.has_key? col
            val = @base[col]
            @base.delete(col)
            @base.store(ncol,val)
            @data.each do |row|
                val = row[col]
                row.delete(col)
                row.store(ncol,val)
            end
        end
    end
    def del_if(query)
        rm = []
        @data = self.load(@data)
        @data.each do |row|
            if eval(Query.new.parse(query))
                rm.push(row)
            end
        end
        rm.each{|o| @data.delete(o)}
        @data = self.dump_array(@data)
    end
    def sort(data,key,flag)
        for w in 0...data.size  
            for y in 0...data.size
                if data[w][key] < data[y][key]
                    temp = data[y]
                    data[y] = data[w]
                    data[w] = temp
                end
            end
        end    
        if flag then data.reverse! end
        data
    end
    def max(k)
        if @base[k]['type'].eql? 'Integer' or @base[k]['type'].eql? 'Float'
            max = @data[0][k] || 0
            @data.each{|row| if row[k] > max then max = row[k] end}
            return max
        end
    end
    def min(k)
        if @base[k]['type'].eql? 'Integer' or @base[k].eql? 'Float'
            min = @data[0][k] || 0
            @data.each{|row| if row[k] < min then min = row[k] end}
            return min
        end
    end
    def avg(k)
        if @base[k]['type'].eql? 'Integer' or @base[k]['type'].eql? 'Float'
            sum = 0
            @data.each{|row| sum += row[k]}
            return (sum.to_f/@data.size)
        end
    end
    def sum(k)
        if @base[k]['type'].eql? 'Integer' or @base[k]['type'].eql? 'Float'
            sum = 0
            @data.each{|row| sum += row[k]}
            return sum
        end
    end
    def select_if(query,cols,limit=-1,sort=false,desc=false)
        result = []
        @data = self.load(@data)
        rw = 1
        @data.each do |row|
            break if rw.eql? (limit+1)
            if eval(Query.new.parse(query))
                col = {}
                if !cols[0].strip.eql? "*"
                    cols.each do |e|
                        col.store(e,row[e])
                    end
                    result.push(col)
                else
                   result.push(row)
                end
                rw +=1     
            end   
        end   
        if sort
            result = self.sort(result,sort,desc)
        end
        @data = self.dump_array(@data)
        if cols[0].strip.eql? "*"
            return self.load(result)
        end   
        result    
    end
    def inject(base,data) #:nodoc:#
        @base = base
        @data = data
    end
end
end