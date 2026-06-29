# frozen_string_literal: true

module ContributionsHelper
  def contribution_status_tone(contribution)
    case contribution.status
    when "finalized" then :success
    when "pending" then :warning
    else :neutral
    end
  end

  def contribution_kind_label(contribution)
    contribution.correction? ? "Correction" : "New course"
  end

  def contribution_kind_tone(contribution)
    contribution.correction? ? :info : :primary
  end
end
