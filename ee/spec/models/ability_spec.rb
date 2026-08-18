# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ability, feature_category: :system_access do
  describe '.issues_readable_by_user' do
    context 'with IP restrictions' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:user) { create(:user, developer_of: group) }

      let_it_be(:issues) { create_list(:issue, 2, project: project) }

      before_all do
        create(:ip_restriction, group: group, range: '192.168.0.0/24')
      end

      before do
        stub_licensed_features(group_ip_restriction: true)
      end

      it 'returns issues when IP is within the configured range' do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')

        expect(described_class.issues_readable_by_user(issues, user)).to match_array(issues)
      end

      it 'excludes issues when IP is outside the configured range' do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('10.0.1.1')

        expect(described_class.issues_readable_by_user(issues, user)).to be_empty
      end
    end
  end
end
