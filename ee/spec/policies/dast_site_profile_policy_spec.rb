# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DastSiteProfilePolicy, feature_category: :dynamic_application_security_testing do
  it_behaves_like 'a dast on-demand scan policy' do
    let_it_be(:record) { create(:dast_site_profile, project: project) }
  end

  describe 'secret variable protection' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }

    let(:policies) { [:create_on_demand_dast_scan] }

    subject { described_class.new(user, dast_site_profile) }

    before do
      stub_licensed_features(security_on_demand_scans: true)
    end

    context 'when the site profile has no secret variables' do
      context 'when the user is a developer' do
        before_all do
          project.add_developer(user)
        end

        it { expect_allowed(*policies) }
      end
    end

    context 'when the site profile has secret variables' do
      before_all do
        create(:dast_site_profile_secret_variable, :password, dast_site_profile: dast_site_profile)
      end

      context 'when the user is a developer' do
        before_all do
          project.add_developer(user)
        end

        it { expect_disallowed(*policies) }
      end

      context 'when the user is a maintainer' do
        before_all do
          project.add_maintainer(user)
        end

        it { expect_allowed(*policies) }
      end

      context 'when the user is an owner' do
        before_all do
          group.add_owner(user)
        end

        it { expect_allowed(*policies) }
      end
    end
  end
end
