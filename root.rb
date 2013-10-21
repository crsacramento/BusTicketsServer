require 'rubygems'
require 'sinatra'
require 'data_mapper'
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
    key: true,
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
    required: true,
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
# :_login/:_password/:_name/:_num/:_type/:_val
post '/register' do
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
        {"error" => true}.to_json
    end
end

get '/user/:login' do |login|
# test method, displays user info
    user = User.first(:login => login)
{user:
        {
        name: user.name,
        password: user.password,
        login: user.login,
        num: user.credit_card_num,
        type: user.credit_card_type,
        val: user.credit_card_val
         }
    }.to_json
end

post '/buy' do
    # params = login, num_tickets15m, num_tickets30m, num_tickets60m
    
    # find client
    

    $i = 0
    while $i < params[:num_tickets15m] do
        # new ticket of type 15 mins
    end
    $i = 0
    while $i < params[:num_tickets30m] do
        # new ticket of type 30 mins
    end
   $i = 0
    while $i < params[:num_tickets60m] do
        # new ticket of type 60 mins
    end

end

post '/validate' do
    # params = mac_address, ticket_id

end

post '/buslist' do
    # params = mac_address
end

# methods END
