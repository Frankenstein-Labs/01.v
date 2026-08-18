import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlIcon, GlBadge } from '@gitlab/ui';
import { RouterLinkStub as RouterLink } from '@vue/test-utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';
import AiCatalogItemUserAttribution from 'ee/ai/catalog/components/ai_catalog_item_user_attribution.vue';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import { normalizeCustomOrFoundationalItem } from 'ee/ai/catalog/utils';
import {
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';
import {
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  TYPENAME_AI_FOUNDATIONAL_CHAT_AGENT,
  VERIFICATION_LEVEL_GITLAB_MAINTAINED,
  TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_ITEM_TYPES,
  TRACK_EVENT_ORIGIN_PROJECT,
  TRACK_EVENT_PAGE_LIST,
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';
import { mockBaseVersion, mockProjectWithGroup } from '../mock_data';

describe('AiCatalogListItem', () => {
  let wrapper;

  const mockId = 1;

  const mockItem = {
    id: `gid://gitlab/Ai::Catalog::Item/${mockId}`,
    createdAt: '2025-08-19T16:45:00Z',
    name: 'Test AI Agent',
    itemType: 'AGENT',
    description: 'A helpful AI assistant for testing purposes',
    visibility: VISIBILITY_LEVEL_PRIVATE,
    updatedAt: '2025-08-19T16:45:00Z',
    project: mockProjectWithGroup,
    latestVersion: { ...mockBaseVersion, updatedAt: '2025-08-19T16:45:00Z' },
    userPermissions: {
      readAiCatalogItem: true,
      adminAiCatalogItem: true,
    },
    starCount: 0,
    starred: false,
    last30DayUsageCount: 0,
  };

  const mockRouter = {
    resolve: jest.fn().mockReturnValue({ href: `/agent/${mockId}` }),
    push: jest.fn(),
  };

  const publicTooltip = 'Public Item';
  const restrictedTooltip = 'Restricted Item';
  const privateTooltip = 'Private Item';

  const defaultItemTypeConfig = {
    actionItems: (itemId) => [
      {
        text: 'Edit',
        to: {
          name: AI_CATALOG_AGENTS_EDIT_ROUTE,
          params: { id: itemId },
        },
        icon: 'pencil',
      },
    ],
    disableActionItem: {
      showActionItem: () => true,
    },
    showRoute: '/items/:id',
    visibilityTooltip: {
      [VISIBILITY_LEVEL_PUBLIC]: publicTooltip,
      [VISIBILITY_LEVEL_RESTRICTED]: restrictedTooltip,
      [VISIBILITY_LEVEL_PRIVATE]: privateTooltip,
    },
    showStatusBadge: true,
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const defaultProvide = {
    isGlobalNamespace: false,
    isProjectNamespace: false,
    isGroupNamespace: false,
  };

  const createComponent = ({
    item = mockItem,
    itemTypeConfig = defaultItemTypeConfig,
    provide = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(AiCatalogListItem, {
      propsData: {
        item,
        itemTypeConfig,
      },
      provide: { ...defaultProvide, ...provide },
      mocks: {
        $route: {
          path: '/agents/:id',
        },
        $router: mockRouter,
      },
      stubs: {
        RouterLink,
      },
    });
  };

  const findStarCountDisplay = () => wrapper.findByTestId('star-count-display');
  const findUsageCountDisplay = () => wrapper.findByTestId('usage-count-display');
  const findSourceProjectTooltip = () => wrapper.findByTestId('ai-catalog-item-source-project');
  const findSourceProjectIcon = () => findSourceProjectTooltip().findComponent(GlIcon);
  const findSourceProjectText = () => findSourceProjectTooltip().find('span.gl-truncate');
  const findVisibilityTooltip = () => wrapper.findByTestId('ai-catalog-item-visibility');
  const findExternalLabel = () => wrapper.findByTestId('ai-catalog-item-external');
  const findListItemLink = () => wrapper.findComponent(RouterLink);
  const findVisibilityIcon = () => findVisibilityTooltip().findComponent(GlIcon);
  const findDisclosureDropdown = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findGitLabMaintainedIcon = () => wrapper.findComponent(FoundationalIcon);
  const findUserAttribution = () => wrapper.findComponent(AiCatalogItemUserAttribution);
  const findUpdateAvailableLabel = () => wrapper.findByTestId('ai-catalog-item-update');
  const findUpdateUnlistedBadge = () => wrapper.findByTestId('ai-catalog-item-unlisted');
  const findStatusBadge = () => wrapper.findByTestId('ai-catalog-item-status-badge');

  describe('user attribution', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the user attribution component with correct props', () => {
      const attribution = findUserAttribution();
      expect(attribution.exists()).toBe(true);
      expect(attribution.props('item')).toBe(mockItem);
      expect(attribution.props('versionKey')).toBe('latestVersion');
    });
  });

  describe('star count display', () => {
    it('renders the static star count with the correct count from item data', () => {
      createComponent({ item: { ...mockItem, starCount: 5 } });

      expect(findStarCountDisplay().exists()).toBe(true);
      expect(findStarCountDisplay().text()).toContain('5');
    });

    it('renders an empty star icon when the user has not starred the item', () => {
      createComponent({ item: { ...mockItem, starCount: 5, starred: false } });

      expect(findStarCountDisplay().findComponent(GlIcon).props('name')).toBe('star-o');
    });

    it('renders a filled star icon when the user has starred the item', () => {
      createComponent({ item: { ...mockItem, starCount: 5, starred: true } });

      expect(findStarCountDisplay().findComponent(GlIcon).props('name')).toBe('star');
    });

    it('has an accessible aria-label with the star count', () => {
      createComponent({ item: { ...mockItem, starCount: 1 } });

      expect(findStarCountDisplay().attributes('aria-label')).toBe('1 star');
    });

    it('uses the plural form of the aria-label when count is not 1', () => {
      createComponent({ item: { ...mockItem, starCount: 5 } });

      expect(findStarCountDisplay().attributes('aria-label')).toBe('5 stars');
    });
  });

  describe('usage count display', () => {
    it('renders the usage count display when last30DayUsageCount is set', () => {
      createComponent({ item: { ...mockItem, last30DayUsageCount: 42 } });

      expect(findUsageCountDisplay().exists()).toBe(true);
      expect(findUsageCountDisplay().text()).toContain('42');
    });

    it('renders a chart icon inside the usage count display', () => {
      createComponent({ item: { ...mockItem, last30DayUsageCount: 42 } });

      expect(findUsageCountDisplay().findComponent(GlIcon).props('name')).toBe('chart');
    });

    it('renders the correct count value', () => {
      createComponent({ item: { ...mockItem, last30DayUsageCount: 7 } });

      expect(findUsageCountDisplay().text()).toContain('7');
    });

    it('has the correct tooltip text', () => {
      createComponent({ item: { ...mockItem, last30DayUsageCount: 42 } });

      expect(findUsageCountDisplay().attributes('title')).toBe(
        'The number of projects that have used this item in the last 30 days.',
      );
    });

    it('has the correct aria-label for singular count', () => {
      createComponent({ item: { ...mockItem, last30DayUsageCount: 1 } });

      expect(findUsageCountDisplay().attributes('aria-label')).toBe('1 project');
    });

    it('has the correct aria-label for plural count', () => {
      createComponent({ item: { ...mockItem, last30DayUsageCount: 42 } });

      expect(findUsageCountDisplay().attributes('aria-label')).toBe('42 projects');
    });
  });

  describe('component rendering', () => {
    it('renders the list item with the correct link URL', () => {
      createComponent();

      const listItemLink = findListItemLink();

      expect(listItemLink.exists()).toBe(true);
      expect(listItemLink.props('to')).toEqual({
        name: AI_CATALOG_AGENTS_SHOW_ROUTE,
        params: { id: 1 },
      });
    });

    it('renders the actions passed in a prop in a disclosure dropdown', () => {
      createComponent();

      const items = findDisclosureDropdownItems();

      expect(findDisclosureDropdown().exists()).toBe(true);
      expect(items).toHaveLength(2);
      expect(items.at(0).text()).toBe('Edit');
      expect(items.at(1).text()).toBe('Disable');
    });

    it('renders disable action text when passed', () => {
      createComponent({
        itemTypeConfig: {
          ...defaultItemTypeConfig,
          disableActionItem: {
            ...defaultItemTypeConfig.disableActionItem,
            text: 'Disable',
          },
        },
      });
      const items = findDisclosureDropdownItems();

      expect(items.at(1).text()).toBe('Disable');
    });

    describe('when the action items are empty but the user has permission to admin the item', () => {
      beforeEach(() => {
        createComponent({
          itemTypeConfig: { ...defaultItemTypeConfig, actionItems: () => [] },
        });
      });

      it('does render the the disclosure dropdown with the disable action', () => {
        const items = findDisclosureDropdownItems();

        expect(items).toHaveLength(1);
        expect(items.at(0).text()).toBe('Disable');
      });
    });

    describe('when the action items are empty and the user does not have permission to admin the item', () => {
      beforeEach(() => {
        createComponent({
          itemTypeConfig: {
            ...defaultItemTypeConfig,
            actionItems: () => [],
            disableActionItem: {
              showActionItem: () => false,
            },
          },
        });
      });

      it('does not render the the disclosure dropdown', () => {
        expect(findDisclosureDropdown().exists()).toBe(false);
      });
    });

    describe('when aiCatalogInternalVisibility is enabled', () => {
      const internalVisibilityProvide = { glFeatures: { aiCatalogInternalVisibility: true } };

      describe('when the item is private', () => {
        beforeEach(() => {
          createComponent({
            item: { ...mockItem, visibility: VISIBILITY_LEVEL_PRIVATE },
            provide: internalVisibilityProvide,
          });
        });

        it('renders the private icon with a tooltip', () => {
          expect(findVisibilityIcon().props('name')).toBe(
            VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE],
          );
        });

        it('renders the private tooltip', () => {
          expect(findVisibilityTooltip().attributes('title')).toBe(privateTooltip);
        });
      });

      describe('when the item is restricted', () => {
        beforeEach(() => {
          createComponent({
            item: { ...mockItem, visibility: VISIBILITY_LEVEL_RESTRICTED },
            provide: internalVisibilityProvide,
          });
        });

        it('renders the restricted icon with a tooltip', () => {
          expect(findVisibilityIcon().props('name')).toBe(
            VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_RESTRICTED],
          );
        });

        it('renders the restricted tooltip', () => {
          expect(findVisibilityTooltip().attributes('title')).toBe(restrictedTooltip);
        });
      });

      describe('when the item is public', () => {
        beforeEach(() => {
          createComponent({
            item: { ...mockItem, visibility: VISIBILITY_LEVEL_PUBLIC },
            provide: internalVisibilityProvide,
          });
        });

        it('renders the public icon with a tooltip', () => {
          expect(findVisibilityIcon().props('name')).toBe(
            VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC],
          );
        });

        it('renders the public tooltip', () => {
          expect(findVisibilityTooltip().attributes('title')).toBe(publicTooltip);
        });
      });
    });

    describe('when aiCatalogInternalVisibility is disabled', () => {
      describe('when the item is private', () => {
        beforeEach(() => {
          createComponent({
            item: { ...mockItem, public: false, visibility: VISIBILITY_LEVEL_RESTRICTED },
          });
        });

        it('derives the private icon from the public flag', () => {
          expect(findVisibilityIcon().props('name')).toBe(
            VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE],
          );
        });

        it('renders the private tooltip', () => {
          expect(findVisibilityTooltip().attributes('title')).toBe(privateTooltip);
        });
      });

      describe('when the item is public', () => {
        beforeEach(() => {
          createComponent({
            item: { ...mockItem, public: true, visibility: VISIBILITY_LEVEL_PRIVATE },
          });
        });

        it('derives the public icon from the public flag', () => {
          expect(findVisibilityIcon().props('name')).toBe(
            VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC],
          );
        });

        it('renders the public tooltip', () => {
          expect(findVisibilityTooltip().attributes('title')).toBe(publicTooltip);
        });
      });
    });
  });

  describe('renders list item link', () => {
    beforeEach(() => {
      createComponent();
    });

    it('contains correct link href', () => {
      expect(findListItemLink().props('to')).toEqual({
        name: AI_CATALOG_AGENTS_SHOW_ROUTE,
        params: { id: 1 },
      });
    });
  });

  describe('when the item is a foundational agent', () => {
    const foundationalItem = normalizeCustomOrFoundationalItem({
      __typename: TYPENAME_AI_FOUNDATIONAL_CHAT_AGENT,
      id: 'gid://gitlab/Ai::FoundationalChatAgent/security_analyst_agent-v1',
      reference: 'security_analyst_agent',
      name: 'Security Analyst',
      description: 'Automate security workflows',
      avatarUrl: '/avatar.png',
    });

    beforeEach(() => {
      createComponent({ item: foundationalItem });
    });

    it('links to the foundational agent show route using its reference', () => {
      expect(findListItemLink().props('to')).toEqual({
        name: AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
        params: { reference: 'security_analyst_agent' },
      });
    });

    it('renders the GitLab-maintained icon', () => {
      expect(findGitLabMaintainedIcon().exists()).toBe(true);
    });

    it('passes the GitLab-maintained verification level to the icon', () => {
      expect(foundationalItem.verificationLevel).toBe(VERIFICATION_LEVEL_GITLAB_MAINTAINED);
      expect(findGitLabMaintainedIcon().props('itemType')).toBe(AI_CATALOG_TYPE_FOUNDATIONAL_AGENT);
    });

    it('does not render source project attribution for a GitLab-maintained item', () => {
      expect(findSourceProjectTooltip().exists()).toBe(false);
    });

    it('renders the default star count of 0', () => {
      expect(findStarCountDisplay().exists()).toBe(true);
      expect(findStarCountDisplay().text()).toContain('0');
      expect(findStarCountDisplay().findComponent(GlIcon).props('name')).toBe('star-o');
    });

    it('renders the default usage count of 0', () => {
      expect(findUsageCountDisplay().exists()).toBe(true);
      expect(findUsageCountDisplay().text()).toContain('0');
    });

    it('renders the "Created and maintained by GitLab" tooltip', () => {
      createComponent({ item: foundationalItem, mountFn: mountExtended });

      expect(findGitLabMaintainedIcon().text().replace(/\s+/g, ' ')).toContain(
        'Created and maintained by GitLab',
      );
    });
  });

  describe('source project attribution', () => {
    beforeEach(() => {
      createComponent({
        item: {
          ...mockItem,
          project: {
            __typename: 'Project',
            nameWithNamespace: 'Group / Project 1',
          },
        },
      });
    });
    it('renders project name text correctly', () => {
      expect(findSourceProjectText().text()).toContain('Project: Group / Project 1');
    });

    it('renders tooltip correctly', () => {
      expect(findSourceProjectTooltip().attributes('title')).toBe('Group / Project 1');
    });

    describe('when project is null', () => {
      beforeEach(() => {
        createComponent({ item: { ...mockItem, project: null } });
      });

      it('renders project icon', () => {
        expect(findSourceProjectIcon().props('name')).toBe('project');
      });

      it('renders generic project name when project is null', () => {
        expect(findSourceProjectText().text()).toContain('Project: Private');
      });

      it('renders tooltip with warning explanation when project is null', () => {
        expect(findSourceProjectTooltip().attributes('title')).toBe(
          "Managed by a private project you don't have access to.",
        );
      });
    });
  });

  describe('on disable action', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits disable event', () => {
      const disableAction = findDisclosureDropdownItems().at(1);

      disableAction.vm.$emit('action');

      expect(wrapper.emitted('disable')[0]).toEqual([]);
    });
  });

  describe('gitlab-maintained item', () => {
    describe('when item is GitLab-maintained', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, verificationLevel: 'GITLAB_MAINTAINED' },
        });
      });

      it('renders gitlab-maintained icon with correct props', () => {
        const gitLabMaintainedIcon = findGitLabMaintainedIcon();

        expect(gitLabMaintainedIcon.props('resourceId')).toBe(mockItem.id);
        expect(gitLabMaintainedIcon.props('size')).toBe(16);
      });

      it('does not render the source project tooltip', () => {
        expect(findSourceProjectTooltip().exists()).toBe(false);
      });
    });

    describe('descriptionHtml rendering', () => {
      const htmlDescription = '<p>Rendered Markdown <strong>here</strong>.</p>';

      it('renders descriptionHtml when present', () => {
        createComponent({
          item: { ...mockItem, descriptionHtml: htmlDescription },
        });

        expect(wrapper.html()).toContain('Rendered Markdown <strong>here</strong>');
      });

      it('falls back to plain description when descriptionHtml is absent', () => {
        createComponent({
          item: {
            ...mockItem,
            description: 'plain text',
            descriptionHtml: null,
          },
        });

        expect(wrapper.html()).not.toContain('<strong>here</strong>');
        expect(wrapper.text()).toContain('plain text');
      });
    });

    describe('when item is a GitLab-maintained THIRD_PARTY_FLOW', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockItem,
            itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
            verificationLevel: 'GITLAB_MAINTAINED',
          },
        });
      });

      it('renders gitlab-maintained icon with correct props', () => {
        const gitLabMaintainedIcon = findGitLabMaintainedIcon();

        expect(gitLabMaintainedIcon.props('resourceId')).toBe(mockItem.id);
        expect(gitLabMaintainedIcon.props('size')).toBe(16);
      });

      it('does not render the source project tooltip', () => {
        expect(findSourceProjectTooltip().exists()).toBe(false);
      });
    });

    describe('when item is not GitLab-maintained', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render gitlab-maintained icon', () => {
        expect(findGitLabMaintainedIcon().exists()).toBe(false);
      });

      it('renders the source project tooltip', () => {
        expect(findSourceProjectTooltip().exists()).toBe(true);
      });
    });
  });

  describe('external agent label', () => {
    describe('when item is THIRD_PARTY_FLOW', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW },
        });
      });

      it('renders external label and icon', () => {
        expect(findExternalLabel().text()).toBe('External');
        expect(findExternalLabel().findComponent(GlIcon).props('name')).toBe('connected');
      });

      it('renders tooltip with correct text', () => {
        expect(findExternalLabel().attributes('title')).toBe(
          'Connects to an AI model provider outside GitLab.',
        );
      });
    });

    describe('when item is not THIRD_PARTY_FLOW', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render external indicator', () => {
        expect(findExternalLabel().exists()).toBe(false);
      });
    });
  });

  describe('update available label', () => {
    describe('when isUpdateAvailable is true', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, isUpdateAvailable: true },
        });
      });

      it('renders Update available label when isUpdateAvailable is true', () => {
        expect(findUpdateAvailableLabel().findComponent(GlBadge).text()).toBe('Update available');
      });

      it('renders tooltip with correct text', () => {
        expect(findUpdateAvailableLabel().attributes('title')).toBe(
          'A new version is available. If you have at least the Maintainer role, you can update this item.',
        );
      });
    });

    describe('when isUpdateAvailable is false', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, isUpdateAvailable: false },
        });
      });

      it('does not render Update available label when isUpdateAvailable is false', () => {
        expect(findUpdateAvailableLabel().exists()).toBe(false);
      });
    });
  });

  describe('unlisted badge', () => {
    describe('when item is soft deleted', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, softDeleted: true },
        });
      });

      it('renders Unlisted badge when softDeleted is true', () => {
        expect(findUpdateUnlistedBadge().findComponent(GlBadge).text()).toBe('Unlisted');
      });

      it('renders tooltip with correct text', () => {
        expect(findUpdateUnlistedBadge().attributes('title')).toBe(
          'This agent was removed from the AI Catalog. You can still use it in this group.',
        );
      });
    });

    describe('when item is not soft deleted', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, isUpdateAvailable: false },
        });
      });

      it('does not render Unlisted badge when softDeleted is false', () => {
        expect(findUpdateUnlistedBadge().exists()).toBe(false);
      });
    });
  });

  describe('status badge', () => {
    describe('when item has group configuration but not enabled', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockItem,
            configurationForGroup: { enabled: false },
            configurationForProject: { enabled: false },
          },
        });
      });

      it('displays pending approval badge', () => {
        expect(findStatusBadge().findComponent(GlBadge).text()).toBe('Pending approval');
        expect(findStatusBadge().findComponent(GlBadge).props('variant')).toBe('warning');
        expect(findStatusBadge().attributes('title')).toBe(
          'To use this agent, a user with the Owner role must enable it in the top-level group.',
        );
      });
    });

    describe('when item has no group configuration (null)', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockItem,
            configurationForGroup: null,
            configurationForProject: { enabled: false },
          },
        });
      });

      it('displays pending approval badge', () => {
        expect(findStatusBadge().findComponent(GlBadge).text()).toBe('Pending approval');
        expect(findStatusBadge().findComponent(GlBadge).props('variant')).toBe('warning');
        expect(findStatusBadge().attributes('title')).toBe(
          'To use this agent, a user with the Owner role must enable it in the top-level group.',
        );
      });
    });

    describe('when item has group configuration enabled but no project configuration', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockItem,
            configurationForGroup: { enabled: true },
            configurationForProject: { enabled: false },
          },
        });
      });

      it('displays ready to enable badge', () => {
        expect(findStatusBadge().findComponent(GlBadge).text()).toBe('Ready to enable');
        expect(findStatusBadge().findComponent(GlBadge).props('variant')).toBe('success');
        expect(findStatusBadge().attributes('title')).toBe(
          'To use this agent, a user with at least the Maintainer role must enable it in this project.',
        );
      });
    });

    describe('when item has group and project configurations enabled', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockItem,
            configurationForGroup: { enabled: true },
            configurationForProject: { enabled: true },
          },
        });
      });

      it('does not display status badge', () => {
        expect(findStatusBadge().exists()).toBe(false);
      });
    });

    describe('when item is enabled at project level and context is project namespace', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockItem,
            configurationForGroup: { enabled: false },
            configurationForProject: { enabled: true },
          },
          provide: { isProjectNamespace: true },
        });
      });

      it('does not display status badge', () => {
        expect(findStatusBadge().exists()).toBe(false);
      });
    });

    describe('when showStatusBadge is false in itemTypeConfig', () => {
      beforeEach(() => {
        createComponent({
          item: {
            ...mockItem,
            configurationForGroup: { enabled: false },
            configurationForProject: { enabled: false },
          },
          itemTypeConfig: {
            ...defaultItemTypeConfig,
            showStatusBadge: false,
          },
        });
      });

      it('does not display status badge', () => {
        expect(findStatusBadge().exists()).toBe(false);
      });
    });
  });

  describe.each`
    scenario                      | itemType                            | isEnabled | expectedOrigin
    ${'Disable agent'}            | ${AI_CATALOG_TYPE_AGENT}            | ${true}   | ${TRACK_EVENT_ORIGIN_PROJECT}
    ${'Disable flow'}             | ${AI_CATALOG_TYPE_FLOW}             | ${true}   | ${TRACK_EVENT_ORIGIN_PROJECT}
    ${'Disable third party flow'} | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${true}   | ${TRACK_EVENT_ORIGIN_PROJECT}
  `('when clicking $scenario', ({ itemType, isEnabled, expectedOrigin }) => {
    beforeEach(() => {
      createComponent({
        item: {
          ...mockItem,
          itemType,
          userPermissions: {
            adminAiCatalogItem: true,
          },
          configurationForProject: {
            id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
            enabled: isEnabled,
          },
        },
        provide: {
          isProjectNamespace: true,
        },
      });
    });

    it(`tracks event  ${TRACK_EVENT_DISABLE_AI_CATALOG_ITEM} with correct properties`, async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await wrapper.findComponentByTestId('disable-button').vm.$emit('action');

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
        {
          label: TRACK_EVENT_ITEM_TYPES[itemType],
          origin: expectedOrigin,
          page: TRACK_EVENT_PAGE_LIST,
        },
        undefined,
      );
    });
  });
});
