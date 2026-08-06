# Active Record Encryption keys.
#
# Real keys come from the environment on the server and are NEVER committed
# (this is a public repo). Generate a set with `bin/rails db:encryption:init`
# and export them on the devbox:
#
#   AR_ENCRYPTION_PRIMARY_KEY, AR_ENCRYPTION_DETERMINISTIC_KEY,
#   AR_ENCRYPTION_KEY_DERIVATION_SALT
#
# Development and test fall back to fixed, non-secret values so the encrypted
# column works locally — these protect only throwaway local data and are not
# secrets. Production reads exclusively from ENV; if the keys are absent, Active
# Record raises when it first tries to encrypt/decrypt (i.e. only if the AI key
# is actually used), rather than failing boot for setups that never enable AI.
Rails.application.configure do
  enc = config.active_record.encryption

  if Rails.env.production?
    enc.primary_key         = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
    enc.deterministic_key   = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
    enc.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
  else
    enc.primary_key         = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", "dev_only_primary_key_not_a_secret")
    enc.deterministic_key   = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", "dev_only_deterministic_not_secret")
    enc.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", "dev_only_salt_value_not_a_secret1")
  end

  # Allow reading any pre-existing plaintext values during rollout; new writes
  # are always encrypted. Can be set to false once all data is confirmed encrypted.
  enc.support_unencrypted_data = true
end
