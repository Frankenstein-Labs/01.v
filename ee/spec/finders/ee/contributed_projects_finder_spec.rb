# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContributedProjectsFinder, feature_category: :groups_and_projects do
  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }

    it_behaves_like 'projects finder with SAML session filtering' do
      let(:finder) { described_class.new(user: user, current_user: current_user, params: params) }

      before do
        travel_to(2.hours.from_now) { create(:push_event, project: project1, author: user) }
        travel_to(3.hours.from_now) { create(:push_event, project: project2, author: user) }
        travel_to(4.hours.from_now) { create(:push_event, project: private_project, author: user) }
      end
    end
  end
end
