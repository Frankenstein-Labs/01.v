# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::JobsHelper, feature_category: :continuous_integration do
  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#admin_jobs_app_data' do
    describe 'can_update_all_jobs', :enable_admin_mode do
      subject { helper.admin_jobs_app_data[:can_update_all_jobs] }

      context 'when current user is admin' do
        let_it_be(:user) { build_stubbed(:user, :admin) }

        it { is_expected.to be true.to_s }
      end

      # A non-admin user can have read_admin_cicd custom ability and gain access
      # to the admin jobs page
      context 'when current user is not an admin' do
        let_it_be(:user) { build_stubbed(:user) }

        it { is_expected.to be false.to_s }
      end
    end
  end
end
