# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
Script.create(:id => 1, :name => "Reruns", :description => "Default Script For Code Based Reruns", :language => "ruby", :status => "invalid", :latest_code_id => nil, :latest_metric_id => nil, :user_id => 3)
