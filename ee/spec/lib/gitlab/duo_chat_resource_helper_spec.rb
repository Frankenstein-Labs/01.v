# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoChatResourceHelper, feature_category: :duo_chat do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:user) { create(:user) }
  let(:helper_class) { Class.new { include Gitlab::DuoChatResourceHelper } }
  let(:helper) { helper_class.new }

  before do
    allow(helper).to receive(:resource).and_return(resource)
  end

  describe '#namespace' do
    context 'when resource is a group' do
      let(:resource) { group }

      it 'returns the group itself' do
        expect(helper.namespace).to eq(group)
      end
    end

    context 'when resource is a project' do
      let(:resource) { project }

      it 'returns the project group' do
        expect(helper.namespace).to eq(group)
      end
    end

    context 'when resource is a user' do
      let(:resource) { user }

      it 'returns nil' do
        expect(helper.namespace).to be_nil
      end
    end

    context 'when resource has a project parent' do
      let(:resource) { issue }

      it 'returns the project group' do
        expect(helper.namespace).to eq(group)
      end
    end

    context 'when resource has a group parent' do
      let(:resource) { epic }

      it 'returns the group' do
        expect(helper.namespace).to eq(group)
      end
    end
  end

  describe '#project' do
    context 'when resource is a project' do
      let(:resource) { project }

      it 'returns the project itself' do
        expect(helper.project).to eq(project)
      end
    end

    context 'when resource is a group' do
      let(:resource) { group }

      it 'returns nil' do
        expect(helper.project).to be_nil
      end
    end

    context 'when resource is a user' do
      let(:resource) { user }

      it 'returns nil' do
        expect(helper.project).to be_nil
      end
    end

    context 'when resource has a project parent' do
      let(:resource) { issue }

      it 'returns the parent project' do
        expect(helper.project).to eq(project)
      end
    end

    context 'when resource has a group parent' do
      let(:resource) { epic }

      it 'returns nil' do
        expect(helper.project).to be_nil
      end
    end
  end
end
