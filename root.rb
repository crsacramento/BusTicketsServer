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
    format: /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/,
    length: 17
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

# {"ticket_15":0,"ticket_30":0,"ticket_60":0}
post '/tickets/:login/buy' do |login|
  # Parameter checks.
  user = User.first(:login => login)
  return { success: false, error: 'User nonexistent' }.to_json unless user
  @p = @p.select { |k, v| !([k] & [:ticket_15, :ticket_30, :ticket_60]).empty? }
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

# {"bus":"00:00:00:00:00:00"}
post '/tickets/:login/validate/:id' do |login, id|
  ticket = User.first(login: login).tickets.get(id) rescue nil
  if !ticket || ticket.validated_at || ticket.bus_mac_address || !((@p[:bus] || '').upcase =~ /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/)
     return { success: false, error: 'Failed to validate.' }.to_json
  end
  return { success: true, ticket: ticket }.to_json if ticket.update({ bus_mac_address: @p[:bus].upcase, validated_at: Time.now })
  return { success: false, error: 'Failed to validate.' }.to_json
end

get '/tickets/list/:bus' do |bus|
  tickets = Ticket.all(:bus_mac_address => bus, :validated_at.gte => Time.now - 90 * 60) rescue nil
  { success: true, tickets: tickets }.to_json
end
