#!/usr/bin/env ruby
# Quick cache test

k = "test_#{Time.now.to_i}"
v = "value_#{rand(1000)}"

puts "Writing: #{k} = #{v}"
Rails.cache.write(k, v)

r = Rails.cache.read(k)
puts "Read: #{r}"
puts "Match: #{r == v}"
puts "Cache store: #{Rails.cache.class.name}"
