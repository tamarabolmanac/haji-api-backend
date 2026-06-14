class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Helper: čita boolean flag sa default-om
  def self.flag(key, default: true)
    rec = find_by(key: key)
    return default if rec.nil? || rec.value.nil?
    rec.value == "true"
  end

  def self.set(key, value)
    rec = find_or_initialize_by(key: key)
    rec.value = value.to_s
    rec.save!
    rec
  end
end
