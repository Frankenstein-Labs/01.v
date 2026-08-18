# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Namespaces::Metadata::GroupNamespaceMetadataType, feature_category: :groups_and_projects do
  include GraphqlHelpers

  describe '#show_new_work_item' do
    let_it_be_with_reload(:namespace) { create(:group) }
    let_it_be(:developer) { create(:user) }

    before_all do
      namespace.add_developer(developer)
    end

    before do
      stub_licensed_features(epics: true)
    end

    context 'when user can create work items' do
      it 'returns true' do
        expect(resolve_field(:show_new_work_item, namespace, current_user: developer)).to be(true)
      end
    end

    context 'when user is not a member' do
      let(:non_member) { create(:user) }

      it 'returns false' do
        expect(resolve_field(:show_new_work_item, namespace, current_user: non_member)).to be(false)
      end
    end

    context 'when user is not signed in' do
      it 'returns false' do
        expect(resolve_field(:show_new_work_item, namespace, current_user: nil)).to be(false)
      end
    end

    context 'when epics feature is not licensed' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns false even for members' do
        expect(resolve_field(:show_new_work_item, namespace, current_user: developer)).to be(false)
      end
    end

    context 'when group is archived' do
      before do
        namespace.update!(archived: true)
      end

      it 'returns false' do
        expect(resolve_field(:show_new_work_item, namespace, current_user: developer)).to be(false)
      end
    end
  end
end
