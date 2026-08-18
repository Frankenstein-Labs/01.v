# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ServicePolicy, feature_category: :continuous_delivery do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }

  let_it_be(:non_member) { create(:user) }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:admin) { create(:user, :admin) }

  subject(:policy) { described_class.new(current_user, service) }

  describe 'cd_service abilities' do
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

      it { is_expected.to(allowed ? be_allowed(:read_cd_service) : be_disallowed(:read_cd_service)) }
    end
  end
end
