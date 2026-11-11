require "pathname"

module DeliveryConfig
  ROOT = File.expand_path("..", __dir__)
  PROJECT = File.join(ROOT, "WeatherJournal.xcodeproj")
  SCHEME = "WeatherJournal"
  CONFIGURATION = "Release"
  OUTPUT = File.join(ROOT, "artifacts")
  EXPORT_METHOD = "ad-hoc"
  SIGNING_STYLE = "manual"
  OUTPUT_NAME = "WeatherJournal.ipa"

  def self.required(name)
    value = ENV[name]&.strip
    raise "Missing required environment variable: #{name}" if value.nil? || value.empty?
    value
  end

  def self.signing
    identifier = required("APP_IDENTIFIER")
    raise "Set the registered APP_IDENTIFIER before packaging" if identifier.start_with?("com.example.")
    raise "Invalid APP_IDENTIFIER" unless identifier.match?(/\A[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\z/)
    {
      identifier: identifier,
      team: required("APPLE_TEAM_ID"),
      profile: required("PROVISIONING_PROFILE_NAME"),
      identity: required("CODE_SIGN_IDENTITY")
    }
  end
end
