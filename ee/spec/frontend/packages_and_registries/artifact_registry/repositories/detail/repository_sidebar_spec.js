import { GlAvatar, GlAvatarLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RepositorySidebar from 'ee/packages_and_registries/artifact_registry/repositories/detail/repository_sidebar.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { mockDetailRepository, mockUser } from '../../mock_data';

describe('ArtifactRegistryRepositorySidebar', () => {
  let wrapper;

  const findStat = (name) => wrapper.findByTestId(`repository-stat-${name}`);
  const findCreated = () => wrapper.findByTestId('repository-created');
  const findLastUpdated = () => wrapper.findByTestId('repository-last-updated');

  const findStats = () => wrapper.findByTestId('repository-stats');

  const createComponent = ({ format = 'MAVEN', overrides = {}, hideStats = false } = {}) => {
    wrapper = mountExtended(RepositorySidebar, {
      propsData: { repository: mockDetailRepository(format, overrides), hideStats },
    });
  };

  describe('the counters', () => {
    beforeEach(() => {
      createComponent({
        overrides: { sizeBytes: '597688320', downloadsCount: '6910', artifactsCount: '5' },
      });
    });

    it('renders the size as a human-readable quantity, not a byte count', () => {
      expect(findStat('size').text()).toMatchInterpolatedText('570.00 MiB Size');
    });

    it('groups the download count, which reaches five and six figures', () => {
      expect(findStat('downloads').text()).toMatchInterpolatedText('6,910 Downloads');
    });

    it('renders the artifact count', () => {
      expect(findStat('artifacts').text()).toMatchInterpolatedText('5 Packages');
    });
  });

  describe.each([
    ['MAVEN', 'Packages'],
    ['NPM', 'Packages'],
    ['DOCKER', 'Images'],
    ['OCI', 'Images'],
  ])('for a %s repository', (format, expectedLabel) => {
    it(`names the artifact counter ${expectedLabel}`, () => {
      createComponent({ format, overrides: { artifactsCount: '5' } });

      expect(findStat('artifacts').text()).toContain(expectedLabel);
    });
  });

  describe('when a counter is one', () => {
    it.each([
      ['MAVEN', '1 Package'],
      ['DOCKER', '1 Image'],
    ])('names the %s artifact counter in the singular', (format, expected) => {
      createComponent({ format, overrides: { artifactsCount: '1' } });

      expect(findStat('artifacts').text()).toMatchInterpolatedText(expected);
    });

    it('names the download counter in the singular', () => {
      createComponent({ overrides: { downloadsCount: '1' } });

      expect(findStat('downloads').text()).toMatchInterpolatedText('1 Download');
    });
  });

  describe('when the counters are absent', () => {
    beforeEach(() => {
      createComponent({
        overrides: { sizeBytes: null, downloadsCount: null, artifactsCount: null },
      });
    });

    it('renders each one as zero, which English names in the plural', () => {
      expect(findStat('size').text()).toMatchInterpolatedText('0 B Size');
      expect(findStat('downloads').text()).toMatchInterpolatedText('0 Downloads');
      expect(findStat('artifacts').text()).toMatchInterpolatedText('0 Packages');
    });
  });

  describe('created on', () => {
    beforeEach(() => {
      createComponent({ overrides: { createdAt: '2026-05-12T09:24:00Z' } });
    });

    it('names the section', () => {
      expect(findCreated().text()).toContain('Created on');
    });

    it('names it with an h2, so the heading order does not skip a level', () => {
      expect(findCreated().find('h2').text()).toBe('Created on');
    });

    it('renders the date, so the reader is not left working it out from an interval', () => {
      expect(findCreated().text()).toContain('May 12, 2026');
    });

    it('reads as one sentence, attributing the date to the user the join resolved', () => {
      expect(findCreated().text()).toMatchInterpolatedText(
        `Created on May 12, 2026 by ${mockUser.name}`,
      );
    });

    it('links the avatar and the name to that user', () => {
      const link = findCreated().findComponent(GlAvatarLink);

      expect(link.attributes('href')).toBe(mockUser.webPath);
      expect(link.findComponent(GlAvatar).props('src')).toBe(mockUser.avatarUrl);
    });

    it('marks the avatar decorative, since the link already names the user', () => {
      expect(findCreated().findComponent(GlAvatar).props('alt')).toBe('');
    });
  });

  describe('last updated', () => {
    beforeEach(() => {
      createComponent({ overrides: { lastUpdatedAt: '2026-06-01T00:00:00Z' } });
    });

    it('names the section', () => {
      expect(findLastUpdated().text()).toContain('Last updated');
    });

    it('renders the interval since the content last changed', () => {
      expect(findLastUpdated().findComponent(TimeAgoTooltip).props('time')).toBe(
        '2026-06-01T00:00:00Z',
      );
    });

    it('attributes it to the user the join resolved', () => {
      expect(findLastUpdated().findComponent(GlAvatarLink).text()).toContain(mockUser.name);
    });
  });

  describe('when the repository has never been updated', () => {
    beforeEach(() => {
      createComponent({ overrides: { lastUpdatedAt: null } });
    });

    it('renders no last-updated section rather than an empty one', () => {
      expect(findLastUpdated().exists()).toBe(false);
    });

    it('keeps rendering created on, which happened regardless', () => {
      expect(findCreated().exists()).toBe(true);
    });
  });

  describe('when neither user resolves', () => {
    beforeEach(() => {
      createComponent({ overrides: { createdBy: null, updatedBy: null } });
    });

    it('renders the created-on date without attribution', () => {
      expect(findCreated().text()).toMatchInterpolatedText('Created on May 12, 2026');
    });

    it('keeps rendering the last-updated interval', () => {
      expect(findLastUpdated().findComponent(TimeAgoTooltip).exists()).toBe(true);
      expect(findLastUpdated().text()).not.toContain('by');
    });

    it('renders no avatar, which would otherwise stand for nobody', () => {
      expect(wrapper.findComponent(GlAvatar).exists()).toBe(false);
      expect(wrapper.findComponent(GlAvatarLink).exists()).toBe(false);
    });
  });

  describe('when the stats are hidden', () => {
    beforeEach(() => {
      createComponent({ hideStats: true });
    });

    it('drops the counters', () => {
      expect(findStats().exists()).toBe(false);
      expect(findStat('size').exists()).toBe(false);
      expect(findStat('downloads').exists()).toBe(false);
      expect(findStat('artifacts').exists()).toBe(false);
    });

    it('keeps the timestamps, which are true of an empty repository too', () => {
      expect(findCreated().exists()).toBe(true);
      expect(findLastUpdated().exists()).toBe(true);
    });
  });

  it('renders the counters unless told to hide them', () => {
    createComponent();

    expect(findStats().exists()).toBe(true);
  });
});
