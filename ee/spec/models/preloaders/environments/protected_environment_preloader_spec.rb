# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::Environments::ProtectedEnvironmentPreloader, :aggregate_failures do
  before do
    stub_licensed_features(protected_environments: true)
  end

  describe '#initialize' do
    it 'raises an error if environments belong to more than one project' do
      expect { described_class.new(create_list(:environment, 2)) }
        .to raise_error('This preloader supports only environments in the same project')
    end
  end

  describe '#execute' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be_with_reload(:project) { create(:project, :small_repo, group: subgroup) }
    let_it_be_with_refind(:production) { create(:environment, name: 'production', project: project) }
    let_it_be_with_refind(:staging) { create(:environment, name: 'staging', project: project) }
    let_it_be(:production_operator) { create(:user, developer_of: project) }
    let_it_be(:staging_operator) { create(:user, developer_of: project) }
    let(:association_attributes) { [:deploy_access_levels, :project] }

    subject { described_class.new([production, staging]).execute(association_attributes) }

    shared_examples 'preloads and associates environments' do
      it 'preloads protected environments' do
        subject

        expect { production.protected? }.not_to exceed_query_limit(0)
        expect { staging.protected? }.not_to exceed_query_limit(0).with_threshold(1) # 1 project load is expected

        expect(production.protected?).to be_truthy
        expect(staging.protected?).to be_truthy
      end

      it 'preloads deploy access levels' do
        subject

        expect { production.protected_by?(production_operator) }.not_to exceed_query_limit(0)
        expect { staging.protected_by?(staging_operator) }
          .not_to exceed_query_limit(0)
          .with_threshold(1) # 1 project load is expected
      end

      it 'associates protected environments to the correct environment' do
        subject

        expect(production.protected_by?(production_operator)).to be_truthy
        expect(staging.protected_by?(staging_operator)).to be_truthy
        expect(production.protected_from?(staging_operator)).to be_truthy
        expect(staging.protected_from?(production_operator)).to be_truthy
      end
    end

    context 'with project-level protected environments' do
      before_all do
        create(
          :protected_environment,
          project: project, name: production.name, authorize_user_to_deploy: production_operator
        )
        create(
          :protected_environment,
          project: project, name: staging.name, authorize_user_to_deploy: staging_operator
        )
      end

      include_examples 'preloads and associates environments'
    end

    context 'with group-level protected environments' do
      before_all do
        create(
          :protected_environment, :group_level,
          group: root_group, name: production.name, authorize_user_to_deploy: production_operator
        )
        create(
          :protected_environment, :group_level,
          group: subgroup, name: staging.name, authorize_user_to_deploy: staging_operator
        )
      end

      include_examples 'preloads and associates environments'
    end
  end
end
