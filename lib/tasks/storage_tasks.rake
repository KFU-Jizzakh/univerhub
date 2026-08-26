# frozen_string_literal: true

# PURPOSE: Ops tasks for local disk storage integrity: verifies which Active Storage blobs have no file on disk
#   and restores missing files from a source directory matched by MD5 checksum
namespace :storage do
  # PURPOSE: Lists Active Storage blobs whose files are missing from the disk service; exits 1 when missing files are found
  desc "List Active Storage blobs whose files are missing from the disk service. Usage: bin/rails storage:verify"
  task verify: :environment do
    missing = ActiveStorage::Blob.order(:id).select { |blob| !File.exist?(blob_disk_path(blob)) }

    if missing.empty?
      puts "All #{ActiveStorage::Blob.count} blobs have files on disk."
    else
      puts "Missing files for #{missing.size} of #{ActiveStorage::Blob.count} blobs:"
      missing.each do |blob|
        attachments = blob.attachments.map { |a| "#{a.record_type}##{a.record_id}:#{a.name}" }.join(", ")
        puts format("%-6s | %-40s | %-24s | %s", blob.id, blob.filename.to_s.truncate(40), blob.checksum, attachments)
        puts format("%9s%s (size: %s)", "", blob.key, blob.byte_size)
      end
      abort "Missing files: #{missing.size}"
    end
  end

  # PURPOSE: Restores missing blob files by copying source files from DIR that match the blob MD5 checksum and byte size
  desc "Restore missing blob files from a directory of source files matched by MD5 checksum. " \
       "Usage: bin/rails \"storage:restore[/path/to/files]\" or SRC_DIR=/path/to/files bin/rails storage:restore"
  task :restore, [ :dir ] => :environment do |_t, args|
    dir = args[:dir].presence || ENV["SRC_DIR"].to_s
    if dir.blank?
      abort "No source directory given. Usage: bin/rails \"storage:restore[/path/to/files]\" " \
            "or SRC_DIR=/path/to/files bin/rails storage:restore"
    end
    abort "Source directory not found: #{dir}" unless File.directory?(dir)

    source_index = Hash.new { |hash, key| hash[key] = [] }
    Dir.glob(File.join(dir, "**", "*")).each do |path|
      source_index[File.size(path)] << path if File.file?(path)
    end

    missing = ActiveStorage::Blob.order(:id).select { |blob| !File.exist?(blob_disk_path(blob)) }
    restored = []
    not_found = []

    missing.each do |blob|
      source = source_index[blob.byte_size].find { |path| Digest::MD5.file(path).base64digest == blob.checksum }
      if source
        FileUtils.mkdir_p(File.dirname(blob_disk_path(blob)))
        FileUtils.cp(source, blob_disk_path(blob))
        restored << [ blob, source ]
      else
        not_found << blob
      end
    end

    restored.each do |blob, source|
      puts format("restored  blob %-6s %-40s <- %s", blob.id, blob.filename.to_s.truncate(40), source)
    end
    not_found.each do |blob|
      puts format("no source blob %-6s %-40s (%s, %s bytes)", blob.id, blob.filename.to_s.truncate(40), blob.checksum, blob.byte_size)
    end

    puts "Restored: #{restored.size}, no source found: #{not_found.size}"
  end

  def blob_disk_path(blob)
    File.join(Rails.root, "storage", blob.key[0..1], blob.key[2..3], blob.key)
  end
end
