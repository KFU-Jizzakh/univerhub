namespace :users do
  desc "Reset passwords for seed users and output them. Usage: EMAILS=a@x.local,b@x.local bin/rails users:reset_seed_passwords or bin/rails 'users:reset_seed_passwords[a@x.local;b@x.local]'"
  task :reset_seed_passwords, [ :emails ] => :environment do |_t, args|
    default_emails = %w[
      admin@univerhub.local
      manager@univerhub.local
      ivanov@univerhub.local
      petrova@univerhub.local
      reviewer@univerhub.local
      supervisor@univerhub.local
      visitor@univerhub.local
    ]

    emails = if ENV["EMAILS"].present?
      ENV["EMAILS"].split(",").map(&:strip).reject(&:blank?)
    elsif args[:emails].present?
      args[:emails].split(";").map(&:strip).reject(&:blank?)
    else
      default_emails
    end

    results = []
    skipped = []

    emails.each do |email|
      user = User.find_by(email_address: email)
      if user.nil?
        skipped << email
        next
      end

      password = SecureRandom.alphanumeric(12)
      user.password = password
      user.save!
      results << { email: email, password: password }
    end

    puts "\n=== Seed users passwords reset ==="
    puts format("%-35s %s", "Email", "Password")
    puts "-" * 55
    results.each do |r|
      puts format("%-35s %s", r[:email], r[:password])
    end
    puts "-" * 55
    puts "Total: #{results.size} user(s) updated"

    if skipped.any?
      puts "\nSkipped (not found): #{skipped.join(', ')}"
    end

    if results.any?
      timestamp = Time.current.strftime("%Y-%m-%d_%H-%M-%S")
      filepath = Rails.root.join("log", "seed_passwords_#{timestamp}.txt")
      File.write(
        filepath,
        results.map { |r| "#{r[:email]}  #{r[:password]}" }.join("\n")
      )
      puts "Saved to: #{filepath}"
    end
  end
end
