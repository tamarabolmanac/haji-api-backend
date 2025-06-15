# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Sample Hike Routes in Balkans

# Croatia
HikeRoute.find_or_create_by!(
  title: "Velebit Mountain - Paklenica",
  description: "A challenging hike through Croatia's largest mountain range with stunning views of the Adriatic Sea",
  duration: 6,
  difficulty: "hard",
  distance: 15.5,
  location_latitude: 44.2561,
  location_longitude: 15.3238,
  best_time_to_visit: "May to September"
)

HikeRoute.find_or_create_by!(
  title: "Plitvice Lakes National Park - Veliki Buk",
  description: "A scenic hike through the famous lakes and waterfalls with wooden walkways",
  duration: 4,
  difficulty: "medium",
  distance: 8.2,
  location_latitude: 44.6425,
  location_longitude: 15.6133,
  best_time_to_visit: "April to October"
)

# Montenegro

# Serbia
HikeRoute.find_or_create_by!(
  title: "Djerdap National Park - Iron Gates",
  description: "A scenic hike through the Djerdap Gorge with stunning Danube river views and historical sites",
  duration: 5,
  difficulty: "medium",
  distance: "12.5",
  location_latitude: 44.7167,
  location_longitude: 21.7000,
  best_time_to_visit: "April to October"
)

HikeRoute.find_or_create_by!(
  title: "Tara National Park",
  description: "A beautiful hike through dense forests and mountain peaks with panoramic views",
  duration: 6,
  difficulty: "medium",
  distance: "14.0",
  location_latitude: 43.7833,
  location_longitude: 19.2500,
  best_time_to_visit: "May to September"
)

HikeRoute.find_or_create_by!(
  title: "Strazilovo Mountain",
  description: "A challenging hike with panoramic views of the surrounding mountains and valleys",
  duration: 4,
  difficulty: "hard",
  distance: "10.5",
  location_latitude: 44.4333,
  location_longitude: 21.3000,
  best_time_to_visit: "June to September"
)

HikeRoute.find_or_create_by!(
  title: "Begečka Jama",
  description: "An adventurous hike through one of Serbia's largest caves with unique geological formations",
  duration: 3,
  difficulty: "medium",
  distance: "5.0",
  location_latitude: 45.4833,
  location_longitude: 19.7167,
  best_time_to_visit: "March to October"
)

HikeRoute.find_or_create_by!(
  title: "Zasavica Biosphere Reserve",
  description: "A nature hike through wetlands and protected wildlife areas with rich biodiversity",
  duration: 3,
  difficulty: "easy",
  distance: "6.5",
  location_latitude: 44.9667,
  location_longitude: 20.1333,
  best_time_to_visit: "April to September"
)

HikeRoute.find_or_create_by!(
  title: "Koviljski Rit",
  description: "A scenic hike through the Danube river wetlands with bird watching opportunities",
  duration: 4,
  difficulty: "easy",
  distance: "7.5",
  location_latitude: 45.2500,
  location_longitude: 19.8333,
  best_time_to_visit: "March to October"
)

HikeRoute.find_or_create_by!(
  title: "Fruška Gora National Park",
  description: "A beautiful hike through Serbia's oldest national park with stunning views of the Danube and rich biodiversity",
  duration: 5,
  difficulty: "medium",
  distance: "12.0",
  location_latitude: 45.1667,
  location_longitude: 19.7500,
  best_time_to_visit: "April to October"
)

# Montenegro
HikeRoute.find_or_create_by!(
  title: "Durmitor National Park - Škrčka Lakes",
  description: "A beautiful hike through the Durmitor mountain range with stunning alpine lakes",
  duration: 5,
  difficulty: "medium",
  distance: 10.5,
  location_latitude: 43.3333,
  location_longitude: 18.8333,
  best_time_to_visit: "May to September"
)

HikeRoute.find_or_create_by!(
  title: "Biogradska Gora - Biograd Lake",
  description: "A hike through one of Europe's last primeval forests with a beautiful alpine lake",
  duration: 3,
  difficulty: "easy",
  distance: 6.5,
  location_latitude: 43.2333,
  location_longitude: 19.0833,
  best_time_to_visit: "April to October"
)

# Serbia
HikeRoute.find_or_create_by!(
  title: "Kopaonik - Pančićev Kamen",
  description: "A challenging hike to Serbia's highest peak with panoramic views",
  duration: 7,
  difficulty: "hard",
  distance: 18.5,
  location_latitude: 43.4500,
  location_longitude: 20.8500,
  best_time_to_visit: "June to September"
)

HikeRoute.find_or_create_by!(
  title: "Fruska Gora - Iriški Venac",
  description: "A scenic hike through the historic Fruska Gora mountain with panoramic views",
  duration: 4,
  difficulty: "medium",
  distance: 9.5,
  location_latitude: 45.0833,
  location_longitude: 19.6667,
  best_time_to_visit: "March to November"
)

# Bosnia and Herzegovina
HikeRoute.find_or_create_by!(
  title: "Sutjeska National Park - Maglić",
  description: "A challenging hike to Bosnia's highest peak in the Dinaric Alps",
  duration: 8,
  difficulty: "hard",
  distance: 20.5,
  location_latitude: 43.5833,
  location_longitude: 18.7500,
  best_time_to_visit: "June to September"
)

HikeRoute.find_or_create_by!(
  title: "Blidinje Nature Park - Čvrsnica",
  description: "A beautiful hike through Bosnia's karst landscape with numerous springs",
  duration: 5,
  difficulty: "medium",
  distance: 12.5,
  location_latitude: 43.6667,
  location_longitude: 17.8333,
  best_time_to_visit: "April to October"
)

# Albania
HikeRoute.find_or_create_by!(
  title: "Valbona Pass",
  description: "A scenic hike through Albania's Albanian Alps with stunning views and traditional villages",
  duration: 3,
  difficulty: "medium",
  distance: 10.0,
  location_latitude: 42.3667,
  location_longitude: 20.1667,
  best_time_to_visit: "May to September"
)

HikeRoute.find_or_create_by!(
  title: "Theth Valley",
  description: "A beautiful hike through the remote Albanian Alps with traditional villages",
  duration: 4,
  difficulty: "medium",
  distance: 11.5,
  location_latitude: 42.4167,
  location_longitude: 19.9167,
  best_time_to_visit: "April to October"
)

# Macedonia
HikeRoute.find_or_create_by!(
  title: "Mavrovo National Park - Popova Šapka",
  description: "A hike through Macedonia's largest national park with beautiful lakes and mountains",
  duration: 5,
  difficulty: "medium",
  distance: 13.5,
  location_latitude: 41.8333,
  location_longitude: 21.3333,
  best_time_to_visit: "May to September"
)

HikeRoute.find_or_create_by!(
  title: "Pelister - Baba Mountain",
  description: "A challenging hike to Macedonia's highest peak with beautiful views",
  duration: 6,
  difficulty: "hard",
  distance: 16.5,
  location_latitude: 41.0833,
  location_longitude: 21.3333,
  best_time_to_visit: "June to September"
)
