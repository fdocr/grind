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

    ALLOWED_EXTENSIONS = %w[.jpg .jpeg .png .webp .heic .heif .gif].freeze

    MAX_BYTES = 4.megabytes
    MAX_DIMENSION = 2048
    JPEG_QUALITY = 85
    MIN_JPEG_QUALITY = 60
    MIN_DIMENSION = 1024

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

    def needs_optimization?(attachment)
      attachment.attached? && !optimized?(attachment)
    end

    def optimized?(attachment)
      blob = attachment.blob
      blob.metadata["optimized"] == true &&
        blob.content_type == "image/jpeg" &&
        blob.byte_size <= MAX_BYTES
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
      optimize!(attachment) if needs_optimization?(attachment)
      attachment
    end

    def optimize!(attachment)
      return attachment unless attachment.attached?
      return attachment unless needs_optimization?(attachment)

      blob = attachment.blob
      old_blob = blob

      blob.open do |file|
        processed = encode_within_limits(file.path)
        attachment.attach(
          io: File.open(processed.path),
          filename: jpeg_filename(blob.filename.to_s),
          content_type: "image/jpeg",
          metadata: { optimized: true }
        )
      end

      old_blob.purge_later
      attachment
    rescue Vips::Error, ImageProcessing::Error => error
      Rails.logger.error("ContributionImage optimize failed: #{error.message}")
      raise
    end

    # Backwards-compatible aliases
    def needs_normalization?(attachment)
      needs_optimization?(attachment)
    end

    def normalize!(attachment)
      optimize!(attachment)
    end

    def encode_within_limits(source_path)
      quality = JPEG_QUALITY
      dimension = MAX_DIMENSION

      loop do
        processed = render_jpeg(source_path, quality: quality, dimension: dimension)
        return processed if File.size(processed.path) <= MAX_BYTES

        if quality > MIN_JPEG_QUALITY
          quality -= 10
        elsif dimension > MIN_DIMENSION
          dimension = (dimension * 0.75).to_i
          quality = JPEG_QUALITY
        else
          return processed
        end
      end
    end

    def render_jpeg(source_path, quality:, dimension:)
      begin
        require "image_processing/vips"

        ImageProcessing::Vips
          .source(source_path)
          .resize_to_limit(dimension, dimension)
          .convert("jpg")
          .saver(Q: quality, strip: true)
          .call
      rescue LoadError, Vips::Error
        require "image_processing/mini_magick"

        ImageProcessing::MiniMagick
          .source(source_path)
          .resize_to_limit(dimension, dimension)
          .convert("jpg")
          .saver(quality: quality, strip: true)
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
