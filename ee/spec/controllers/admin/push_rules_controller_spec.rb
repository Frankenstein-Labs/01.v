# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::PushRulesController, feature_category: :source_code_management do
  include StubENV

  let_it_be(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe '#update' do
    let(:params) do
      {
        deny_delete_tag: "true", commit_message_regex: "any", branch_name_regex: "any",
        author_email_regex: "any", member_check: "true", file_name_regex: "any",
        max_file_size: "0", prevent_secrets: "true", commit_committer_check: "true", reject_unsigned_commits: "true",
        reject_non_dco_commits: "true", commit_committer_name_check: "true"
      }
    end

    before do
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
      stub_licensed_features(
        commit_committer_check: true,
        reject_unsigned_commits: true,
        reject_non_dco_commits: true,
        commit_committer_name_check: true)
    end

    shared_examples 'successful push rule update' do |count_change: 0|
      it 'updates organization push rule' do
        expect { patch :update, params: { organization_push_rule: params } }.to change {
          OrganizationPushRule.count
        }.by(count_change)

        expect(response).to redirect_to(admin_push_rule_path)
      end

      it 'does not update push rule' do
        expect { patch :update, params: { organization_push_rule: params } }.not_to change { PushRule.count }

        expect(response).to redirect_to(admin_push_rule_path)
      end
    end

    context 'when a sample rule does not exist' do
      it_behaves_like 'successful push rule update', count_change: 1

      it 'assigns correct organization' do
        expect(::PushRules::CreateOrUpdateService)
          .to receive(:new).with(hash_including(container: current_organization)).and_call_original

        patch :update, params: { organization_push_rule: params }

        expect(OrganizationPushRuleFinder.new(current_organization).execute.organization).to eq(current_organization)
      end
    end

    context 'when a sample rule exists' do
      let_it_be(:organization_push_rule) do
        OrganizationPushRule.find_or_create_by!(organization: current_organization)
      end

      it_behaves_like 'successful push rule update', count_change: 0
    end

    it 'does not link organization push rule with application settings' do
      patch :update, params: { organization_push_rule: params }

      expect(ApplicationSetting.current.push_rule_id).to be_nil
    end

    context 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it 'returns 404' do
        patch :update, params: { organization_push_rule: params }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe '#show' do
    it 'returns 200' do
      get :show

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'push rule initialization' do
      it 'initializes an organization push rule' do
        get :show

        expect(assigns(:push_rule)).to be_a(OrganizationPushRule)
        expect(assigns(:push_rule).organization_id).to eq(current_organization.id)
      end
    end

    context 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it 'returns 404' do
        get :show

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
