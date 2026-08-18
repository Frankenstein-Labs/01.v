# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::CommandPolicy, feature_category: :continuous_integration do
  include PolicyHelpers

  let_it_be(:project) { create(:project) }

  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:security_manager) { create(:user, security_manager_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }

  let(:command_attrs) { { project: project } }
  let(:command) { Gitlab::Ci::Pipeline::Chain::Command.new(**command_attrs) }

  subject(:policy) { described_class.new(user, command) }

  before do
    stub_licensed_features(security_on_demand_scans: true)
  end

  describe ':create_on_demand_dast_scan' do
    using RSpec::Parameterized::TableSyntax

    let(:permission) { :create_on_demand_dast_scan }
    let(:command_attrs) { { project: project, source: :ondemand_dast_scan } }

    where(:role, :allowed) do
      :developer        | true
      :security_manager | true
      :reporter         | false
    end

    with_them do
      let(:user) { send(role) }

      it { allowed ? expect_allowed(permission) : expect_disallowed(permission) }

      context 'for non-DAST pipelines' do
        let(:command_attrs) { { project: project } }

        it { expect_disallowed(permission) }
      end

      context 'when on-demand scans are not licensed' do
        before do
          stub_licensed_features(security_on_demand_scans: false)
        end

        it { expect_disallowed(permission) }
      end
    end
  end
end
