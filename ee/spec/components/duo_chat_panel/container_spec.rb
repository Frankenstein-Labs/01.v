# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DuoChatPanel::Container, :aggregate_failures, feature_category: :duo_chat do
  let(:user) { build_stubbed(:user) }
  let(:project) { nil }
  let(:group) { nil }
  let(:controller_name) { nil }

  subject(:container) do
    described_class.new(project: project, group: group, user: user, controller_name: controller_name)
  end

  before do
    allow(::Gitlab::Llm::DuoChat).to receive(:duo_scope_hash)
      .with(user, project, group, controller_name)
      .and_return(duo_scope)
  end

  context 'when duo_scope resolves to a project' do
    let(:project) { build_stubbed(:project) }
    let(:duo_scope) { { project: project, namespace: nil, default_namespace_applied: false } }

    it 'returns project type' do
      expect(container.type).to eq('project')
      expect(container.project?).to be(true)
    end

    describe '#record' do
      it { is_expected.to have_attributes(record: project) }
    end

    describe '#source' do
      it { is_expected.to have_attributes(source: project) }
    end

    it 'delegates to the record' do
      expect(container.to_global_id).to eq(project.to_global_id)
      expect(container.root_ancestor).to eq(project.root_ancestor)
      expect(container.persisted?).to eq(project.persisted?)
    end

    it 'returns the correct admin permission' do
      expect(container.admin_permission).to eq(:admin_project)
    end

    it 'returns project_id and no namespace_id' do
      expect(container.project_id).to eq(project.to_global_id.to_s)
      expect(container.namespace_id).to be_nil
    end

    describe '#user_can_admin?' do
      it 'checks admin_project permission' do
        allow(user).to receive(:can?).with(:admin_project, project).and_return(true)

        expect(container.user_can_admin?(user)).to be(true)
      end

      it 'returns false when user lacks permission' do
        allow(user).to receive(:can?).with(:admin_project, project).and_return(false)

        expect(container.user_can_admin?(user)).to be(false)
      end
    end
  end

  context 'when duo_scope resolves to a group' do
    let(:group) { build_stubbed(:group) }
    let(:duo_scope) { { project: nil, namespace: group, default_namespace_applied: false } }

    it 'returns group type' do
      expect(container.type).to eq('group')
      expect(container.project?).to be(false)
    end

    describe '#record' do
      it { is_expected.to have_attributes(record: group) }
    end

    describe '#source' do
      it { is_expected.to have_attributes(source: group) }
    end

    it 'returns the correct admin permission' do
      expect(container.admin_permission).to eq(:admin_group)
    end

    it 'returns namespace_id and no project_id' do
      expect(container.namespace_id).to eq(group.to_global_id.to_s)
      expect(container.project_id).to be_nil
    end

    describe '#user_can_admin?' do
      it 'checks admin_group permission' do
        allow(user).to receive(:can?).with(:admin_group, group).and_return(true)

        expect(container.user_can_admin?(user)).to be(true)
      end
    end
  end

  context 'when duo_scope resolves to nil (no container)' do
    let(:duo_scope) { { project: nil, namespace: nil, default_namespace_applied: true } }

    it 'returns group type by default' do
      expect(container.type).to eq('group')
      expect(container.project?).to be(false)
    end

    describe '#record' do
      it { is_expected.to have_attributes(record: nil) }
    end

    describe '#source' do
      it { is_expected.to have_attributes(source: nil) }
    end

    it { is_expected.not_to be_persisted }

    it 'returns nil for delegated methods' do
      expect(container.to_global_id).to be_nil
      expect(container.root_ancestor).to be_nil
      expect(container.duo_features_enabled).to be_nil
    end

    it 'returns nil for project_id and namespace_id' do
      expect(container.project_id).to be_nil
      expect(container.namespace_id).to be_nil
    end
  end
end
