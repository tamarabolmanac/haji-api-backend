# Ponovna obrada postojećih slika ruta: resize (max 1600px) + konverzija u WebP.
# Pokretanje: bundle exec rake routes:reprocess_images
# Na produkciji: RAILS_ENV=production bundle exec rake routes:reprocess_images
namespace :routes do
  desc "Reprocess all route images to WebP (resize 1600px, quality 82)"
  task reprocess_images: :environment do
    require "image_processing/mini_magick"

    attachments = ActiveStorage::Attachment.where(record_type: "HikeRoute", name: "images")
    total = attachments.count
    puts "Pronađeno #{total} slika za obradu..."

    done = 0
    errors = 0

    attachments.find_each do |attachment|
      record = attachment.record
      blob = attachment.blob

      unless record && blob
        errors += 1
        next
      end

      blob.open do |source_file|
        processed = ImageProcessing::MiniMagick
          .source(source_file)
          .resize_to_limit(1600, 1600)
          .convert("webp")
          .saver(quality: 82)
          .call

        base_name = blob.filename.base.presence || "image"
        record.images.attach(
          io: File.open(processed.path),
          filename: "#{base_name}.webp",
          content_type: "image/webp"
        )
      end

      attachment.purge
      done += 1
      puts "  [#{done}/#{total}] Route #{record.id} – slika zamenjena WebP verzijom"
    rescue => e
      errors += 1
      puts "  ✗ Greška za attachment #{attachment.id}: #{e.message}"
    end

    puts "\nZavršeno. Uspešno: #{done}, greške: #{errors}"
  end
end
