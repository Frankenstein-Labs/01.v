# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::DependencyListExport, feature_category: :dependency_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  describe 'associations' do
    subject(:export) { build(:dependency_list_export, project: project) }

    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:author).class_name('User') }

    it do
      is_expected
        .to have_many(:export_parts)
        .class_name('Dependencies::DependencyListExport::Part')
        .dependent(:destroy)
    end

    describe '#pipeline' do
      it_behaves_like 'a partition-pruned pipeline association' do
        # .reload clears the :pipeline target cached by the attribute writer.
        let(:related_resource) do
          create(:dependency_list_export, pipeline: pipeline, project: pipeline.project).reload
        end
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:export_type) }
    it { is_expected.not_to validate_presence_of(:file) }

    context 'when export is finished' do
      subject(:export) { build(:dependency_list_export, :finished, project: project) }

      it { is_expected.to validate_presence_of(:file) }
    end

    describe 'only one exportable can be set' do
      let(:expected_error) { { error: 'Only one exportable is required' } }

      subject { export.errors.details[:base] }

      before do
        export.validate
      end

      where(:args, :valid) do
        group = build_stubbed(:group)
        project = build_stubbed(:project, group: group)
        pipeline = build_stubbed(:ci_pipeline, project: project)

        [
          [{ group: group, project: project, pipeline: pipeline }, false],
          [{ group: group, project: project, pipeline: nil }, false],
          [{ group: group, project: nil, pipeline: pipeline }, false],
          [{ group: group, project: nil, pipeline: nil }, true],
          [{ group: nil, project: project, pipeline: pipeline }, true],
          [{ group: nil, project: project, pipeline: nil }, true],
          [{ group: nil, project: nil, pipeline: pipeline }, true],
          [{ group: nil, project: nil, pipeline: nil }, false]
        ]
      end

      with_them do
        let(:export) { build(:dependency_list_export, **args) }

        if params[:valid]
          it { is_expected.not_to include(expected_error) }
        else
          it { is_expected.to include(expected_error) }
        end
      end
    end
  end

  describe '.expired' do
    let!(:expired_now) { create(:dependency_list_export, expires_at: Time.zone.now) }
    let!(:expired_recently) { create(:dependency_list_export, expires_at: 1.hour.ago) }
    let!(:expiring_soon) { create(:dependency_list_export, expires_at: 1.hour.from_now) }
    let!(:not_set) { create(:dependency_list_export, expires_at: nil) }

    subject(:expired) { described_class.expired }

    it 'returns only expired exports', :freeze_time do
      expect(expired).to match_array([expired_now, expired_recently])
    end
  end

  describe '#status' do
    subject(:dependency_list_export) do
      SecApplicationRecord.feature_flagged_transaction_for(project) do
        create(:dependency_list_export, project: project)
      end
    end

    around do |example|
      freeze_time { example.run }
    end

    context 'when the export is new' do
      it { is_expected.to have_attributes(status: 0) }

      context 'and it fails' do
        before do
          dependency_list_export.failed!
        end

        it { is_expected.to have_attributes(status: -1) }
      end
    end

    context 'when the export starts' do
      before do
        dependency_list_export.start!
      end

      it { is_expected.to have_attributes(status: 1) }
    end

    context 'when the export is running' do
      context 'and it finishes' do
        subject(:dependency_list_export) { create(:dependency_list_export, :with_file, :running, project: project) }

        before do
          dependency_list_export.finish!
        end

        it { is_expected.to have_attributes(status: 2) }
      end

      context 'and it fails' do
        subject(:dependency_list_export) { create(:dependency_list_export, :running, project: project) }

        before do
          dependency_list_export.failed!
        end

        it { is_expected.to have_attributes(status: -1) }
      end
    end
  end

  describe '#completed?' do
    let(:export) { create(:dependency_list_export, status) }

    where(:status, :expected) do
      :created  | false
      :running  | false
      :finished | true
      :failed   | true
    end

    with_them do
      it 'returns expected value' do
        expect(export.completed?).to eq(expected)
      end
    end
  end

  describe '#retrieve_upload' do
    let(:dependency_list_export) { create(:dependency_list_export, :finished, project: project) }
    let(:relative_path) { dependency_list_export.file.url[1..] }

    subject(:retrieve_upload) { dependency_list_export.retrieve_upload(dependency_list_export, relative_path) }

    it { is_expected.to be_present }
  end

  describe '#exportable' do
    let(:export) do
      build(:dependency_list_export,
        project: project,
        group: group,
        pipeline: pipeline)
    end

    subject { export.exportable }

    context 'when the exportable is a project' do
      let(:group) { nil }
      let(:pipeline) { nil }

      it { is_expected.to eq(project) }
    end

    context 'when the exportable is a group' do
      let(:project) { nil }
      let(:pipeline) { nil }

      it { is_expected.to eq(group) }
    end

    context 'when the exportable is a pipeline' do
      let(:project) { nil }
      let(:group) { nil }

      it { is_expected.to eq(pipeline) }
    end
  end

  describe '#exportable=' do
    let(:export) { build(:dependency_list_export) }

    after do
      export.project = nil
      export.group = nil
      export.project = nil
      export.pipeline = nil
    end

    specify { expect { export.exportable = project }.to change { export.project }.to(project) }
    specify { expect { export.exportable = group }.to change { export.group }.to(group) }

    it 'sets pipelines and project when given a pipeline' do
      expect { export.exportable = pipeline }.to change { export.pipeline }.to(pipeline)
        .and change { export.project }.to(pipeline.project)
    end
  end

  describe '#export_service' do
    let(:export) { build(:dependency_list_export) }

    subject { export.export_service }

    it { is_expected.to be_an_instance_of(Dependencies::Export::SegmentedExportService) }
  end

  describe '#send_completion_email!' do
    let_it_be(:export) { build_stubbed(:dependency_list_export) }

    let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

    subject(:send_completion_email!) { export.send_completion_email! }

    it 'does not send email' do
      expect(Sbom::ExportMailer).not_to receive(:completion_email)

      send_completion_email!
    end

    context 'when send_email is set to true' do
      let_it_be(:export) { build_stubbed(:dependency_list_export, send_email: true) }

      it 'delivers email using Sbom::ExportMailer' do
        expect(Sbom::ExportMailer).to receive(:completion_email).with(export).and_return(message_delivery)
        expect(message_delivery).to receive(:deliver_now)

        send_completion_email!
      end
    end
  end

  describe '#schedule_export_deletion' do
    let(:export) { create(:dependency_list_export) }

    subject(:schedule_export_deletion) { export.schedule_export_deletion }

    it 'sets `expires_at`', :freeze_time do
      expect { schedule_export_deletion }.to change { export.reload.expires_at }
        .from(nil).to(described_class::EXPIRES_AFTER.from_now)
    end
  end

  describe '#timed_out?' do
    let(:created_at) { (Dependencies::DependencyListExport::MAX_EXPORT_DURATION - 1.hour).ago }
    let(:export) { create(:dependency_list_export, created_at: created_at) }

    subject { export.timed_out? }

    context 'when the export has not been running for too long' do
      it { is_expected.to be_falsey }
    end

    context 'when the export has been running for too long' do
      let(:created_at) { (Dependencies::DependencyListExport::MAX_EXPORT_DURATION + 1.hour).ago }

      it { is_expected.to be_truthy }
    end
  end

  context 'with loose foreign key on dependency_list_exports.user_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:user) }
      let_it_be(:model) { create(:dependency_list_export, author: parent) }
    end
  end

  context 'with loose foreign key on dependency_list_exports.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:dependency_list_export, project: parent) }
    end
  end

  context 'with loose foreign key on dependency_list_exports.group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:dependency_list_export, project: nil, group: parent) }
    end
  end

  describe '#uploads_sharding_key' do
    it 'returns one of organization_id, group_id, or project_id' do
      parents = { organization: nil, group: nil, project: nil }

      parents.each_key do |parent_type|
        parent = build_stubbed(parent_type)
        export = build_stubbed(:dependency_list_export, **parents.merge(parent_type => parent))

        key_name = case parent_type
                   when :organization then :organization_id
                   when :group then :namespace_id
                   when :project then :project_id
                   end

        expect(export.uploads_sharding_key).to eq(
          { organization_id: nil, namespace_id: nil, project_id: nil }.merge(key_name => parent.id)
        )
      end
    end
  end
end
