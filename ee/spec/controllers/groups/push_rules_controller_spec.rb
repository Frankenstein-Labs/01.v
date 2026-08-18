# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::PushRulesController, feature_category: :source_code_management do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user) }

  describe '#update' do
    let(:params) { { group_id: group, push_rule: { prevent_secrets: true } } }

    subject(:push_rule_update) { patch :update, params: params }

    shared_examples 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)
        group.add_maintainer(user)
      end

      it 'returns 404 status' do
        push_rule_update

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    shared_examples 'updateable setting' do |rule_attr, new_value|
      let(:params) { { group_id: group, push_rule: { rule_attr => new_value } } }

      it 'updates the setting' do
        push_rule_update

        expect(push_rule.public_send(rule_attr)).to eq(new_value)
      end
    end

    shared_examples 'an updatable setting with global default' do |rule_attr|
      context "when #{rule_attr} not specified on global level" do
        before do
          stub_licensed_features(rule_attr => true)
        end

        it_behaves_like 'updateable setting', rule_attr, true
      end

      context "when global setting #{rule_attr} is enabled" do
        before do
          stub_licensed_features(rule_attr => true)
          create(:organization_push_rule, organization_id: group.organization.id, rule_attr => true)
        end

        it_behaves_like 'updateable setting', rule_attr, true
      end
    end

    shared_examples 'not updateable setting' do |rule_attr, new_value|
      let(:params) { { group_id: group, push_rule: { rule_attr => new_value } } }

      it 'does not update the setting' do
        expect { push_rule_update }.not_to change { push_rule.public_send(rule_attr) }
      end
    end

    shared_examples 'a not updatable setting with global default' do |rule_attr|
      context "when #{rule_attr} is disabled" do
        before do
          stub_licensed_features(rule_attr => false)
        end

        it_behaves_like 'not updateable setting', rule_attr, true
      end

      context "when global setting #{rule_attr} is enabled" do
        before do
          stub_licensed_features(rule_attr => true)
          create(:organization_push_rule, organization_id: group.organization.id, rule_attr => true)
        end

        it_behaves_like 'not updateable setting', rule_attr, true
      end
    end

    shared_examples 'a user role lower than maintainer' do
      before do
        sign_in(user)
        group.add_developer(user)
      end

      context 'push rules unlicensed' do
        before do
          stub_licensed_features(push_rules: false)
        end

        it 'returns 404 status' do
          push_rule_update

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'push rules licensed' do
        before do
          stub_licensed_features(push_rules: true)
        end

        it 'returns 404 status' do
          push_rule_update

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    shared_examples 'an update to commit_committer_name_check setting' do
      context 'with licensed feature' do
        let(:params) { { group_id: group, push_rule: { 'commit_committer_name_check' => true } } }

        before do
          stub_licensed_features(commit_committer_name_check: true)
        end

        context 'as an admin', :enable_admin_mode do
          let(:user) { create(:admin) }

          it 'updates the setting' do
            push_rule_update

            expect(push_rule.reload.commit_committer_name_check).to be(true)
          end
        end

        context 'as a maintainer user' do
          before do
            group.add_maintainer(user)
          end

          it 'updates the setting' do
            push_rule_update

            expect(push_rule.reload.commit_committer_name_check).to be(true)
          end
        end

        context 'as a developer user' do
          before do
            group.add_developer(user)
          end

          it 'does not update the setting' do
            push_rule_update

            expect(push_rule.reload.commit_committer_name_check).to be(false)
          end
        end
      end

      context 'with unlicensed feature' do
        let(:params) { { group_id: group, push_rule: { 'commit_committer_name_check' => true } } }

        before do
          stub_licensed_features(commit_committer_name_check: false)
        end

        context 'as an admin', :enable_admin_mode do
          let(:user) { create(:admin) }

          it 'does not update the setting' do
            push_rule_update

            expect(push_rule.reload.commit_committer_name_check).to be(false)
          end
        end

        context 'as a maintainer user' do
          before do
            group.add_maintainer(user)
          end

          it 'does not update the setting' do
            push_rule_update

            expect(push_rule.reload.commit_committer_name_check).to be(false)
          end
        end

        context 'as a developer user' do
          before do
            group.add_developer(user)
          end

          it 'does not update the setting' do
            push_rule_update

            expect(push_rule.reload.commit_committer_name_check).to be(false)
          end
        end
      end
    end

    before do
      sign_in(user)
    end

    context 'push rules licensed' do
      before do
        stub_licensed_features(push_rules: true)
      end

      PushRule::SETTINGS_WITH_GLOBAL_DEFAULT.each do |rule_attr|
        context "Updating #{rule_attr} rule" do
          let(:push_rule) { group.reload.group_push_rule }

          before do
            create(:group_push_rule, group: group, rule_attr => false)
          end

          context 'as an admin' do
            let(:user) { create(:admin) }

            context 'when admin mode enabled', :enable_admin_mode do
              it_behaves_like 'an updatable setting with global default', rule_attr, updates: true
            end

            context 'when admin mode disabled' do
              it_behaves_like 'a not updatable setting with global default', rule_attr, updates: true
            end
          end

          context 'as a maintainer user' do
            before do
              group.add_maintainer(user)
            end

            it 'updates the push rule' do
              push_rule_update

              expect(response).to have_gitlab_http_status(:found)
              expect(push_rule.prevent_secrets).to be_truthy
            end

            context "when global setting #{rule_attr} is disabled" do
              let(:organization_push_rule) do
                create(:organization_push_rule, organization_id: group.organization.id, rule_attr => true)
              end

              let(:push_rule) { organization_push_rule.reload }

              before do
                stub_licensed_features(rule_attr => false)
              end

              it_behaves_like 'updateable setting', rule_attr, true
            end

            context "when global setting #{rule_attr} is enabled" do
              before do
                stub_licensed_features(rule_attr => true)
                create(:organization_push_rule, organization_id: group.organization.id, rule_attr => true)
              end

              it_behaves_like 'not updateable setting', rule_attr, true
            end
          end

          context 'as a developer user' do
            before do
              group.add_developer(user)
            end

            it_behaves_like 'a not updatable setting with global default', rule_attr
          end
        end
      end

      it_behaves_like 'an update to commit_committer_name_check setting' do
        let(:push_rule) { group.reload.group_push_rule }

        before do
          create(:group_push_rule, group: group)
        end
      end
    end

    it_behaves_like 'push rules unlicensed'
    it_behaves_like 'a user role lower than maintainer'
  end
end
