# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupHookPolicy, feature_category: :webhooks do
  let_it_be(:user) { create(:user) }

  let(:hook) { create(:group_hook) }

  subject(:policy) { described_class.new(user, hook) }

  context 'when the user is not an owner' do
    before do
      hook.group.add_maintainer(user)
    end

    it "cannot read or admin web-hooks" do
      expect(policy).to be_disallowed(:read_web_hook)
      expect(policy).to be_disallowed(:admin_web_hook)
    end
  end

  context 'when the user is an owner' do
    before do
      hook.group.add_owner(user)
    end

    it "can admin web-hooks" do
      expect(policy).to be_allowed(:read_web_hook)
      expect(policy).to be_allowed(:admin_web_hook)
    end
  end
end
