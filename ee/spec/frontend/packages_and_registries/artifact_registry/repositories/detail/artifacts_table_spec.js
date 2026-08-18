import { RouterLinkStub } from '@vue/test-utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ArtifactsTable from 'ee/packages_and_registries/artifact_registry/repositories/detail/artifacts_table.vue';
import {
  mockImagePage,
  mockMavenPackagePage,
  mockNpmPackagePage,
  mockRepository,
} from '../../mock_data';

describe('ArtifactRegistryArtifactsTable', () => {
  let wrapper;

  const findHeaders = () => wrapper.findAll('th').wrappers.map((th) => th.text());
  const findNameCells = () =>
    wrapper.findAllByTestId('artifact-name').wrappers.map((c) => c.text());
  const findVersionsCells = () =>
    wrapper.findAllByTestId('artifact-versions').wrappers.map((c) => c.text());
  const findNameRoutes = () =>
    wrapper.findAllComponents(RouterLinkStub).wrappers.map((link) => link.props('to'));

  const createComponent = ({
    format = 'MAVEN',
    artifacts = mockMavenPackagePage.nodes,
    name = mockRepository.name,
  } = {}) => {
    wrapper = mountExtended(ArtifactsTable, {
      propsData: { format, artifacts, name },
      stubs: { RouterLink: RouterLinkStub },
    });
  };

  describe('the columns a format calls for', () => {
    it.each([
      ['DOCKER', ['Image'], mockImagePage.nodes],
      ['OCI', ['Image'], mockImagePage.nodes],
      ['MAVEN', ['Package'], mockMavenPackagePage.nodes],
      ['NPM', ['Package', 'Versions'], mockNpmPackagePage.nodes],
    ])('gives a %s repository exactly %j', (format, headers, artifacts) => {
      createComponent({ format, artifacts });

      expect(findHeaders()).toEqual(headers);
    });
  });

  describe('how a row is named', () => {
    it('names a container image outright', () => {
      createComponent({ format: 'DOCKER', artifacts: mockImagePage.nodes });

      expect(findNameCells()).toEqual(['payment-service', 'api-gateway']);
    });

    it('joins Maven coordinates with a colon', () => {
      createComponent({ format: 'MAVEN', artifacts: mockMavenPackagePage.nodes });

      expect(findNameCells()).toEqual(['com.company.payment:core']);
    });

    it('puts a scoped npm package behind its scope and leaves an unscoped one bare', () => {
      createComponent({ format: 'NPM', artifacts: mockNpmPackagePage.nodes });

      expect(findNameCells()).toEqual(['@company/payment-core', 'design-tokens']);
    });
  });

  describe('for an npm repository', () => {
    beforeEach(() => {
      createComponent({ format: 'NPM', artifacts: mockNpmPackagePage.nodes });
    });

    it('renders the version count, which npm alone reports', () => {
      expect(findVersionsCells()).toEqual(['5', '12']);
    });
  });

  describe('where a row leads', () => {
    it.each([
      ['DOCKER', mockImagePage.nodes],
      ['OCI', mockImagePage.nodes],
      ['MAVEN', mockMavenPackagePage.nodes],
      ['NPM', mockNpmPackagePage.nodes],
    ])('links every %s row to that artifact version list', (format, artifacts) => {
      createComponent({ format, artifacts, name: 'a-repository' });

      expect(findNameRoutes()).toEqual(
        artifacts.map(({ id }) => ({
          name: 'artifact_versions',
          params: { id: 'a-repository', artifactId: id },
        })),
      );
    });

    it('addresses the artifact by id, never by the name the row renders', () => {
      createComponent({ format: 'MAVEN', artifacts: mockMavenPackagePage.nodes });

      expect(findNameCells()).toEqual(['com.company.payment:core']);
      expect(findNameRoutes()[0].params.artifactId).toBe(mockMavenPackagePage.nodes[0].id);
    });
  });

  it('renders no columns for an unknown format', () => {
    createComponent({ format: 'CONDA', artifacts: [] });

    expect(findHeaders()).toEqual([]);
  });
});
