require 'rails_helper'

RSpec.describe TidalService do
  let(:service) do
    TidalService.new(
      client_id: ENV.fetch('TIDAL_CLIENT_ID', 'test_client_id'),
      client_secret: ENV.fetch('TIDAL_CLIENT_SECRET', 'test_client_secret')
    )
  end

  describe '#search_track' do
    it 'searches for a track on Tidal' do
      VCR.use_cassette('tidal/search_track') do
        result = service.search_track('Bohemian Rhapsody', 'Queen')

        expect(result).to be_present
        expect(result['title']).to be_present
      end
    end
  end

  describe '#fetch_access_token' do
    it 'fetches an access token' do
      VCR.use_cassette('tidal/fetch_access_token') do
        token = service.send(:fetch_access_token)

        expect(token).to be_present
        expect(token).to be_a(String)
      end
    end
  end
end
