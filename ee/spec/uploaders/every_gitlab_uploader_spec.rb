# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Every GitLab uploader' do
  context 'for Geo replication' do
    # rubocop:disable Layout/LineLength
    it 'has Geo self-service framework support' do
      replicable_names = replicators.map(&:replicable_name)

      missing_data_types = data_types - replicable_names

      expect(missing_data_types)
        .to be_empty, "New uploader type detected: #{missing_data_types.to_a.inspect}. " \
                      "Additional work may be needed to add Geo support. Geo support is " \
                      "a part of the definition of done, see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/97172. " \
                      "Please visit https://docs.gitlab.com/ee/development/geo.html#ensuring-a-new-feature-has-geo-support " \
                      "for details. If work is not needed, add the uploader to known_unimplemented_uploader? and get a review " \
                      "by a Geo team member."
    end
    # rubocop:enable Layout/LineLength

    def uploaders
      @uploaders ||=
        [].then { |ary| ary.concat(find_uploaders(Rails.root.join('app/uploaders'))) }
          .then { |ary| ary.concat(find_uploaders(Rails.root.join('ee/app/uploaders'))) }
    end

    def find_uploaders(root)
      find_klasses(root, GitlabUploader)
        .reject { |uploader| known_unimplemented_uploader?(uploader) || uploads?(uploader) }
    end

    def replicators
      @replicators ||= find_replicators(Rails.root.join('ee/app/replicators'))
    end

    def find_replicators(root)
      find_klasses(root, Gitlab::Geo::Replicator)
    end

    def find_klasses(root, parent_klass)
      concerns = root.join('concerns').to_s

      Dir[root.join('**', '*.rb')]
        .reject { |path| path.start_with?(concerns) }
        .map    { |path| klass_from_path(path, root) }
        .select { |klass| klass < parent_klass }
    end

    def klass_from_path(path, root)
      ns = Pathname.new(path).relative_path_from(root).to_s.gsub('.rb', '')
      ns.camelize.constantize
    end

    # rubocop:disable Layout/LineLength
    def known_unimplemented_uploader?(uploader)
      {
        DeletedObjectUploader => "Used by Ci::DeletedObject. We don't want to replicate this since the files are physically the same files referenced by Ci::JobArtifact.",
        DependencyProxy::FileUploader => "We do want to replicate this, see https://gitlab.com/groups/gitlab-org/-/epics/8833.",
        Packages::Debian::ComponentFileUploader => "Geo replication is being added incrementally per model. ProjectComponentFile: https://gitlab.com/gitlab-org/gitlab/-/issues/333611. GroupComponentFile: https://gitlab.com/gitlab-org/gitlab/-/issues/556945.",
        Packages::Debian::DistributionReleaseFileUploader => "This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/issues/333615.",
        Packages::Rpm::RepositoryFileUploader => "RPM registry is an incomplete/unmaintained MVC with no working upload path. Geo replication is not needed. See https://gitlab.com/gitlab-org/gitlab/-/issues/379055#note_3220415029.",
        Packages::BaseMetadataCacheUploader => "This is a abstract class. We won't use it directly, no need to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/work_items/555047.",
        Packages::Npm::MetadataCacheUploader => "This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/issues/408278.",
        Packages::Helm::MetadataCacheUploader => "This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/issues/545919.",
        Packages::Rubygems::SpecFileUploader => "This feature is not yet released. We do want to replicate this.",
        Packages::Nuget::SymbolUploader => 'This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/issues/422929.',
        Packages::Npm::PackageFileUploader => 'Used to force workhorse to pass an upload as a local file to rails. No direct interactions with object storage.',
        Repositories::CommitsUploader => 'Used to force workhorse to pass an upload as a local file to rails. No direct interactions with object storage.',
        VirtualRegistries::Cache::EntryUploader => 'This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/issues/473033',
        Security::VulnerabilityScanning::SbomScanUploader => "Used to store ephemeral security scans. We don't want to replicate these files as they are only short living (usually, less than a couple of minutes)",
        Security::VulnerabilityScanning::SbomScanResultUploader => "Used to store ephemeral security scan results. We don't want to replicate these files because of their short TTL, see https://gitlab.com/gitlab-org/gitlab/-/issues/562694.",
        SupplyChain::AttestationUploader => 'This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/issues/571772.',
        Ai::Catalog::YamlDefinitionUploader => 'This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/work_items/595333.',
        WorkItems::AgentPlanContentUploader => 'This feature is not yet released. Agent plan content is stored in object storage for work items. Geo replication to be evaluated.',
        Cd::ApplicationFlowDefinitionUploader => 'This feature is not yet released. We do want to replicate this, see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/239072.',
        Ci::Catalog::BundledResources::ComponentUploader => "This feature is not yet released and is currently scoped to GitLab.com Cells. Bundled components are a regenerable cache compiled from catalog component sources that Geo already replicates, though a promoted secondary would need to recompile them. Geo replication to be evaluated, see https://gitlab.com/gitlab-org/gitlab/-/issues/600454."
      }.key?(uploader)
    end
    # rubocop:enable Layout/LineLength

    def uploads?(uploader)
      upload_name = uploader.name.delete_suffix('Uploader').underscore
      Gitlab::Geo::Replication.object_type_from_user_uploads?(upload_name)
    end

    def data_types
      @data_types ||= uploaders.map { |uploader| data_type_for(uploader) }
    end

    def data_type_for(uploader)
      object_type = uploader.name.delete_suffix('Uploader').underscore.tr('/', '_')

      unmatched_data_types = {
        'ci_pipeline_artifact' => 'pipeline_artifact',
        'external_diff' => 'merge_request_diff',
        'packages_package_file' => 'package_file',
        'terraform_state' => 'terraform_state_version'
      }

      unmatched_data_types.fetch(object_type, object_type)
    end
  end
end
