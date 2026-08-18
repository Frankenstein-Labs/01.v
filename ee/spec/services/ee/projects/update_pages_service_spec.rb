# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdatePagesService, feature_category: :pages do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:path_prefix) { nil }
  let(:expire_in) { nil }
  let(:system_default_expiry) { 86400 }
  let(:build_options) { { pages: { path_prefix: path_prefix, expire_in: expire_in } } }
  let(:build) { create(:ci_build, :pages, project: project, user: user, options: build_options) }
  let(:multiple_versions_enabled) { true }

  subject(:service) { described_class.new(project, build) }

  before_all do
    project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
  end

  before do
    stub_application_setting(pages_extra_deployments_default_expiry_seconds: system_default_expiry)
    stub_pages_setting(enabled: true)
    allow(::Gitlab::Pages)
      .to receive(:multiple_versions_enabled_for?)
        .with(build.project)
        .and_return(multiple_versions_enabled)
  end

  describe 'expiry' do
    # Specify a fixed date as now, because we want to reference it in the examples
    # and freeze_time does not apply during spec setup
    now = Time.utc(2024, 8, 29, 13, 20, 0)

    before do
      travel_to now
    end

    where(:path_prefix, :system_default_expiry, :expire_in, :result) do
      '/path_prefix/' | 3600 | '1 week' | (now + 1.week) # use the value from ci over the default
      '/path_prefix/' | 3600 | 'never'  | nil            # a value of 'never' prevents the deployment from expiring
      '/path_prefix/' | 3600 | nil      | (now + 1.hour) # fall back to the system setting
      '/path_prefix/' | 0    | nil      | nil            # System setting can also be set to 0 (no expiry)
      '/path_prefix/' | 0    | '1 week' | (now + 1.week) # but make sure to still use the value from ci
      ''              | 3600 | '1 week' | (now + 1.week) # main deployments can also be set to expire
      ''              | 3600 | nil      | nil            # but they should not do so by default
    end

    with_them do
      it "sets the expiry date to the expected value" do
        expect { expect(service.execute).to include(status: :success) }
          .to change { project.pages_deployments.count }.by(1)

        expect(project.pages_deployments.last.expires_at).to eq(result)
      end
    end
  end

  context 'when path_prefix is not blank' do
    let(:path_prefix) { '/path_prefix/' }

    context 'and pages_multiple_versions is disabled for project' do
      let(:multiple_versions_enabled) { false }

      it 'does not create a new pages_deployment' do
        expect { expect(service.execute).to include(status: :error) }
          .not_to change { project.pages_deployments.count }
      end

      it_behaves_like 'internal event not tracked' do
        let(:event) { 'create_pages_extra_deployment' }

        subject(:track_event) { service.execute }
      end
    end

    context 'and pages_multiple_versions is enabled for project' do
      let(:multiple_versions_enabled) { true }

      before do
        stub_application_setting(pages_extra_deployments_default_expiry_seconds: 3600)
      end

      it 'saves the slugiffied version of the path prefix' do
        expect { expect(service.execute).to include(status: :success) }
          .to change { project.pages_deployments.count }.by(1)

        expect(project.pages_deployments.last.path_prefix).to eq('path-prefix')
      end

      it 'sets the expiry date to the default setting', :freeze_time do
        expect { expect(service.execute).to include(status: :success) }
          .to change { project.pages_deployments.count }.by(1)

        expect(project.pages_deployments.last.expires_at).to eq(1.hour.from_now)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'create_pages_extra_deployment' }
        let(:category) { 'Projects::UpdatePagesService' }
        let(:namespace) { project.namespace }

        subject(:track_event) { service.execute }
      end
    end
  end
end
