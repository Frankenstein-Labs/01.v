import { GlTable } from '@gitlab/ui';
import { merge } from 'lodash-es';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ProjectList from '~/usage_quotas/storage/namespace/components/project_list.vue';
import { storageTypeHelpPaths } from '~/usage_quotas/storage/constants';
import {
  mockGetNamespaceStorageGraphQLResponse,
  projectList,
} from 'jest/usage_quotas/storage/mock_data';
import { defaultNamespaceProvideValues } from '../../mock_data';

/** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
let wrapper;

const createComponent = ({ provide = {}, props = {} } = {}) => {
  wrapper = mountExtended(ProjectList, {
    provide: {
      ...defaultNamespaceProvideValues,
      ...provide,
    },
    propsData: {
      namespace: mockGetNamespaceStorageGraphQLResponse.data.namespace,
      projects: projectList,
      helpLinks: storageTypeHelpPaths,
      isLoading: false,
      sortBy: 'storage',
      ...props,
    },
  });
};

const createProject = (attrs = {}) => {
  return merge(
    {
      id: 'gid://gitlab/Project/150',
      fullPath: 'frontend-fixtures/gitlab',
      nameWithNamespace: 'Sidney Jones132 / GitLab',
      avatarUrl: null,
      webUrl: 'http://localhost/frontend-fixtures/gitlab',
      name: 'GitLab',
      statistics: {
        storageSize: 1691805.0,
        costFactoredStorageSize: 1691805.0,
        repositorySize: 209710.0,
        lfsObjectsSize: 209720.0,
        containerRegistrySize: 0.0,
        buildArtifactsSize: 1272375.0,
        pipelineArtifactsSize: 0.0,
        packagesSize: 0.0,
        wikiSize: 0.0,
        snippetsSize: 0.0,
        __typename: 'ProjectStatistics',
      },
      __typename: 'Project',
    },
    attrs,
  );
};

const findTable = () => wrapper.findComponent(GlTable);

describe('ProjectList', () => {
  describe('Table header', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('rendering a fork', () => {
      it('renders a fork when the storage size and cost factored storage size match', () => {
        const project = createProject({
          statistics: { storageSize: 200, costFactoredStorageSize: 200 },
        });
        createComponent({ props: { projects: [project] } });
        expect(wrapper.text()).toContain('200 B');
      });

      it('renders a fork when the storage size and the cost factored storage size differ', () => {
        const project = createProject({
          statistics: { storageSize: 200, costFactoredStorageSize: 100 },
        });
        createComponent({ props: { projects: [project] } });

        const text = findTable()
          .text()
          .replace(/[\s\n]+/g, ' ');
        expect(text).toContain('100 B (of 200 B)');
      });

      it('renders a link to the cost factors for forks documentation', () => {
        const project = createProject({
          statistics: { storageSize: 200, costFactoredStorageSize: 100 },
        });
        createComponent({ props: { projects: [project] } });

        const linkToDocumentation = wrapper.findByRole('link', {
          href: '/help/user/storage_usage_quotas.html#view-project-fork-storage-usage',
        });

        expect(linkToDocumentation.exists()).toBe(true);
      });
    });
  });
});
