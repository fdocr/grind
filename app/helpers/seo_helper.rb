# frozen_string_literal: true

module SeoHelper
  SITE_NAME = "Grind"
  GITHUB_URL = "https://github.com/fdocr/grind"
  DEFAULT_DESCRIPTION = "Amateurs don't get the same value from stats that the pros do. Grind keeps your score while tracking simple stats that show where you're dropping shots on the course."
  DEFAULT_IMAGE_PATH = "/og.png"

  def seo_page_title
    page_title = content_for(:seo_title).presence || content_for(:title).presence
    page_title.present? ? "#{page_title} · #{SITE_NAME}" : SITE_NAME
  end

  def seo_description
    content_for?(:seo_description) ? content_for(:seo_description) : DEFAULT_DESCRIPTION
  end

  def seo_image_url
    absolute_url(content_for(:seo_image).presence || DEFAULT_IMAGE_PATH)
  end

  def seo_canonical_url
    absolute_url(request.path)
  end

  def seo_robots
    @seo_robots.presence || content_for(:seo_robots).presence || "index, follow"
  end

  def seo_indexable?
    seo_robots.exclude?("noindex")
  end

  def seo_site_url
    root_url
  end

  def absolute_url(path)
    return path if path.start_with?("http")

    "#{request.base_url}#{path}"
  end
end
