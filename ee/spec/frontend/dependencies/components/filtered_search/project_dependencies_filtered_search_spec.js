import { shallowMount } from '@vue/test-utils';
import {
  OPERATORS_IS,
  OPERATORS_IS_NOT,
  OPERATORS_OR,
} from '~/vue_shared/components/filtered_search_bar/constants';
import ProjectDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/project_dependencies_filtered_search.vue';
import DependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/dependencies_filtered_search.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import VersionToken from 'ee/dependencies/components/filtered_search/tokens/version_token.vue';
import ActivityToken from 'ee/dependencies/components/filtered_search/tokens/activity_token.vue';
import MalwareToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/malware_token.vue';
import TrackedRefToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/tracked_ref_token.vue';

describe('ProjectDependenciesFilteredSearch', () => {
  let wrapper;

  const defaultBranchContext = {
    id: 'gid://gitlab/Security::ProjectTrackedContext/23',
    name: 'main',
  };

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMount(ProjectDependenciesFilteredSearch, {
      provide: {
        projectFullPath: 'gitlab-org/my-project',
        defaultBranchContext,
        glFeatures: {
          maliciousPackageDetection: true,
          vulnerabilitiesAcrossContexts: true,
          projectDependencyTrackedRef: true,
        },
        ...provide,
      },
    });
  };

  const findDependenciesFilteredSearch = () => wrapper.findComponent(DependenciesFilteredSearch);
  const findTokenTypes = () =>
    findDependenciesFilteredSearch()
      .props('tokens')
      .map((t) => t.type);

  beforeEach(() => {
    createComponent();
  });

  it('sets the filtered search id', () => {
    expect(findDependenciesFilteredSearch().props('filteredSearchId')).toBe(
      'project-level-filtered-search',
    );
  });

  it.each`
    tokenTitle       | tokenConfig
    ${'Component'}   | ${{ title: 'Component', type: 'component_names', multiSelect: true, token: ComponentToken, operators: OPERATORS_IS }}
    ${'Version'}     | ${{ title: 'Version', type: 'component_versions', multiSelect: true, token: VersionToken, operators: OPERATORS_IS_NOT }}
    ${'Activity'}    | ${{ title: 'Activity', type: 'component_activity', multiSelect: false, token: ActivityToken, operators: OPERATORS_IS }}
    ${'Malware'}     | ${{ title: 'Malware', type: 'malware', multiSelect: false, token: MalwareToken, operators: OPERATORS_IS }}
    ${'Tracked ref'} | ${{ title: 'Tracked ref', type: 'trackedRefIds', multiSelect: true, token: TrackedRefToken, operators: OPERATORS_OR }}
  `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
    expect(findDependenciesFilteredSearch().props('tokens')).toMatchObject(
      expect.arrayContaining([
        expect.objectContaining({
          ...tokenConfig,
        }),
      ]),
    );
  });

  describe('tracked ref token', () => {
    const findInitialValue = () => findDependenciesFilteredSearch().props('value');

    it('is shown and pre-selects the default branch by default', () => {
      expect(findTokenTypes()).toContain('trackedRefIds');
      expect(findInitialValue()).toEqual([
        {
          type: 'trackedRefIds',
          value: {
            data: [defaultBranchContext],
            operator: OPERATORS_OR[0].value,
          },
        },
      ]);
    });

    it.each`
      scenario                          | provide
      ${'projectFullPath is missing'}   | ${{ projectFullPath: '' }}
      ${'defaultBranchContext is null'} | ${{ defaultBranchContext: null }}
    `('is not shown and pre-selects nothing when $scenario', ({ provide }) => {
      createComponent({ provide });

      expect(findTokenTypes()).not.toContain('trackedRefIds');
      expect(findInitialValue()).toEqual([]);
    });
  });

  it('does not include the malware token when maliciousPackageDetection feature flag is disabled', () => {
    createComponent({
      provide: {
        glFeatures: {
          maliciousPackageDetection: false,
          vulnerabilitiesAcrossContexts: true,
          projectDependencyTrackedRef: true,
        },
      },
    });

    const tokenTypes = findTokenTypes();

    expect(tokenTypes).not.toContain('malware');
    expect(tokenTypes).toMatchObject([
      'component_names',
      'component_versions',
      'component_activity',
      'trackedRefIds',
    ]);
  });

  it('does not include the tracked ref token when vulnerabilitiesAcrossContexts and projectDependencyTrackedRef feature flags are disabled', () => {
    createComponent({
      provide: {
        projectFullPath: 'gitlab-org/my-project',
        glFeatures: {
          vulnerabilitiesAcrossContexts: false,
          projectDependencyTrackedRef: false,
        },
      },
    });

    const tokenTypes = findTokenTypes();

    expect(tokenTypes).not.toContain('trackedRefIds');
    expect(tokenTypes).toMatchObject([
      'component_names',
      'component_versions',
      'component_activity',
    ]);
  });
});
