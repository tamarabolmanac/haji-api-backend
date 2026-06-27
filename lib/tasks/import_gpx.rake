require "rexml/document"

# GPX import for hike routes.
#
#   Single file:
#     bundle exec rails "gpx:import[sample_routes/kopaonik.gpx]"
#     bundle exec rails "gpx:import[sample_routes/kopaonik.gpx,someone@example.com]"
#
#   Whole folder (recognizes the location from the filename and fills the
#   curated title / difficulty / tags / Serbian description automatically):
#     bundle exec rails "gpx:import_all[sample_routes]"
#     bundle exec rails "gpx:import_all[sample_routes,someone@example.com]"
#
# If no email is given it uses the first user. Elevation is left NULL on import
# so OpenTopoData (DEM) fills it — that powers the terrain + profile feature.
module GpxImport
  # Curated metadata for well-known Serbian routes. `keys` are matched against
  # the (transliterated) filename. Difficulty strings align with the app's
  # diffKey classifier: contains "lak" → lako, "teš/tes" → teško, else srednje.
  CATALOG = [
    { keys: %w[avala], title: "Avala — vrh i Avalski toranj", difficulty: "Laka",
      tags: %w[vidikovac suma parking kafic],
      desc: "Lagana šetnja do vrha Avale (511 m) i Avalskog tornja, dvadesetak kilometara od Beograda. Šumske staze, vidikovac s pogledom na grad i Spomenik Neznanom junaku — idealno za početnike i porodice." },

    { keys: %w[fruska strazilovo letenka andrevlje], title: "Fruška gora — Stražilovo i Crveni čot", difficulty: "Laka",
      tags: %w[suma vidikovac odmor],
      desc: "Šumska tura preko Stražilova do Crvenog čota, najvišeg vrha Fruške gore (539 m). Blago uspinjanje kroz hladovinu, brojna mesta za odmor i vidici nad Vojvodinom." },

    { keys: %w[kopaonik pancicev pancic], title: "Kopaonik — Pančićev vrh", difficulty: "Srednja",
      tags: %w[vidikovac vetrovito],
      desc: "Uspon na Pančićev vrh (2017 m), najviši vrh Kopaonika, do mauzoleja Josifa Pančića. Prostrani vidici i otvoren, često vetrovit greben — nezaboravan panoramski vrh." },

    { keys: %w[banjska perucac], title: "Tara — Banjska stena", difficulty: "Laka",
      tags: %w[vidikovac parking suma],
      desc: "Kratka staza do Banjske stene, čuvenog vidikovca nad jezerom Perućac i kanjonom Drine na Tari. Lak prilaz i jedan od najlepših pogleda u Srbiji." },

    { keys: %w[crno], title: "Tara — Crno jezero", difficulty: "Laka",
      tags: %w[jezero suma komarci],
      desc: "Mirna šetnja kroz četinarsku šumu do Crnog jezera na Tari. Senovita staza pored vode — prijatan letnji predah uz moguće komarce." },

    { keys: %w[midzor babin], title: "Stara planina — Midžor", difficulty: "Teška",
      tags: %w[vidikovac vetrovito],
      desc: "Uspon od Babinog zuba ka Midžoru (2169 m), najvišem vrhu Srbije. Otvoreni, vetroviti pašnjaci i široki vidici prema Bugarskoj — zahtevnija celodnevna tura." },

    { keys: %w[suva trem], title: "Suva planina — Trem", difficulty: "Teška",
      tags: %w[vidikovac vetrovito],
      desc: "Uspon na Trem (1810 m), najviši vrh Suve planine. Strm, izložen greben i prostran vidikovac nad jugoistočnom Srbijom — za iskusnije planinare." },

    { keys: %w[rtanj siljak], title: "Rtanj — vrh Šiljak", difficulty: "Srednja",
      tags: %w[vidikovac vetrovito],
      desc: "Uspon na piramidalni vrh Šiljak (1565 m), zaštitni znak Rtnja. Strma staza bez senke, ali s nestvarnim kružnim pogledom — kultni cilj planinara." },

    { keys: %w[zlatibor tornik], title: "Zlatibor — Tornik", difficulty: "Srednja",
      tags: %w[vidikovac hrana parking],
      desc: "Tura do Tornika (1496 m), najvišeg vrha Zlatibora. Pristupačan uspon, vidikovci i bogata ugostiteljska ponuda u blizini." },

    { keys: %w[djerdap derdap strbac ploce], title: "Đerdap — Veliki Štrbac", difficulty: "Srednja",
      tags: %w[vidikovac suma],
      desc: "Staza do Velikog Štrpca (768 m) u Nacionalnom parku Đerdap, s vidikovcima nad Đerdapskom klisurom i Dunavom. Šumski put i veličanstven pogled na reku." },

    { keys: %w[ovcar kablar], title: "Ovčar-Kablar — vidikovci nad meandrima", difficulty: "Srednja",
      tags: %w[vidikovac reka],
      desc: "Tura preko vidikovaca Ovčarsko-kablarske klisure, nad spektakularnim meandrima Zapadne Morave i manastirima. Srednje zahtevno, izuzetni prizori." },

    { keys: %w[vlasina vlasinsko], title: "Vlasinsko jezero — obilaznica", difficulty: "Laka",
      tags: %w[jezero parking],
      desc: "Lagana obilaznica oko Vlasinskog jezera, najvišeg veštačkog jezera u Srbiji. Otvoren predeo, plutajuća ostrva i mir — prijatno za sve uzraste." },
  ].freeze

  module_function

  def transliterate(str)
    str.downcase.gsub("đ", "dj").tr("čćžš", "cczs")
  end

  # Best catalog match for a filename (most keyword hits), or nil.
  def match_meta(path)
    norm = transliterate(File.basename(path, ".*"))
    tokens = norm.split(/[^a-z0-9]+/).reject(&:empty?)
    scored = CATALOG.map { |e| [e, e[:keys].count { |k| tokens.include?(k) || norm.include?(k) }] }
    best = scored.select { |(_, n)| n.positive? }.max_by { |(_, n)| n }
    best&.first
  end

  def parse_trkpts(path)
    doc = REXML::Document.new(File.read(path))
    # The track's own <name> (not the first <name>, which may be a waypoint).
    gpx_name = REXML::XPath.first(doc, "//*[local-name()='trk']/*[local-name()='name']")&.text&.strip
    gpx_name = gpx_name&.sub(/\s*[-–]\s*Wikiloc\s*\z/i, "")&.sub(/\A\s*Wikiloc\s*[-–]\s*/i, "")&.strip
    pts = REXML::XPath.match(doc, "//*[local-name()='trkpt']").map do |pt|
      time = REXML::XPath.first(pt, "*[local-name()='time']")&.text
      { lat: pt.attribute("lat").value.to_f, lng: pt.attribute("lon").value.to_f, timestamp: time ? Time.parse(time) : nil }
    end
    [gpx_name, pts]
  end

  # Imports one GPX file → finalized route (+ elevation). Returns the route or nil.
  def import_file(path, user)
    gpx_name, trkpts = parse_trkpts(path)
    if trkpts.empty?
      puts "⚠️  #{File.basename(path)}: nema <trkpt> tačaka — preskačem"
      return nil
    end

    base = trkpts.first[:timestamp] || Time.current
    trkpts.each_with_index { |p, i| p[:timestamp] ||= base + (i * 30) }

    meta  = match_meta(path) || {}
    # Prefer the route's own GPX name (each imported file is a distinct route);
    # the catalog title is only a fallback. Use the curated description only when
    # there's no GPX name, to avoid title/desc mismatch on same-area routes.
    title = gpx_name.presence || meta[:title].presence || File.basename(path, ".*")
    # No "imported from GPX" filler — leave the description empty so the detail
    # page simply omits the "O ruti" section. (Use catalog desc only if there's
    # no GPX name at all.)
    desc  = gpx_name.blank? ? meta[:desc].to_s : ""

    attrs = {
      title: title,
      description: desc,
      difficulty: meta[:difficulty] || "Srednja",
      status: "tracking",
      location_latitude: trkpts.first[:lat],
      location_longitude: trkpts.first[:lng],
      duration: 0, distance: 0,
    }
    # Only set tags if the column is deployed (prod may not be migrated yet).
    if HikeRoute.column_names.include?("tags") && meta[:tags].present?
      attrs[:tags] = meta[:tags]
    end

    route = nil
    ActiveRecord::Base.transaction do
      route = user.hike_routes.create!(attrs)
      now = Time.current
      Point.insert_all!(trkpts.map { |p| p.merge(hike_route_id: route.id, user_id: user.id, created_at: now, updated_at: now) })
      route.finalize_route!
    end

    label = meta[:title] ? "✓ #{meta[:title]} [#{attrs[:difficulty]}]" : "○ bez kataloga (generički)"
    puts "✅ ##{route.id} \"#{route.title}\" — #{trkpts.size} tač. · #{route.reload.distance} km · #{label}"

    profile = ElevationService.new(route).profile
    Rails.cache.delete("hike:#{route.id}:elevation")
    eles = profile.map { |p| p[:elevation] }.compact
    if eles.any?
      gain = eles.each_cons(2).sum { |a, b| [b - a, 0].max }.to_i
      puts "   ⛰ visine: #{eles.size}/#{profile.size} tač., #{eles.min.to_i}–#{eles.max.to_i} m, ↑#{gain} m"
    else
      puts "   (bez visina — proveri OpenTopoData / DEM)"
    end
    puts "   → /route/#{route.id}"
    route
  rescue => e
    puts "❌ #{File.basename(path)}: #{e.class} — #{e.message}"
    nil
  end
