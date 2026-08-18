# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::SyncLicensePolicyRuleService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:security_policy) { create(:security_policy) }
  let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read) }
  let_it_be_with_reload(:approval_policy_rule) do
    create(:approval_policy_rule, :license_finding, security_policy: security_policy)
  end

  let_it_be(:software_license_policy) do
    create(:software_license_policy, project: project, approval_policy_rule: approval_policy_rule)
  end

  let(:license_names) { ['BSD 1-Clause License', 'MIT License'] }
  let(:licenses_count) { license_names.size }

  let(:service) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rule: approval_policy_rule,
      scan_result_policy_read: scan_result_policy_read
    )
  end

  describe '#execute' do
    shared_examples_for 'calls create service for each license name' do
      it 'calls create service for each license name' do
        create_service = instance_double(SoftwareLicensePolicies::CreateService)

        expect(SoftwareLicensePolicies::CreateService)
          .to receive(:new)
          .exactly(licenses_count).times
          .and_return(create_service)

        expect(create_service).to receive(:execute).exactly(licenses_count).times

        service.execute
      end
    end

    shared_examples_for 'creates software license policies' do
      it 'creates software license policies' do
        service.execute

        software_license_policies = project.reload.software_license_policies

        expect(software_license_policies.count).to eq(licenses_count)
        license_names.each_with_index do |license_name, i|
          expect(software_license_policies[i].name).to eq(license_name)
          expect(software_license_policies[i].approval_status).to eq(approval_status)
          expect(software_license_policies[i].approval_policy_rule_id).to eq(approval_policy_rule.id)
        end
      end
    end

    shared_examples_for 'deletes existing software license policies' do
      it 'deletes existing software license policies' do
        service.execute

        expect { software_license_policy.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when using the license_types property' do
      before do
        approval_policy_rule.content.delete('licenses')
        approval_policy_rule.content['license_types'] = license_names
        approval_policy_rule.content['match_on_inclusion_license'] = match_on_inclusion_license
        approval_policy_rule.save!
      end

      context 'when using match_on_inclusion_license true' do
        let(:approval_status) { 'denied' }
        let(:match_on_inclusion_license) { true }

        it_behaves_like 'calls create service for each license name'

        it_behaves_like 'creates software license policies'

        it_behaves_like 'deletes existing software license policies'
      end

      context 'when using match_on_inclusion_license false' do
        let(:approval_status) { 'allowed' }
        let(:match_on_inclusion_license) { false }

        it_behaves_like 'calls create service for each license name'

        it_behaves_like 'creates software license policies'

        it_behaves_like 'deletes existing software license policies'
      end
    end

    context 'when using the licenses property' do
      let(:licenses) do
        license_names.map do |license|
          { 'name' => license }
        end
      end

      before do
        approval_policy_rule.content.delete('license_types')
        approval_policy_rule.content.delete('licenses')
        approval_policy_rule.content['licenses'] = { approval_status => licenses }
        approval_policy_rule.save!
      end

      context 'when using the denied property' do
        let(:approval_status) { 'denied' }

        it_behaves_like 'calls create service for each license name'

        it_behaves_like 'creates software license policies'

        it_behaves_like 'deletes existing software license policies'
      end

      context 'when using the allowed property' do
        let(:approval_status) { 'allowed' }

        it_behaves_like 'calls create service for each license name'

        it_behaves_like 'creates software license policies'

        it_behaves_like 'deletes existing software license policies'
      end
    end

    context 'when neither license_types nor licenses are provided' do
      before do
        approval_policy_rule.content.delete('license_types')
        approval_policy_rule.content.delete('licenses')
      end

      it 'does not calls create service' do
        expect(SoftwareLicensePolicies::CreateService).not_to receive(:new)

        service.execute
      end

      it 'does not raise NoMethodError' do
        expect { service.execute }.not_to raise_error
      end
    end
  end
end
