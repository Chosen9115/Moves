namespace :moves do
  namespace :token do
    desc "Mint a new API token: moves:token:mint[name,scopes]"
    task :mint, [ :name, :scopes ] => :environment do |_t, args|
      name   = args[:name]   || abort("Usage: moves:token:mint[name,scopes]")
      scopes = args[:scopes] || "moves:read"

      record, raw = ApiToken.generate!(name: name, scopes: scopes)

      puts ""
      puts "  API token created: #{record.name}"
      puts "  Scopes: #{record.scopes}"
      puts ""
      puts "  Token (shown once — store it now):"
      puts "  #{raw}"
      puts ""
      puts "  WARNING: This token will not be shown again."
      puts ""
    end

    desc "Revoke an API token by name: moves:token:revoke[name]"
    task :revoke, [ :name ] => :environment do |_t, args|
      name = args[:name] || abort("Usage: moves:token:revoke[name]")

      tokens = ApiToken.where(name: name, revoked_at: nil)
      if tokens.empty?
        puts "No active token found with name: #{name}"
      else
        tokens.each(&:revoke!)
        puts "Revoked #{tokens.count} token(s) named '#{name}'."
      end
    end

    desc "List all API tokens (never shows raw tokens)"
    task list: :environment do
      tokens = ApiToken.order(:name, :created_at)
      if tokens.empty?
        puts "No API tokens found."
      else
        fmt = "%-20s  %-30s  %-20s  %s"
        puts format(fmt, "NAME", "SCOPES", "LAST USED", "STATUS")
        puts "-" * 80
        tokens.each do |t|
          last_used = t.last_used_at ? t.last_used_at.strftime("%Y-%m-%d %H:%M UTC") : "never"
          status    = t.revoked? ? "REVOKED (#{t.revoked_at.strftime('%Y-%m-%d')})" : "active"
          puts format(fmt, t.name, t.scopes, last_used, status)
        end
      end
    end
  end
end
