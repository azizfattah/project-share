class PriceTagsController < ApplicationController

  def create
    @price_tag = PriceTag.new(params[:price_tag])
    if @price_tag.save
      render json: @price_tag.to_json, status: :created, location: listing_price_tags_url(@price_tag.listing_id)
    else
      render json: @price_tag.errors, status: :unprocessable_entity
    end
  end

  def update
    @price_tag = PriceTag.find_by_id(params[:id])
    if @price_tag.update_attributes(params[:price_tag])
      render json: @price_tag.to_json, status: :created, location: listing_price_tags_url(@price_tag.listing_id)
    else
      render json: @price_tag.errors, status: :unprocessable_entity
    end

  end
end
