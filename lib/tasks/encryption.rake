namespace :moves do
  desc "Re-encrypt any AppPreference.openai_api_key still stored as plaintext"
  task encrypt_openai_keys: :environment do
    count = AppPreference.encrypt_legacy_plaintext!
    puts "Re-encrypted #{count} plaintext openai_api_key value(s)."
  end
end
