require 'rails_helper'

RSpec.describe "Spotify Playlists", type: :feature do
  it "displays playlists" do
    VCR.use_cassette 'spotify_playlists' do
      visit '/spotify'
      expect(page).to have_content "Spotify Playlists"
    end
  end
end
