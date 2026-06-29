# frozen_string_literal: true

module Grind
  module ContributionImage
    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg
      image/png
      image/webp
      image/heic
      image/heif
      image/gif
    ].freeze

    BROWSER_DISPLAYABLE_TYPES = %w[
      image/jpeg
      image/png
      image/webp
      image/gif
    ].freeze

    ALLOWED_EXTENSIONS = %w[.jpg .jpeg .png .webp .heic .heif .gif].freeze

    MAX_BYTES = 10.megabytes
    JPEG_QUALITY = 85
    MAX_DIMENSION = 4096

    module_function

    def allowed?(attachment)
      blob = attachment.blob
      extension_allowed?(blob.filename.to_s) && allowed_content_type?(blob)
    end

    def allowed_content_type?(blob)
      ALLOWED_CONTENT_TYPES.include?(detect_content_type(blob))
    end

    def extension_allowed?(filename)
      ext = File.extname(filename.to_s).downcase
      ALLOWED_EXTENSIONS.include?(ext)
    end

    def needs_normalization?(attachment)
      blob = attachment.blob
      extension = File.extname(blob.filename.to_s).downcase
      return true if %w[.heic .heif].include?(extension)

      !BROWSER_DISPLAYABLE_TYPES.include?(detect_content_type(blob))
    end

    def detect_content_type(blob)
      sample = blob.download
      Marcel::MimeType.for(
        sample,
        name: blob.filename.to_s,
        declared_type: blob.content_type
      )
    rescue StandardError
      blob.content_type.to_s
    end

    def ensure_displayable!(attachment)
      normalize!(attachment) if attachment.attached? && needs_normalization?(attachment)
      attachment
    end

    def normalize!(attachment)
      return attachment unless attachment.attached?
      return attachment unless needs_normalization?(attachment)

      blob = attachment.blob
      old_blob = blob

      blob.open do |file|
        processed = convert_to_jpeg(file.path)
        attachment.attach(
          io: File.open(processed.path),
          filename: jpeg_filename(blob.filename.to_s),
          content_type: "image/jpeg"
        )
      end

      old_blob.purge_later
      attachment
    rescue Vips::Error, ImageProcessing::Error => error
      Rails.logger.error("ContributionImage normalize failed: #{error.message}")
      raise
    end

    def convert_to_jpeg(source_path)
      begin
        require "image_processing/vips"

        ImageProcessing::Vips
          .source(source_path)
          .resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
          .convert("jpg")
          .saver(Q: JPEG_QUALITY, strip: true)
          .call
      rescue LoadError, Vips::Error
        require "image_processing/mini_magick"

        ImageProcessing::MiniMagick
          .source(source_path)
          .resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
          .convert("jpg")
          .saver(quality: JPEG_QUALITY)
          .call
      end
    end

    def jpeg_filename(original)
      base = File.basename(original.to_s, ".*")
      base = "scorecard" if base.blank?
      "#{base}.jpg"
    end
  end
end
