# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

HikeRoute.create!(title: "Ledinacko jezero", description: "Ovo je jedno od najlepsih fruskogorskih jezera. Iskopano na 340mnv.")

HikeRoute.create!(title: "Popovica", description: "Popovica je jedno od najpoznatijih polaznih tacaka na fruskoj gori. Iz popovice se racva vise od 20 planinskih staza za izvanredne izlete u prirodi razlicite tezine.")

HikeRoute.create!(title: "Strazilovo", description: "Brankov grob i planinarski dom Strazilovo samo su neki od check-pointa koje morate da obidjete kad svracate na Strazilovo. Ovo divno izletiste pruza avanturu kako za ljude zeljne opustanja tako i za iskusne planinare.")