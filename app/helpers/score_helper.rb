module ScoreHelper
  def format_score_to_par(value)
    return "Even" if value.zero?

    value.positive? ? "+#{value}" : value.to_s
  end

  def format_inside_pw_9i(value)
    return "E" if value.zero?

    value.positive? ? "+#{value}" : value.to_s
  end
end
