module CategoryHelper
  def category_options_html_for(category)
    html = ""
    selected_id = category.id
    categories = @current_community.top_level_categories

    categories.each do |c|
      html += option_tag_for_category(c, selected_id, category)
    end

    html
  end

  private

  def option_tag_for_category(c, selected_id, category)
    result = ""
    if c != category
      nested_level = c.descendant_level
      html_options = {:value => c.id}
      if c.id == selected_id
        html_options[:selected] = "selected"
      end

      result += content_tag(:option, "".rjust(nested_level*2).gsub(" ", "&nbsp;").html_safe + c.display_name(I18n.locale), html_options)

      c.children.each do |child|
        result += option_tag_for_category(child, selected_id, category)
      end
    end

    result
  end
end
