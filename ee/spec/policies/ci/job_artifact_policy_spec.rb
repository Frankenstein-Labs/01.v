# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobArtifactPolicy, :models, feature_category: :job_artifacts do
  using RSpec::Parameterized::TableSyntax

  subject(:policy) { described_class.new(current_user, job_artifact) }

  describe 'job artifacts access for different roles' do
    before do
      case role
      when :developer  then project.add_developer(current_user)
      when :maintainer then project.add_maintainer(current_user)
      when :owner      then project.add_owner(current_user)
      when :reporter   then project.add_reporter(current_user)
      when :guest      then project.add_guest(current_user)
      when :auditor    then project.add_developer(current_user) # rubocop:disable Lint/DuplicateBranch -- we still need to mimic developer role for auditor
      end
    end

    let_it_be(:project)  { create(:project, :small_repo, public_builds: true) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
    let_it_be(:job)      { create(:ci_build, :success, pipeline: pipeline, project: project) }

    let(:current_user) { role == :auditor ? create(:user, :auditor) : create(:user) }
    let(:job_artifact) { create(:ci_job_artifact, artifact_trait, job: job, project: project) }

    where(:role, :artifact_trait, :allowed) do
      # No access
      :no_access | :private    | false
      :no_access | :public     | false
      :no_access | :none       | false
      :no_access | :maintainer_only_access | false

      # Developer
      :developer | :private    | true
      :developer | :public     | true
      :developer | :none       | false
      :developer | :maintainer_only_access | false

      # Maintainer
      :maintainer | :private    | true
      :maintainer | :public     | true
      :maintainer | :none       | false
      :maintainer | :maintainer_only_access | true

      # Owner
      :owner | :private    | true
      :owner | :public     | true
      :owner | :none       | false
      :owner | :maintainer_only_access | true

      # Auditor (member as developer)
      :auditor | :private    | true
      :auditor | :public     | true
      :auditor | :none       | false
      :auditor | :maintainer_only_access | false

      # Reporter
      :reporter | :private    | false
      :reporter | :public     | true
      :reporter | :none       | false
      :reporter | :maintainer_only_access | false

      # Guest
      :guest | :private    | false
      :guest | :public     | true
      :guest | :none       | false
      :guest | :maintainer_only_access | false
    end

    with_them do
      it { is_expected.to(allowed ? be_allowed(:read_job_artifacts) : be_disallowed(:read_job_artifacts)) }
    end
  end

  describe 'Security Manager access to security report artifacts' do
    let_it_be(:project)  { create(:project, :small_repo, public_builds: true) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
    let_it_be(:job)      { create(:ci_build, :success, pipeline: pipeline, project: project) }
    let_it_be(:current_user) { create(:user, security_manager_of: project) }

    context 'with a private security report artifact' do
      where(:file_type, :file_format) do
        [
          [:sast,                   :raw],
          [:secret_detection,       :raw],
          [:dast,                   :raw],
          [:dependency_scanning,    :raw],
          [:container_scanning,     :raw],
          [:cluster_image_scanning, :raw],
          [:coverage_fuzzing,       :raw],
          [:api_fuzzing,            :raw],
          [:sarif,                  :raw],
          [:cyclonedx,              :gzip],
          [:license_scanning,       :raw]
        ]
      end

      with_them do
        let(:job_artifact) do
          create(:ci_job_artifact, :private, job: job, project: project, file_type: file_type, file_format: file_format)
        end

        it { is_expected.to be_allowed(:read_job_artifacts) }
      end
    end

    context 'with a private non-security artifact' do
      let(:job_artifact) { create(:ci_job_artifact, :private, job: job, project: project) }

      it { is_expected.to be_disallowed(:read_job_artifacts) }
    end

    context 'with a public non-security artifact' do
      let(:job_artifact) { create(:ci_job_artifact, :public, job: job, project: project) }

      it { is_expected.to be_allowed(:read_job_artifacts) }
    end

    context 'with a none-access security report artifact' do
      let(:job_artifact) do
        create(:ci_job_artifact, :sast, :none, job: job, project: project)
      end

      it { is_expected.to be_disallowed(:read_job_artifacts) }
    end

    context 'with a maintainer-only-access security report artifact' do
      let(:job_artifact) do
        create(:ci_job_artifact, :sast, :maintainer, job: job, project: project)
      end

      it { is_expected.to be_disallowed(:read_job_artifacts) }
    end
  end

  context 'when guest user and project-based pipeline visibility is disabled' do
    let_it_be(:project) { create(:project, :small_repo, public_builds: false) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
    let_it_be(:job)      { create(:ci_build, :success, pipeline: pipeline, project: project) }

    let_it_be(:guest) { create(:user) }
    let(:current_user) { guest }
    let(:job_artifact) { create(:ci_job_artifact, :public, job: job, project: project) }

    before do
      project.add_guest(guest)
    end

    it 'disallows read_job_artifacts' do
      expect(policy).to be_disallowed(:read_job_artifacts)
    end
  end
end
