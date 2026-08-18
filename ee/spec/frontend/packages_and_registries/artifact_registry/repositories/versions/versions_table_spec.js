import { mountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';
import VersionsTable from 'ee/packages_and_registries/artifact_registry/repositories/versions/versions_table.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { mockVersions } from '../../mock_data';

describe('ArtifactRegistryVersionsTable', () => {
  let wrapper;

  useFakeDate(2026, 6, 15);

  const findHeaders = () => wrapper.findAll('th').wrappers.map((th) => th.text());
  const findVersionCells = () =>
    wrapper.findAllByTestId('version-name').wrappers.map((cell) => cell.text());
  const findPublishedCells = () => wrapper.findAllComponents(TimeAgoTooltip);

  const createComponent = ({ versions = mockVersions } = {}) => {
    wrapper = mountExtended(VersionsTable, { propsData: { versions } });
  };

  it('renders the columns an Artifact Registry version can fill', () => {
    createComponent();

    expect(findHeaders()).toEqual(['Version', 'Published']);
  });

  it('renders the version string of every row, in the order it was given', () => {
    createComponent();

    expect(findVersionCells()).toEqual(['3.2.1', '2.0.0']);
  });

  it('renders the publication date as a relative time', () => {
    createComponent();

    expect(findPublishedCells().wrappers.map((cell) => cell.props('time'))).toEqual([
      '2026-06-10T00:00:00Z',
      '2026-04-02T00:00:00Z',
    ]);
  });

  it('renders the headers with no rows for a version-less package', () => {
    createComponent({ versions: [] });

    expect(findHeaders()).toEqual(['Version', 'Published']);
    expect(findVersionCells()).toEqual([]);
  });
});
