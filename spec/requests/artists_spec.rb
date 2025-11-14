require 'rails_helper'

RSpec.describe "Artists", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/artists/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/artists/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/artists/destroy"
      expect(response).to have_http_status(:success)
    end
  end
end
