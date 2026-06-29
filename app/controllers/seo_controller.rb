# frozen_string_literal: true

class SeoController < ApplicationController
  def robots
    render plain: robots_txt, content_type: "text/plain"
  end

  def sitemap
    @entries = [
      { loc: root_url, changefreq: "weekly", priority: "1.0" },
      { loc: about_url, changefreq: "monthly", priority: "0.8" },
      { loc: contribute_url, changefreq: "monthly", priority: "0.7" }
    ]
  end

  private

  def robots_txt
    <<~TXT
      User-agent: *
      Allow: /

      Disallow: /jobs
      Disallow: /dev/
      Disallow: /rounds/
      Disallow: /courses/*/round

      Sitemap: #{sitemap_url}
    TXT
  end
end
