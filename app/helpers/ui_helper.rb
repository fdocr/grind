module UiHelper
  def icon(name, **options)
    render partial: "shared/svg/#{name}", locals: { class: options[:class].to_s }
  end
end
