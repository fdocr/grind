module ApplicationHelper
  include UiHelper
  include ScoreHelper

  # Homepage install prompt. Macintosh is included so iPadOS, which often sends a
  # desktop Safari user agent, still receives the markup. The banner script only
  # opens it on an iPhone or iPad.
  def ios_app_banner?
    return false if hotwire_native_app?
    return false unless request.path == root_path

    user_agent = request.user_agent.to_s
    return false if user_agent.match?(/Android/i)

    user_agent.match?(/iPhone|iPad|iPod|Macintosh/i)
  end
end
