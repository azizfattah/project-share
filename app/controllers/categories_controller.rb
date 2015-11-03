class CategoriesController < ApplicationController

  def children
    category = @current_community.categories.find(params[:id])

    if request.format.json?
      results = []
      category.children.each do |child|
        json = child.as_json
        json[:display_name] = child.display_name(I18n.locale)

        results << json
      end

      render :json => {:results => results}
    end
  end

end
