require 'rails_helper'

RSpec.describe "Queues", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/queue/index"
      expect(response).to have_http_status(:success)
    end
  end

end
