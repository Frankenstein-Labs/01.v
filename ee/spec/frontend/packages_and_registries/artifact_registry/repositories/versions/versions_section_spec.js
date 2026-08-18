import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VersionsSection from 'ee/packages_and_registries/artifact_registry/repositories/versions/versions_section.vue';
import VersionsTable from 'ee/packages_and_registries/artifact_registry/repositories/versions/versions_table.vue';
import { mockVersions } from '../../mock_data';

describe('ArtifactRegistryVersionsSection', () => {
  let wrapper;

  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findTable = () => wrapper.findComponent(VersionsTable);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(VersionsSection, { propsData: props });
  };

  describe('while the read is in flight', () => {
    beforeEach(() => createComponent({ loading: true }));

    it('renders a loading affordance', () => {
      expect(findSkeleton().exists()).toBe(true);
    });

    it('renders no table, so an in-flight read is not mistaken for a version-less package', () => {
      expect(findTable().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when the read failed', () => {
    beforeEach(() => createComponent({ hasError: true }));

    it('reports the failure in this region', () => {
      expect(wrapper.findByTestId('versions-error').text()).toBe(
        'The Artifact Registry service is unavailable.',
      );
    });

    it('renders no table and no skeleton', () => {
      expect(findTable().exists()).toBe(false);
      expect(findSkeleton().exists()).toBe(false);
    });

    it('reports the failure ahead of an empty page, which it cannot vouch for', () => {
      createComponent({ hasError: true, versions: [] });

      expect(findAlert().exists()).toBe(true);
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('when the package has versions', () => {
    beforeEach(() => createComponent({ versions: mockVersions }));

    it('renders them in the table', () => {
      expect(findTable().props('versions')).toBe(mockVersions);
    });

    it('renders no skeleton and no alert', () => {
      expect(findSkeleton().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });
  });
});
