# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Export, feature_category: :vulnerability_management do
  it { is_expected.to define_enum_for(:format).with_values(csv: 0, pdf: 1) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:author).class_name('User').required }
  end

  describe 'validations' do
    subject(:export) { build(:vulnerability_export, **params) }

    let(:params) { {} }

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:format) }
    it { is_expected.not_to validate_presence_of(:file) }

    describe 'report_data JSON schema validation' do
      context 'when report_data is nil' do
        let(:params) { { report_data: nil } }

        it { is_expected.to be_invalid }
      end

      context 'when report_data contains keys not defined in the schema' do
        let(:params) { { report_data: { some_key: 'some value' } } }

        it { is_expected.to be_invalid }
      end

      context 'when report_data contains keys defined in the schema' do
        context 'when the data does not match schema' do
          let(:params) { { report_data: { project_vulnerabilities_history: 'some value' } } }

          it { is_expected.to be_invalid }
        end

        context 'when the data does match schema' do
          let(:params) { { report_data: { project_vulnerabilities_history: { svg: '<svg></svg>' } } } }

          it { is_expected.to be_valid }
        end
      end
    end

    context 'when export is finished' do
      subject(:export) { build(:vulnerability_export, :finished) }

      it { is_expected.to validate_presence_of(:file) }
    end

    describe 'presence of both project and group' do
      let(:export) { build(:vulnerability_export, project: project, group: group) }
      let(:expected_error) { _('Project & Group can not be assigned at the same time') }

      subject { export.errors[:base] }

      before do
        export.validate
      end

      context 'when the project is present' do
        let(:project) { build(:project) }

        context 'when the group is present' do
          let(:group) { build(:group) }

          it { is_expected.to include(expected_error) }
        end

        context 'when the group is not present' do
          let(:group) { nil }

          it { is_expected.not_to include(expected_error) }
        end
      end

      context 'when the project is not present' do
        let(:project) { nil }

        context 'when the group is present' do
          let(:group) { build(:group) }

          it { is_expected.not_to include(expected_error) }
        end

        context 'when the group is not present' do
          let(:group) { nil }

          it { is_expected.not_to include(expected_error) }
        end
      end
    end
  end

  describe '#status' do
    subject(:vulnerability_export) { create(:vulnerability_export, :csv) }

    around do |example|
      SecApplicationRecord.feature_flagged_transaction_for(vulnerability_export.project) do
        freeze_time { example.run }
      end
    end

    context 'when the export is new' do
      it { is_expected.to have_attributes(status: 'created') }
    end

    context 'when the export starts' do
      before do
        vulnerability_export.start!
      end

      it { is_expected.to have_attributes(status: 'running', started_at: Time.current) }
    end

    context 'when the export is running' do
      context 'and it finishes' do
        subject(:vulnerability_export) { create(:vulnerability_export, :csv, :with_file, :running) }

        before do
          vulnerability_export.finish!
        end

        it { is_expected.to have_attributes(status: 'finished', finished_at: Time.current) }
      end

      context 'and it fails' do
        subject(:vulnerability_export) { create(:vulnerability_export, :csv, :running) }

        before do
          vulnerability_export.failed!
        end

        it { is_expected.to have_attributes(status: 'failed', finished_at: Time.current) }
      end
    end
  end

  describe '.expired' do
    let!(:expired_now) { create(:vulnerability_export, expires_at: Time.zone.now) }
    let!(:expired_recently) { create(:vulnerability_export, expires_at: 1.hour.ago) }
    let!(:expiring_soon) { create(:vulnerability_export, expires_at: 1.hour.from_now) }
    let!(:not_set) { create(:vulnerability_export, expires_at: nil) }

    subject(:expired) { described_class.expired }

    it 'returns only expired exports', :freeze_time do
      expect(expired).to match_array([expired_now, expired_recently])
    end
  end

  describe '#exportable' do
    subject { vulnerability_export.exportable }

    context 'when the export has project assigned' do
      let(:project) { build(:project) }
      let(:vulnerability_export) { build(:vulnerability_export, project: project) }

      it { is_expected.to eq(project) }
    end

    context 'when the export does not have project assigned' do
      context 'when the export has group assigned' do
        let(:group) { build(:group) }
        let(:vulnerability_export) { build(:vulnerability_export, :group, group: group) }

        it { is_expected.to eq(group) }
      end

      context 'when the export does not have group assigned' do
        let(:author) { build(:user) }
        let(:vulnerability_export) { build(:vulnerability_export, :user, author: author) }
        let(:mock_security_dashboard) { instance_double(InstanceSecurityDashboard) }

        before do
          allow(author).to receive(:security_dashboard).and_return(mock_security_dashboard)
        end

        it { is_expected.to eq(mock_security_dashboard) }
      end
    end
  end

  describe '#exportable=' do
    let_it_be_with_reload(:author_namespace) { create(:namespace) }
    let_it_be_with_reload(:author) { create(:user, namespace: author_namespace) }

    let(:vulnerability_export) { build(:vulnerability_export, author: author) }

    subject(:set_exportable) { vulnerability_export.exportable = exportable }

    context 'when the exportable is a Project' do
      let_it_be(:exportable) { create(:project) }

      it 'changes the exportable of the export to given project' do
        expect { set_exportable }.to change { vulnerability_export.exportable }.to(exportable)
      end

      it 'sets the organization of the export' do
        expect { set_exportable }.to change { vulnerability_export.organization_id }
          .to(exportable.namespace.organization_id)
      end
    end

    context 'when the exportable is a Group' do
      let(:exportable) { create(:group) }

      it 'changes the exportable of the export to given group' do
        expect { set_exportable }.to change { vulnerability_export.exportable }.to(exportable)
      end

      it 'sets the organization of the export' do
        expect { set_exportable }.to change { vulnerability_export.organization_id }.to(exportable.organization_id)
      end
    end

    context 'when the exportable is an InstanceSecurityDashboard' do
      let(:exportable) { InstanceSecurityDashboard.new(author) }

      before do
        allow(author).to receive(:security_dashboard).and_return(exportable)
      end

      it 'changes the exportable of the export to security dashboard of the author' do
        expect { set_exportable }.to change { vulnerability_export.exportable }.to(exportable)
      end

      it 'sets the organization of the export' do
        expect { set_exportable }.to change { vulnerability_export.organization_id }
          .to(author_namespace.organization_id)
      end

      context 'when the author of the export is not yet assigned' do
        let(:vulnerability_export) { build(:vulnerability_export, author: nil) }

        it 'sets the organization of the export' do
          expect { set_exportable }.to change { vulnerability_export.organization_id }
            .to(author_namespace.organization_id)
        end
      end
    end

    context 'when the exportable is a String' do
      let(:exportable) { 'Foo' }

      it 'raises an exception' do
        expect { set_exportable }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#completed?' do
    context 'when status is created' do
      subject { build(:vulnerability_export, :created) }

      it { is_expected.not_to be_completed }
    end

    context 'when status is running' do
      subject { build(:vulnerability_export, :running) }

      it { is_expected.not_to be_completed }
    end

    context 'when status is finished' do
      subject { build(:vulnerability_export, :finished) }

      it { is_expected.to be_completed }
    end

    context 'when status is failed' do
      subject { build(:vulnerability_export, :failed) }

      it { is_expected.to be_completed }
    end
  end

  describe '#export_service' do
    context 'for csv exports' do
      let(:export) { build(:vulnerability_export, :csv) }

      it 'instantiates an export service for the instance' do
        expect(export.export_service).to be_an_instance_of(::VulnerabilityExports::ExportService)
      end
    end

    context 'for pdf exports' do
      let(:export) { build(:vulnerability_export, :pdf) }

      it 'instantiates an export service for the instance' do
        expect(export.export_service).to be_an_instance_of(::VulnerabilityExports::PdfExportService)
      end
    end
  end

  describe '#retrive_upload' do
    subject(:export) { create(:vulnerability_export) }

    before do
      file = Tempfile.new
      file.print "Hello World!"
      export.update!(file: file)
    end

    it 'retrieves the file associated with the vulnerability export' do
      expect(export.file.read).to eq("Hello World!")
    end
  end

  describe '#schedule_export_deletion' do
    let(:export) { create(:vulnerability_export) }

    subject(:schedule_export_deletion) { export.schedule_export_deletion }

    it 'sets `expires_at`', :freeze_time do
      expect { schedule_export_deletion }
        .to change { export.reload.expires_at }
              .from(nil).to(described_class::EXPIRES_AFTER.from_now)
    end
  end

  describe '#timed_out?' do
    let(:created_at) { (Vulnerabilities::Export::MAX_EXPORT_DURATION - 1.hour).ago }
    let(:export) do
      create(:vulnerability_export,
        created_at: created_at)
    end

    subject { export.timed_out? }

    context 'when the export has not been running for too long' do
      it { is_expected.to be_falsey }
    end

    context 'when the export has been running for too long' do
      let(:created_at) { (Vulnerabilities::Export::MAX_EXPORT_DURATION + 1.hour).ago }

      it { is_expected.to be_truthy }
    end
  end

  context 'with loose foreign key on vulnerability_exports.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:organization) }
      let_it_be(:model) { create(:vulnerability_export, organization: parent) }

      before do
        parent.users.delete_all
      end
    end
  end

  context 'with loose foreign key on vulnerability_exports.group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:namespace) }
      let_it_be(:model) { create(:vulnerability_export, group_id: parent.id) }
    end
  end

  context 'with loose foreign key on vulnerability_exports.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerability_export, project: parent) }
    end
  end

  context 'with loose foreign key on vulnerability_exports.author_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:user) }
      let_it_be(:model) { create(:vulnerability_export, author_id: parent.id) }
    end
  end

  describe '#uploads_sharding_key' do
    it 'returns organization_id' do
      organization = build_stubbed(:organization)
      export = build_stubbed(:vulnerability_export, organization: organization)

      expect(export.uploads_sharding_key).to eq(organization_id: organization.id)
    end
  end

  describe '#send_completion_email!' do
    let_it_be(:export) { build_stubbed(:vulnerability_export) }

    let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

    subject(:send_completion_email!) { export.send_completion_email! }

    it 'does not send email' do
      expect(Sbom::ExportMailer).not_to receive(:completion_email)

      send_completion_email!
    end

    context 'when send_email is set to true' do
      let_it_be(:export) { build_stubbed(:vulnerability_export, send_email: true) }

      it 'delivers email using Sbom::ExportMailer' do
        expect(Vulnerabilities::ExportMailer).to receive(:completion_email).with(export).and_return(message_delivery)
        expect(message_delivery).to receive(:deliver_now)

        send_completion_email!
      end
    end
  end
end
