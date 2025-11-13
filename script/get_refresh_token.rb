#!/usr/bin/env ruby

require 'faraday'
require 'json'

puts "Enter your Spotify Client ID:"
client_id = gets.chomp

puts "Enter your Spotify Client Secret:"
client_secret = gets.chomp

puts "Enter the authorization code from the redirect URL:"
code = gets.chomp

redirect_uri = "http://localhost:3000/callback"

response = Faraday.post('https://accounts.spotify.com/api/token') do |req|
  req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
  req.headers['Authorization'] = "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"
  req.body = URI.encode_www_form(
    grant_type: 'authorization_code',
    code: code,
    redirect_uri: redirect_uri
  )
end

if response.success?
  data = JSON.parse(response.body)
  puts "Access Token: #{data['access_token']}"
  puts "Refresh Token: #{data['refresh_token']}"
  puts "Expires in: #{data['expires_in']} seconds"
else
  puts "Error: #{response.body}"
end
