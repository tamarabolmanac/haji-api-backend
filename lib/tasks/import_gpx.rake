require "rexml/document"

# Imports a GPX track as a finalized HikeRoute (with Points), then enqueues
# elevation backfill so the terrain profile is ready.
#
#   bundle exec rails "gpx:import[sample_routes/kopaonik.gpx]"
#   bundle exec rails "gpx:import[sample_routes/kopaonik.gpx,someone@example.com]"
#
# If no email is given it uses the first user. Elevation is left NULL on import
# so OpenTopoData (DEM) fills it — that's the whole point of the terrain feature.
namespace :gpx do
  desc "Import a GPX file as a finalized hike route"
  task :import, [:path, :email] => :environment do |_t, args|
    path = args[:path] or abort "Usage: rails 'gpx:import[path/to/file.gpx,email]'"
    abort "File not found: #{path}" unless File.exist?(path)

    user = args[:email] ? User.find_by(email: args[:email]) : User.first
    abort "No user found (give an email that exists)" unless user

    doc = REXML::Document.new(File.read(path))
    name = REXML::XPath.first(doc, "//*[local-name()='name']")&.text&.strip
    name = name.presence || File.basename(path, ".*")

    trkpts = REXML::XPath.match(doc, "//*[local-name()='trkpt']").map do |pt|
      time = REXML::XPath.first(pt, "*[local-name()='time']")&.text
      {
        lat: pt.attribute("lat").value.to_f,
        lng: pt.attribute("lon").value.to_f,
        timestamp: time ? Time.parse(time) : nil
      }
    end
    abort "No <trkpt> points in #{path}" if trkpts.empty?

    # Fill missing timestamps so ordering is stable.
    base = trkpts.first[:timestamp] || Time.current
    trkpts.each_with_index { |p, i| p[:timestamp] ||= base + (i * 30) }

    route = nil
    ActiveRecord::Base.transaction do
      route = user.hike_routes.create!(
        title: name,
        description: "Uvezeno iz GPX (#{File.basename(path)})",
        difficulty: "medium",
        status: "tracking",
        location_latitude: trkpts.first[:lat],
        location_longitude: trkpts.first[:lng],
        duration: 0,
        distance: 0
      )
      now = Time.current
      Point.insert_all!(trkpts.map { |p|
        p.merge(hike_route_id: route.id, user_id: user.id, created_at: now, updated_at: now)
      })
      route.finalize_route!
    end

    puts "✅ Imported route ##{route.id} \"#{route.title}\" for #{user.email}"
    puts "   #{trkpts.size} points · distance #{route.reload.distance} · status #{route.status}"

    print "   Fetching elevations from OpenTopoData... "
    profile = ElevationService.new(route).profile
    Rails.cache.delete("hike:#{route.id}:elevation")
    eles = profile.map { |p| p[:elevation] }.compact
    if eles.any?
      puts "done — #{eles.size}/#{profile.size} points, #{eles.min.to_i}–#{eles.max.to_i} m, ↑#{(eles.each_cons(2).sum { |a, b| [b - a, 0].max }).to_i} m gain"
    else
      puts "no elevation returned (check OpenTopoData / DEM tiles)"
    end
    puts "   → Open: /route/#{route.id}"
  end
end
