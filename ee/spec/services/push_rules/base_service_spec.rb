# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRules::BaseService, feature_category: :source_code_management do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { User.new }

  let(:project) { build_stubbed(:project, group: group) }
  let(:organization) { build_stubbed(:organization) }
  let(:container) { organization }

  subject(:instance) { described_class.new(container: container, current_user: user) }

  describe '#initialize' do
    it 'accepts organization as container' do
      instance = described_class.new(container: organization, current_user: user)

      expect(instance.container).to eq(organization)
      expect(instance.organization).to eq(organization)
    end
  end

  describe 'container type methods' do
    context 'when container is a project' do
      let(:container) { project }

      it 'correctly identifies container type' do
        expect(instance.project_container?).to be true
        expect(instance.group_container?).to be false
        expect(instance.organization_container?).to be false
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      it 'correctly identifies container type' do
        expect(instance.project_container?).to be false
        expect(instance.group_container?).to be true
        expect(instance.organization_container?).to be false
      end
    end

    context 'when container is an organization' do
      let(:container) { organization }

      it 'correctly identifies container type' do
        expect(instance.project_container?).to be false
        expect(instance.group_container?).to be false
        expect(instance.organization_container?).to be true
      end
    end

    context 'when container is a project namespace' do
      let(:container) { build_stubbed(:project_namespace, project: project) }

      it 'correctly identifies container type' do
        expect(instance.project_container?).to be false
        expect(instance.group_container?).to be false
        expect(instance.organization_container?).to be false
        expect(instance.namespace_container?).to be true
      end
    end
  end
end
