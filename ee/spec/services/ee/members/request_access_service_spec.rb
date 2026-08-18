# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::RequestAccessService, feature_category: :groups_and_projects do
  let(:user) { create(:user) }

  shared_examples 'a service creating a guest access request' do
    it 'creates a request with guest access level' do
      member = described_class.new(user).execute(source)

      expect(member.access_level).to eq(::Gitlab::Access::GUEST)
    end
  end

  shared_examples 'a service creating a developer access request' do
    it 'creates a request with developer access level' do
      member = described_class.new(user).execute(source)

      expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
    end
  end

  context 'when member promotion management is enabled' do
    before do
      allow_next_instance_of(described_class) do |service|
        allow(service).to receive(:member_promotion_management_enabled?).and_return(true)
      end
    end

    context 'when user is non-billable' do
      before do
        allow(User).to receive(:non_billable_users_for_billable_management).and_return([user])
      end

      %i[project group].each do |source_type|
        it_behaves_like 'a service creating a guest access request' do
          let(:source) { create(source_type, :public) }
        end
      end
    end

    context 'when user is billable' do
      before do
        allow(User).to receive(:non_billable_users_for_billable_management).and_return([])
      end

      %i[project group].each do |source_type|
        it_behaves_like 'a service creating a developer access request' do
          let(:source) { create(source_type, :public) }
        end
      end
    end
  end

  context 'when member promotion management is disabled' do
    before do
      allow_next_instance_of(described_class) do |service|
        allow(service).to receive(:member_promotion_management_enabled?).and_return(false)
      end
    end

    %i[project group].each do |source_type|
      it_behaves_like 'a service creating a developer access request' do
        let(:source) { create(source_type, :public) }
      end
    end
  end

  context 'when membership is locked' do
    shared_examples 'a service denying access request' do
      it 'raises Gitlab::Access::AccessDeniedError' do
        expect { described_class.new(user).execute(source) }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'for a project with locked group membership' do
      it_behaves_like 'a service denying access request' do
        let_it_be(:locked_group) { create(:group, :public, membership_lock: true) }
        let_it_be(:source) { create(:project, :public, group: locked_group) }
      end
    end

    context 'for a group with locked membership' do
      it_behaves_like 'a service creating a developer access request' do
        let_it_be(:source) { create(:group, :public, membership_lock: true) }
      end
    end

    context 'for a project with unlocked group membership' do
      it_behaves_like 'a service creating a developer access request' do
        let_it_be(:unlocked_group) { create(:group, :public, membership_lock: false) }
        let_it_be(:source) { create(:project, :public, group: unlocked_group) }
      end
    end
  end
end
