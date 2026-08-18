# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuo::ModelSelectionHelper, feature_category: :ai_abstraction_layer do
  let(:group) { build_stubbed(:group) }
  let(:user) { build_stubbed(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe 'group_model_selection_view_model' do
    subject(:view_model) { helper.group_model_selection_view_model(group) }

    context 'when the user can read and update the model selection allowlist' do
      before do
        allow(helper).to receive(:can?).and_call_original
        allow(helper).to receive(:can?).with(user, :read_model_selection_allowlist, group).and_return(true)
        allow(helper).to receive(:can?).with(user, :update_model_selection_allowlist, group).and_return(true)
      end

      it 'returns the view model with the allowlist available' do
        expect(view_model).to eq(
          groupId: group.to_gid,
          modelSelectionAllowlistAvailable: true
        )
      end
    end

    context 'when the user cannot read the model selection allowlist' do
      before do
        allow(helper).to receive(:can?).and_call_original
        allow(helper).to receive(:can?).with(user, :read_model_selection_allowlist, group).and_return(false)
        allow(helper).to receive(:can?).with(user, :update_model_selection_allowlist, group).and_return(true)
      end

      it 'returns the view model with the allowlist unavailable' do
        expect(view_model).to include(modelSelectionAllowlistAvailable: false)
      end
    end

    context 'when the user cannot update the model selection allowlist' do
      before do
        allow(helper).to receive(:can?).and_call_original
        allow(helper).to receive(:can?).with(user, :read_model_selection_allowlist, group).and_return(true)
        allow(helper).to receive(:can?).with(user, :update_model_selection_allowlist, group).and_return(false)
      end

      it 'returns the view model with the allowlist unavailable' do
        expect(view_model).to include(modelSelectionAllowlistAvailable: false)
      end
    end
  end
end