end

namespace :gpx do
  desc "Import a single GPX file as a finalized hike route"
  task :import, [:path, :email] => :environment do |_t, args|
    path = args[:path] or abort "Usage: rails 'gpx:import[path/to/file.gpx,email]'"
    abort "File not found: #{path}" unless File.exist?(path)
    user = args[:email] ? User.find_by(email: args[:email]) : User.first
    abort "No user found (give an email that exists)" unless user
    GpxImport.import_file(path, user)
  end

  desc "Import every .gpx in a folder, deriving metadata from the filename"
  task :import_all, [:dir, :email] => :environment do |_t, args|
    dir = args[:dir] or abort "Usage: rails 'gpx:import_all[folder,email]'"
    abort "Folder not found: #{dir}" unless Dir.exist?(dir)
    files = Dir.glob(File.join(dir, "*.{gpx,GPX}")).sort
    abort "No .gpx files in #{dir}" if files.empty?
    user = args[:email] ? User.find_by(email: args[:email]) : User.first
    abort "No user found (give an email that exists)" unless user

    puts "Uvozim #{files.size} GPX fajl(ova) za #{user.email}…\n\n"
    ok = files.count { |f| GpxImport.import_file(f, user) }
    puts "\nGotovo: #{ok}/#{files.size} ruta uvezeno."
  end
end
