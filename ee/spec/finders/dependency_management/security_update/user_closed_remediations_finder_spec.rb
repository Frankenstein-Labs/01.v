# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::UserClosedRemediationsFinder,
  feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:service_account) do
    create(:user, :service_account, name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
  end

  let_it_be(:maintainer) { create(:user) }

  subject(:finder) { described_class.new(project: project) }

  before_all do
    project.add_member(service_account, :guest)
  end

  before do
    allow(project).to receive(:dependency_management_service_account).and_return(service_account)
  end

  def create_remediation_mr(
    source_branch: 'dependency-management/rails-6.x', state: :closed, author: service_account, closed_by: nil)
    create(:merge_request, state, :with_closed_by,
      target_project: project, source_project: project, author: author,
      source_branch: source_branch, target_branch: 'main', skip_branch_existence_check: true,
      closed_by: closed_by)
  end

  describe '#dismissed_branch?' do
    let(:branch) { 'dependency-management/rails-6.x' }

    context 'when there is no dependency management service account' do
      before do
        allow(project).to receive(:dependency_management_service_account).and_return(nil)
      end

      it 'returns false' do
        expect(finder.dismissed_branch?(branch)).to be(false)
      end
    end

    it 'is true when a maintainer closed a remediation MR on the branch' do
      create_remediation_mr(source_branch: branch, closed_by: maintainer)

      expect(finder.dismissed_branch?(branch)).to be(true)
    end

    it 'is false when there is no remediation MR on the branch' do
      expect(finder.dismissed_branch?(branch)).to be(false)
    end

    it 'is false when the service account closed it (no-maintainer auto-close)' do
      create_remediation_mr(source_branch: branch, closed_by: service_account)

      expect(finder.dismissed_branch?(branch)).to be(false)
    end

    it 'is false when the MR on the branch is open' do
      create_remediation_mr(source_branch: branch, state: :opened)

      expect(finder.dismissed_branch?(branch)).to be(false)
    end

    it 'is false when the MR on the branch is merged' do
      create_remediation_mr(source_branch: branch, state: :merged, closed_by: maintainer)

      expect(finder.dismissed_branch?(branch)).to be(false)
    end

    it 'is false when the MR was authored by someone other than the service account' do
      create_remediation_mr(source_branch: branch, author: maintainer, closed_by: maintainer)

      expect(finder.dismissed_branch?(branch)).to be(false)
    end
  end

  describe '#for_vulnerability' do
    let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }

    let(:merge_request) { create_remediation_mr(closed_by: maintainer) }
    let(:link_vulnerability) { vulnerability }

    subject(:result) { finder.for_vulnerability(vulnerability) }

    def link(merge_request, vuln: vulnerability)
      create(:vulnerabilities_merge_request_link, vulnerability: vuln, finding: vuln.finding,
        merge_request: merge_request)
    end

    before do
      link(merge_request, vuln: link_vulnerability)
    end

    it 'returns human-closed remediation MRs linked to the vulnerability' do
      expect(result).to contain_exactly(merge_request)
    end

    context 'when the service account closed it (no-maintainer auto-close)' do
      let(:merge_request) { create_remediation_mr(closed_by: service_account) }

      it { is_expected.to be_empty }
    end

    context 'when linked to a different vulnerability' do
      let_it_be(:other) { create(:vulnerability, :with_finding, project: project) }
      let(:link_vulnerability) { other }

      it { is_expected.to be_empty }
    end

    context 'when the MR is merged' do
      let(:merge_request) { create_remediation_mr(state: :merged, closed_by: maintainer) }

      it { is_expected.to be_empty }
    end

    context 'when the closer is unknown (no metrics closer recorded)' do
      let(:merge_request) { create_remediation_mr(closed_by: nil).tap(&:ensure_metrics!) }

      it { is_expected.to be_empty }
    end

    context 'when there is no dependency management service account' do
      before do
        allow(project).to receive(:dependency_management_service_account).and_return(nil)
      end

      it { is_expected.to be_empty }
    end
  end
end
