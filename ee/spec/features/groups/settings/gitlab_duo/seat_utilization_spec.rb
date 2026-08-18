# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > GitLab Duo > Seat Utilization', :js, :saas, feature_category: :seat_cost_management do
  it_behaves_like 'GitLab Duo administration' do
    let(:duo_page) { group_settings_gitlab_duo_seat_utilization_index_path(group) }
  end
end
