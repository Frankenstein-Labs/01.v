# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceAccessTokenExpirationHelper, feature_category: :user_management do
  let(:group) { build_stubbed :group }
  let(:owner) { group.owner }

  it 'calls proper ability method' do
    expect(helper).to receive(:can?).with(owner, :admin_service_accounts, group)

    helper.can_change_service_access_tokens_expiration?(owner, group)
  end
end
