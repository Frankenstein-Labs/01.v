import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ArtifactSourceCard from 'ee/cd/components/artifact_source_card.vue';
import VersionsTable from 'ee/cd/components/versions_table.vue';
import { makeArtifactSource } from './mock_data';

describe('ArtifactSourceCard', () => {
  let wrapper;

  const findTitle = () => wrapper.findByTestId('artifact-source-title');
  const findSourceRef = () => wrapper.findByTestId('artifact-source-ref');
  const findVersionsTable = () => wrapper.findComponent(VersionsTable);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ArtifactSourceCard, {
      propsData: {
        artifactSource: makeArtifactSource(),
        ...props,
      },
    });
  };

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the artifact source title', () => {
      expect(findTitle().text()).toBe('Artifact source');
    });

    it('renders the source ref in monospace', () => {
      expect(findSourceRef().text()).toBe('registry.example.com/api-server');
      expect(findSourceRef().classes()).toContain('gl-font-monospace');
    });

    it('renders the versions table with versions', () => {
      expect(findVersionsTable().exists()).toBe(true);
      expect(findVersionsTable().props('versions')).toHaveLength(1);
    });
  });

  describe('with empty sourceRef', () => {
    beforeEach(() => {
      createComponent({ artifactSource: makeArtifactSource({ sourceRef: '' }) });
    });

    it('does not render the source ref element', () => {
      expect(findSourceRef().exists()).toBe(false);
    });
  });

  describe('with null sourceRef', () => {
    beforeEach(() => {
      createComponent({ artifactSource: makeArtifactSource({ sourceRef: null }) });
    });

    it('does not render the source ref element', () => {
      expect(findSourceRef().exists()).toBe(false);
    });
  });

  describe('with no versions', () => {
    beforeEach(() => {
      createComponent({ artifactSource: makeArtifactSource({ versions: { nodes: [] } }) });
    });

    it('renders the versions table with empty array', () => {
      expect(findVersionsTable().exists()).toBe(true);
      expect(findVersionsTable().props('versions')).toEqual([]);
    });
  });

  describe('with missing versions node', () => {
    beforeEach(() => {
      createComponent({ artifactSource: makeArtifactSource({ versions: undefined }) });
    });

    it('passes empty array when versions is undefined', () => {
      expect(findVersionsTable().props('versions')).toEqual([]);
    });
  });
});
