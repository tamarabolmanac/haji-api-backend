class RecommendationsController < ApiController
  before_action :authenticate_user

  def create
    distance_min = params[:distance_min].to_i
    distance_max = params[:distance_max].to_i
    tags = Array(params[:tags])
    location = params[:location].to_s.strip

    prompt = build_prompt(distance_min, distance_max, tags, location)

    service = ClaudeService.new
    reply = service.chat(prompt)

    # Izvuci samo JSON niz iz odgovora (Claude ponekad doda tekst oko JSON-a)
    json_match = reply.match(/\[.*\]/m)
    clean_json = json_match ? json_match[0] : reply

    render json: { recommendation: clean_json }, status: :ok
  rescue => e
    Rails.logger.error("RecommendationsController error: #{e.message}")
    render json: { error: "Greška pri generisanju preporuke." }, status: :internal_server_error
  end

  private

  def build_prompt(distance_min, distance_max, tags, location)
    parts = []
    parts << "Ti si lokalni vodič za planinarenje i šetnju u Srbiji."
    parts << "Korisnik traži preporuku za šetnju ili planinarenje na teritoriji Republike Srbije."
    parts << ""
    parts << "Kriterijumi:"
    parts << "- Željena dužina staze: #{distance_min}–#{distance_max} km"
    parts << "- Tip terena / karakteristike: #{tags.join(', ')}" if tags.any?
    parts << "- Blizu lokacije: #{location}" if location.present?
    parts << ""
    parts << "Na osnovu ovih kriterijuma, predloži 3–5 konkretnih lokacija u Srbiji."
    parts << "Odgovori ISKLJUČIVO validnim JSON nizom, bez ikakvog dodatnog teksta pre ili posle JSON-a."
    parts << "Format:"
    parts << '[{"name":"Naziv destinacije","distance":"X–Y km","description":"Kratki opis lokacije.","why":"Zašto odgovara kriterijumima.","lat":44.8125,"lon":20.4612}]'
    parts << "lat i lon moraju biti tačne GPS koordinate te lokacije u Srbiji (decimalni broj)."
    parts << "Piši na srpskom jeziku, prijateljskim tonom."

    parts.join("\n")
  end
end
