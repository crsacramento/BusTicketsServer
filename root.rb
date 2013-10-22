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
    format: /^\d{8}$/
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

# Parse parameters list before every action.
before do
  request.body.rewind
  @p = JSON.parse(request.body.read, {symbolize_names: true}) rescue @p = {}
end

post '/register' do
  @p[:credit_card_val] = Time.at(@p[:credit_card_val]).utc.to_date rescue nil
  user = User.new @p rescue user = User.new
  return {success: true}.to_json if user.save
  return {success: false, errors: user.errors.to_h}.to_json
end

get '/tickets/:login' do |login|
  user = User.first(:login => login)
  return { success: true, tickets: user.tickets.all(:validated_at => nil) }.to_json if user
  return { success: false }.to_json
end

post '/tickets/:login/buy' do |login|
  # Parameter checks.
  user = User.first(:login => login)
  return { success: false, error: 'User nonexistent' }.to_json unless user
  @p = @p.select { |k, v| not ([k] & [:ticket_15, :ticket_30, :ticket_60]).empty? }
  unless
    @p.keys.count == 3 &&
    @p.values.all? { |x| x.class == Fixnum } &&
    @p.values.inject(:+) > 0
    return { success: false, error: 'Bought 0 tickets.' }.to_json
  end
  # Create tickets.
  tickets = []
  @p.keys.each do |t|
    @p[t].times { tickets << user.tickets.new(validity_time: t.to_s[/\d+$/].to_i) }
  end
  tickets << user.tickets.new({ validity_time: (tickets.map { |ts| ts.validity_time }).min }) if tickets.count >= 10
  return { success: false, error: 'Error buying tickets.' } unless tickets.all? { |ts| ts.valid? }
  tickets.each { |ts| ts.save }
  {success: true, tickets: user.tickets.all(:validated_at => nil), extra: @p.values.inject(:+) < tickets.count }.to_json
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
