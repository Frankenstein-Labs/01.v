# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::EnterpriseUsers::BulkAssociateByDomainWorker, :saas, feature_category: :user_management do
  subject(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker' do
    let(:pages_domain) { create(:pages_domain) }
    let(:job_args) { [pages_domain.id] }
  end

  describe '#perform' do
    shared_examples 'does not do anything' do
      it 'does not do anything', :aggregate_failures do
        expect(User).not_to receive(:select).and_call_original
        expect(User).not_to receive(:human).and_call_original
        expect(User).not_to receive(:with_email_domain).and_call_original
        expect(User).not_to receive(:excluding_enterprise_users_of_group).and_call_original
        expect(User).not_to receive(:each_batch).and_call_original

        expect(Groups::EnterpriseUsers::AssociateWorker)
          .not_to receive(:bulk_perform_async).and_call_original

        worker.perform(pages_domain_id)
      end
    end

    shared_examples 'bulk perform async Groups::EnterpriseUsers::AssociateWorker' do
      it 'bulk perform async Groups::EnterpriseUsers::AssociateWorker', :aggregate_failures do
        expect(User).to receive(:select).with(:id).and_call_original
        expect(User).to receive(:human).and_call_original
        expect(User).to receive(:with_email_domain).with(pages_domain.domain).and_call_original
        expect(User).to receive(:excluding_enterprise_users_of_group).with(pages_domain.root_group).and_call_original
        expect(User).to receive(:each_batch).with(of: 100).and_call_original

        expect(Groups::EnterpriseUsers::AssociateWorker)
          .to receive(:bulk_perform_async).and_call_original

        worker.perform(pages_domain_id)
      end

      it 'bulk perform async Groups::EnterpriseUsers::AssociateWorker ' \
         'only for users with email domain that is equal to the specified domain, ' \
         'excluding users who are already enterprise users of the group', :aggregate_failures do
        expect(Groups::EnterpriseUsers::AssociateWorker).to receive(:bulk_perform_async) do |args_list|
          expected_args_list = [
            user_with_the_specified_domain_1,
            user_with_the_specified_domain_2,
            enterprise_user_of_some_group_with_the_specified_domain,
            not_enterprise_user_with_the_specified_domain,
            user_without_user_detail_record_with_the_specified_domain
          ].map { |user| [user.id] }

          expect(args_list).to match_array(expected_args_list)
        end

        worker.perform(pages_domain_id)
      end
    end

    context 'when pages_domain does not exist for given pages_domain_id' do
      let(:pages_domain_id) { -1 }

      include_examples 'does not do anything'
    end

    context 'when pages_domain exist for given pages_domain_id' do
      let(:pages_domain) { create(:pages_domain, domain: email_domain, project: project) }
      let(:pages_domain_id) { pages_domain.id }
      let(:email_domain) { 'example.GitLab.com' }

      let!(:user_with_the_specified_domain_1) do
        create(:user, email: "user_with_the_specified_domain_1@#{pages_domain.domain}")
      end

      let!(:user_with_the_specified_domain_2) do
        create(:user, email: "user_with_the_specified_domain_2@#{pages_domain.domain}").tap do |user|
          user.update_column(:email, "user_with_the_specified_domain_2@#{pages_domain.domain.swapcase}")
        end
      end

      let!(:user_with_subdomain_of_the_specified_domain) do
        create(:user, email: "user_with_subdomain_of_the_specified_domain@subdomain.#{pages_domain.domain}")
      end

      let!(:user_with_domain_that_contains_the_specified_domain) do
        create(
          :user,
          email: "user_with_domain_that_contains_the_specified_domain@subdomain.#{pages_domain.domain}.example.com"
        )
      end

      context 'when pages_domain belongs to project' do
        context 'when project belongs to user' do
          let_it_be(:user_namespace) { create(:user).namespace }
          let_it_be(:project) { create(:project, namespace: user_namespace) }

          include_examples 'does not do anything'
        end
      end

      context 'when project belongs to root group' do
        let_it_be(:root_group) { create(:group) }
        let_it_be(:project) { create(:project, namespace: root_group) }

        let!(:enterprise_user_of_the_group_with_the_specified_domain) do
          create(
            :user,
            enterprise_group_id: root_group.id,
            email: "enterprise_user_of_the_group_with_the_specified_domain@#{pages_domain.domain}"
          )
        end

        let!(:enterprise_user_of_some_group_with_the_specified_domain) do
          create(
            :enterprise_user,
            email: "enterprise_user_of_some_group_with_the_specified_domain@#{pages_domain.domain}"
          )
        end

        let!(:not_enterprise_user_with_the_specified_domain) do
          create(
            :user,
            enterprise_group_id: nil, email: "not_enterprise_user_with_the_specified_domain@#{pages_domain.domain}"
          )
        end

        let!(:user_without_user_detail_record_with_the_specified_domain) do
          create(
            :user,
            email: "user_without_user_detail_record_with_the_specified_domain@#{pages_domain.domain}"
          ).tap do |user|
            user.user_detail.destroy!
          end
        end

        let!(:service_account_with_the_specified_domain) do
          create(
            :user,
            :service_account,
            provisioned_by_group_id: root_group.id,
            enterprise_group_id: nil,
            email: "service_account@#{pages_domain.domain}"
          )
        end

        context 'when domain_verification feature is not available for the group' do
          before do
            stub_licensed_features(domain_verification: false)
          end

          include_examples 'does not do anything'
        end

        context 'when domain_verification feature is available for the group' do
          before do
            stub_licensed_features(domain_verification: true)
          end

          include_examples 'bulk perform async Groups::EnterpriseUsers::AssociateWorker'

          context 'when project is in subgroup' do
            let_it_be(:subgroup) { create(:group, parent: root_group) }
            let_it_be(:project) { create(:project, namespace: subgroup) }

            include_examples 'bulk perform async Groups::EnterpriseUsers::AssociateWorker'
          end

          context 'when pages_domain is unverified' do
            before do
              pages_domain.update!(verified_at: nil)
            end

            include_examples 'does not do anything'
          end
        end
      end
    end
  end
end
