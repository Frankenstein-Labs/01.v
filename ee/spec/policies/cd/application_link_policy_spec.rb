# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationLinkPolicy, feature_category: :continuous_delivery do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:application_link) { create(:cd_application_link, application: application) }

  let_it_be(:non_member) { create(:user) }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:admin) { create(:user, :admin) }

  subject(:policy) { described_class.new(current_user, application_link) }

  describe 'cd_application abilities' do
    where(:role, :admin_mode, :allowed) do
      :non_member          | false | false
      :organization_member | false | false
      :organization_owner  | false | true
      :admin               | false | false
      :admin               | true  | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(:read_cd_application) : be_disallowed(:read_cd_application)) }

      it 'delegates create_cd_application_link to the application' do
        ability = :create_cd_application_link

        is_expected.to(allowed ? be_allowed(ability) : be_disallowed(ability))
      end
    end
  end
end
