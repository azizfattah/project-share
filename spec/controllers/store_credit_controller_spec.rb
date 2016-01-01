require 'spec_helper'

describe StoreCreditController do

  describe "GET 'wallet'" do
    it "returns http success" do
      get 'wallet'
      response.should be_success
    end
  end

end
