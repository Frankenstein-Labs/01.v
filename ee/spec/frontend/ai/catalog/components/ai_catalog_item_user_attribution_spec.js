import { GlAvatarLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemUserAttribution from 'ee/ai/catalog/components/ai_catalog_item_user_attribution.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { VERSION_PINNED, VERSION_LATEST } from 'ee/ai/catalog/constants';
import {
  mockAgent,
  mockAgentPinnedVersion,
  mockCreatedByUser,
  mockModifiedByUser,
} from '../mock_data';

describe('AiCatalogItemUserAttribution', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemUserAttribution, {
      propsData: {
        item: mockAgent,
        versionKey: VERSION_LATEST,
        ...props,
      },
      stubs: {
        GlAvatarLink,
        GlSprintf,
        TimeAgoTooltip,
      },
    });
  };

  const findCreatedByItem = () => wrapper.findByTestId('metadata-created-by');
  const findModifiedByItem = () => wrapper.findByTestId('metadata-modified-by');
  const findUserLink = () => wrapper.findByTestId('user-link');

  describe('when item is on version 1.0.0 (first version)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows "Created" attribution, not "Updated"', () => {
      expect(findCreatedByItem().exists()).toBe(true);
      expect(findModifiedByItem().exists()).toBe(false);
    });

    it('displays the author name with "Created" and "by" in a single string', () => {
      const text = findCreatedByItem().text();
      expect(text).toContain('Created');
      expect(text).toContain('by');
      expect(text).toContain(mockCreatedByUser.name);
    });

    it('links to the author profile with correct user metadata', () => {
      const link = findUserLink();
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(mockCreatedByUser.webUrl);
      expect(link.attributes('data-username')).toBe(mockCreatedByUser.username);
      expect(link.attributes('data-user-id')).toBe('1');
      expect(link.text()).toContain(mockCreatedByUser.name);
    });

    describe('when createdBy is null', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockAgent,
            latestVersion: {
              ...mockAgent.latestVersion,
              createdBy: null,
            },
          },
        });
      });

      it('displays "Unknown" instead of a user link', () => {
        expect(findCreatedByItem().text()).toContain('Unknown');
        expect(findUserLink().exists()).toBe(false);
      });
    });

    describe('when item is GitLab-maintained', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockAgent,
            verificationLevel: 'GITLAB_MAINTAINED',
          },
        });
      });

      it('displays "GitLab" instead of a user link', () => {
        expect(findCreatedByItem().text()).toContain('GitLab');
        expect(findUserLink().exists()).toBe(false);
      });
    });

    it('displays "GitLab" for GitLab-maintained items even when createdBy is null', () => {
      createComponent({
        item: {
          ...mockAgent,
          verificationLevel: 'GITLAB_MAINTAINED',
          latestVersion: {
            ...mockAgent.latestVersion,
            createdBy: null,
          },
        },
      });

      expect(findCreatedByItem().text()).toContain('GitLab');
      expect(findUserLink().exists()).toBe(false);
    });
  });

  describe('when item has been updated beyond version 1.0.0', () => {
    const mockUpdatedAgent = {
      ...mockAgent,
      latestVersion: {
        ...mockAgent.latestVersion,
        versionName: '2.0.0',
        humanVersionName: 'v2.0.0',
        createdBy: mockModifiedByUser,
        createdAt: '2025-09-01T10:00:00Z',
      },
    };

    describe('when viewing the latest version', () => {
      beforeEach(() => {
        createComponent({
          versionKey: VERSION_LATEST,
          item: mockUpdatedAgent,
        });
      });

      it('shows "Updated" attribution, not "Created"', () => {
        expect(findModifiedByItem().exists()).toBe(true);
        expect(findCreatedByItem().exists()).toBe(false);
      });

      it('displays the updated author name with "Updated" and "by" in a single string', () => {
        const text = findModifiedByItem().text();
        expect(text).toContain('Updated');
        expect(text).toContain('by');
        expect(text).toContain(mockModifiedByUser.name);
      });

      it('links to the updated author profile with correct user metadata', () => {
        const link = findUserLink();
        expect(link.attributes('href')).toBe(mockModifiedByUser.webUrl);
        expect(link.attributes('data-username')).toBe(mockModifiedByUser.username);
        expect(link.attributes('data-user-id')).toBe('2');
      });
    });

    describe('when viewing a pinned version', () => {
      it('displays "Updated" with the pinned version author', () => {
        createComponent({
          versionKey: VERSION_PINNED,
          item: {
            ...mockUpdatedAgent,
            configurationForProject: {
              pinnedItemVersion: {
                ...mockAgentPinnedVersion,
                createdBy: mockCreatedByUser,
              },
            },
          },
        });

        const text = findModifiedByItem().text();
        expect(text).toContain('Updated');
        expect(text).toContain(mockCreatedByUser.name);
      });

      it('displays "Unknown" when pinned version createdBy is null', () => {
        createComponent({
          versionKey: VERSION_PINNED,
          item: {
            ...mockUpdatedAgent,
            configurationForProject: {
              pinnedItemVersion: {
                ...mockAgentPinnedVersion,
                createdBy: null,
              },
            },
          },
        });

        const text = findModifiedByItem().text();
        expect(text).toContain('Updated');
        expect(text).toContain('Unknown');
        expect(findUserLink().exists()).toBe(false);
      });
    });
  });

  describe('when createdAt is not defined', () => {
    const findTimeAgoTooltip = () => wrapper.findComponent(TimeAgoTooltip);

    it('omits the timeAgo from the "Created" message', () => {
      createComponent({
        item: {
          ...mockAgent,
          createdAt: undefined,
          latestVersion: {
            ...mockAgent.latestVersion,
            createdAt: undefined,
          },
        },
      });

      const text = findCreatedByItem().text();
      expect(text).toContain('Created by');
      expect(text).toContain(mockCreatedByUser.name);
      expect(findTimeAgoTooltip().exists()).toBe(false);
    });

    it('omits the timeAgo from the "Updated" message', () => {
      createComponent({
        item: {
          ...mockAgent,
          latestVersion: {
            ...mockAgent.latestVersion,
            versionName: '2.0.0',
            humanVersionName: 'v2.0.0',
            createdBy: mockModifiedByUser,
            createdAt: undefined,
          },
        },
      });

      const text = findModifiedByItem().text();
      expect(text).toContain('Updated by');
      expect(text).toContain(mockModifiedByUser.name);
      expect(findTimeAgoTooltip().exists()).toBe(false);
    });
  });

  describe('authorClasses prop', () => {
    it('applies default bold styling to author link', () => {
      createComponent();

      const link = findUserLink();
      expect(link.classes()).toEqual(expect.arrayContaining(['gl-font-bold', 'gl-text-default']));
    });

    it('applies custom classes when authorClasses is provided', () => {
      createComponent({ authorClasses: 'gl-text-subtle' });

      const link = findUserLink();
      expect(link.classes()).toContain('gl-text-subtle');
      expect(link.classes()).not.toEqual(
        expect.arrayContaining(['gl-font-bold', 'gl-text-default']),
      );
    });

    it('applies custom classes to the fallback span when there is no user link', () => {
      createComponent({
        authorClasses: 'gl-text-subtle',
        item: {
          ...mockAgent,
          latestVersion: {
            ...mockAgent.latestVersion,
            createdBy: null,
          },
        },
      });

      const span = findCreatedByItem().find('span span');
      expect(span.classes()).toContain('gl-text-subtle');
    });
  });
});
