require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'dm-core'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-migrations'
require 'date'
require 'json'

# Setup database.
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/dev.db")

# Creates User class and database representation.
class User

  include DataMapper::Resource

  property :id,                     Serial

  property :name,                   String, {
    required: true,
    length: 5..50
  }

  property :password,               String, {
    required: true,
    length: 5..50
  }

  property :login,                  String, {
    unique: true,
    required: true,
    length: 5..50
  }

  property :credit_card_num,        String, {
    required: true,
    length: 8,
    unique: true
  }

  property :credit_card_type,       String, {
    required: true,
    format: /(^Visa$)|(^MasterCard$)/
  }

  property :credit_card_val,        Date, {
    required: true
  }

  has n, :tickets

end

# Creates Ticket class and database representation.
class Ticket

  include DataMapper::Resource

  property :id, Serial

  property :bus_mac_address,        String, {
    format: /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/
  }

  property :validated_at,           DateTime

  property :validity_time,          Integer, {
    :required => true
  }

  belongs_to :user

end

# Update database scheme if needed.
DataMapper.finalize.auto_upgrade!

# Disable access protection.
disable :protection

# methods START
post '/register' do
    # {"name":"Diogo Teixeira","password":"password","login":"diogo","num":"12345678","type":"Visa","val":"1382310000"}

    params = JSON.parse(request.body.read, {symbolize_names: true})
    puts params
    user = User.new
    user.attributes = {
        :name => params[:name],
        :password => params[:password],
        :login => params[:login],
        :credit_card_num => params[:num],
        :credit_card_type => params[:type],
        :credit_card_val => Time.at(params[:val]).utc.to_datetime
        # _val comes in EpochTime format
    }
    if user.save
        # answer success
        {"error" => false}.to_json
    else
        # answer error
        # {"error" => true}.to_json
        user.errors.each do |error|
            puts error
        end
        user.errors.to_json
    end
end

get '/tickets/:login' do |login|
# test method, lists non-validated tickets
    user = User.first(:login => login)
    user.tickets.all(:validated_at => nil).to_json
end

post '/buy' do
    # {login":"diogo","num_tickets15m":1,"num_tickets30m":1,"num_tickets60m":0}"
    params = JSON.parse(request.body.read, {symbolize_names: true})
   
    # find client
    user = User.first(:login => params[:login])

    if !user
        return {'error' => 'User nonexistent'}.to_json
    end
    
    if((params[:num_tickets15m].to_i + params[:num_tickets30m].to_i + params[:num_tickets60m].to_i) == 0)
        return {'error' => 'Bought 0 tickets.'}.to_json
    end

    $i = 0
    while $i < params[:num_tickets15m].to_i do
        # new ticket of type 15 mins
        ticket = user.tickets.new(:validity_time => 15)
        bool = ticket.save
        if !bool
            return ticket.errors.to_json
        end
        $i = $i + 1
    end

    $i = 0
    
    while $i < params[:num_tickets30m].to_i do
        # new ticket of type 30 mins
        ticket = user.tickets.new(:validity_time => 30)
        bool = ticket.save
        if !bool
           return ticket.errors.to_json
        end
        $i = $i + 1
    end
    
    $i = 0
    
    while $i < params[:num_tickets60m].to_i do
        # new ticket of type 60 mins
        ticket = user.tickets.new(:validity_time => 60)
        bool = ticket.save
        if !bool
            ticket.errors.to_json
        end
        $i = $i + 1
    end

    # check if user qualifies for extra ticket
    if((params[:num_tickets15m].to_i + params[:num_tickets30m].to_i + params[:num_tickets60m].to_i) >= 10)
        if params[:num_tickets15m].to_i > 0
            # free 15m ticket
            user.tickets.create(:validity_time => 15)
        elsif params[:num_tickets30m].to_i > 0
            # free 30m ticket
            user.tickets.create(:validity_time => 30)
        elsif params[:num_tickets60m].to_i > 0
            # free 60m ticket
            user.tickets.create(:validity_time => 60)
        end
    end

    user.tickets.all(:validated_at => nil).to_json
end

post '/validate' do
    # {"bus":"00:00:00:00:00:00","ticket":1}
    params = JSON.parse(request.body.read, {symbolize_names: true})

    ticket = Ticket.get(params[:ticket].to_i)
    if ticket.validated_at == nil and ticket.bus_mac_address == nil
        ticket.bus_mac_address = params[:bus_mac_address]
        ticket.validated_at = Time.now
        bool = ticket.save
        if !bool
            return ticket.errors.to_json
        end
    
        ticket = Ticket.get(params[:ticket].to_i)
        return ticket.to_json
    else
        return ticket.errors.to_json
    end
end

post '/buslist' do
    #{"bus":"00:00:00:00:00:00"}
    params = JSON.parse(request.body.read, {symbolize_names: true})
    tickets = Ticket.all(:bus_mac_address => params[:bus]) & Ticket.all(:validated_at.lte => (Time.now - 90*60).to_s)
    tickets.to_json
end

# methods END
