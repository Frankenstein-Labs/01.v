import { shallowMount } from '@vue/test-utils';
import {
  OPERATORS_IS,
  OPERATORS_IS_NOT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import GroupDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue';
import DependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/dependencies_filtered_search.vue';
import LicenseToken from 'ee/dependencies/components/filtered_search/tokens/license_token.vue';
import ProjectToken from 'ee/dependencies/components/filtered_search/tokens/project_token.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import VersionToken from 'ee/dependencies/components/filtered_search/tokens/version_token.vue';
import MalwareToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/malware_token.vue';

describe('GroupDependenciesFilteredSearch', () => {
  let wrapper;

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMount(GroupDependenciesFilteredSearch, {
      provide: {
        glFeatures: {
          maliciousPackageDetection: true,
        },
        ...provide,
      },
    });
  };

  const findDependenciesFilteredSearch = () => wrapper.findComponent(DependenciesFilteredSearch);

  beforeEach(createComponent);

  it('sets the filtered search id', () => {
    expect(findDependenciesFilteredSearch().props('filteredSearchId')).toEqual(
      'group-level-filtered-search',
    );
  });

  it.each`
    tokenTitle     | tokenConfig
    ${'License'}   | ${{ title: 'License', type: 'licenses', multiSelect: true, token: LicenseToken, operators: OPERATORS_IS }}
    ${'Project'}   | ${{ title: 'Project', type: 'project_ids', multiSelect: true, token: ProjectToken, operators: OPERATORS_IS }}
    ${'Component'} | ${{ title: 'Component', type: 'component_names', multiSelect: true, token: ComponentToken, operators: OPERATORS_IS }}
    ${'Version'}   | ${{ title: 'Version', type: 'component_versions', multiSelect: true, token: VersionToken, operators: OPERATORS_IS_NOT }}
    ${'Malware'}   | ${{ title: 'Malware', type: 'malware', multiSelect: false, token: MalwareToken, operators: OPERATORS_IS }}
  `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
    expect(findDependenciesFilteredSearch().props('tokens')).toMatchObject(
      expect.arrayContaining([
        expect.objectContaining({
          ...tokenConfig,
        }),
      ]),
    );
  });

  it('does not include the malware token when maliciousPackageDetection feature flag is disabled', () => {
    createComponent({ provide: { glFeatures: { maliciousPackageDetection: false } } });

    const tokenTypes = findDependenciesFilteredSearch()
      .props('tokens')
      .map((t) => t.type);

    expect(tokenTypes).toMatchObject([
      'licenses',
      'project_ids',
      'component_names',
      'component_versions',
    ]);
  });
});
