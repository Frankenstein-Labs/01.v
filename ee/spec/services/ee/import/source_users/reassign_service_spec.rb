# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::SourceUsers::ReassignService, feature_category: :importers do
  let_it_be(:group) { create(:group) }
  let_it_be(:import_source_user) { create(:import_source_user, namespace: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:assignee_user) { create(:user) }
  let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }
  let_it_be(:another_service_account) { create(:service_account, provisioned_by_group: create(:group)) }

  subject(:service) { described_class.new(import_source_user, assignee_user, current_user: current_user) }

  describe '#execute' do
    before_all do
      group.add_owner(current_user)
    end

    shared_examples 'an error response' do |desc, error:|
      it "returns #{desc} error", :aggregate_failures do
        expect(Notify).not_to receive(:import_source_user_reassign)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq(error)
      end
    end

    shared_examples 'success response' do
      it 'returns success', :aggregate_failures do
        expect(Notify).to receive_message_chain(:import_source_user_reassign, :deliver_later)

        result = service.execute

        expect(result).to be_success
        expect(result.payload.reload).to eq(import_source_user)
        expect(result.payload.reassign_to_user).to eq(assignee_user)
        expect(result.payload.reassigned_by_user).to eq(current_user)
        expect(result.payload.awaiting_approval?).to be(true)
      end
    end

    shared_examples 'a success response that bypasses user confirmation' do
      it 'returns success', :aggregate_failures do
        expect(Import::ReassignPlaceholderUserRecordsWorker).to receive(:perform_async).with(import_source_user.id,
          'confirmation_skipped' => true)

        result = service.execute

        expect(result).to be_success
        expect(result.payload.reload).to eq(import_source_user)
        expect(result.payload.reassign_to_user).to eq(assignee_user)
        expect(result.payload.reassigned_by_user).to eq(current_user)
        expect(result.payload.reassignment_in_progress?).to be(true)
      end
    end

    context 'for SSO enforcement requirements' do
      before do
        stub_licensed_features(group_saml: true)
      end

      context 'when SSO enforcement is enabled for namespace' do
        let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }

        context 'when assignee user account does not meet SSO enforcement requirements' do
          it_behaves_like 'an error response', 'invalid_assignee',
            error: 'You can assign only users with linked SAML and SCIM identities. ' \
              'Ensure the user has signed into GitLab through your SAML SSO provider and has an ' \
              'active SCIM identity for this group.'

          context 'when assignee user account with linked SAML, but SCIM identity is inactive' do
            let_it_be(:group_saml_identity) do
              create(:group_saml_identity, saml_provider: saml_provider, user: assignee_user)
            end

            let_it_be(:group_scim_identity) do
              create(:group_scim_identity, active: false, group: group, user: assignee_user)
            end

            it_behaves_like 'an error response', 'invalid_assignee',
              error: 'You can assign only users with linked SAML and SCIM identities. ' \
                'Ensure the user has signed into GitLab through your SAML SSO provider and has an ' \
                'active SCIM identity for this group.'
          end
        end

        context 'when assignee user account meets SSO enforcement requirements' do
          let_it_be(:group_saml_identity) do
            create(:group_saml_identity, saml_provider: saml_provider, user: assignee_user)
          end

          it_behaves_like 'success response'
        end
      end

      context 'when SSO enforcement is not enabled for namespace' do
        let!(:saml_provider) { create(:saml_provider, group: group, enforced_sso: false) }

        context 'when assignee user account does not meet SSO enforcement requirements' do
          it_behaves_like 'success response'
        end
      end
    end

    context 'for enterprise users check' do
      before do
        # Needed for managed_by_group?
        stub_licensed_features(domain_verification: true)
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      context 'when there are enterprise users' do
        let_it_be(:enterprise_user) { create(:user, enterprise_group: group) }

        context 'when the user is part of the enterprise group' do
          let_it_be(:assignee_user) { enterprise_user }

          it_behaves_like 'success response'
        end

        context 'when the user is an enterprise users for another group' do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:assignee_user) { create(:user, enterprise_group: other_group) }

          it_behaves_like 'an error response',
            error: "You can assign only enterprise users in the top-level group you're importing to."
        end

        context 'when the user is not part of an enterprise group' do
          it_behaves_like 'an error response',
            error: "You can assign only enterprise users in the top-level group you're importing to."
        end
      end

      context 'when there are no enterprise users' do
        it_behaves_like 'success response'
      end
    end

    context 'when enterprise bypass placeholder confirmation is allowed' do
      before do
        allow_next_instance_of(Import::UserMapping::EnterpriseBypassAuthorizer, group, assignee_user,
          current_user) do |authorizer|
          allow(authorizer).to receive(:allowed?).and_return(true)
        end
      end

      it_behaves_like 'a success response that bypasses user confirmation'
    end

    describe 'service account reassignment' do
      context 'when assignee user is a service account that belongs to the group' do
        let(:assignee_user) { service_account }

        it_behaves_like 'a success response that bypasses user confirmation'
      end

      context 'when assignee user is a service account that does not belong to the group' do
        let(:assignee_user) { another_service_account }

        it_behaves_like 'an error response',
          error: "Service account does not belong to top level group."
      end
    end
  end
end
