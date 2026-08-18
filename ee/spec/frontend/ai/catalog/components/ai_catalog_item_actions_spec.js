import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlTooltip } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import AiCatalogItemDeleteModal from 'ee/ai/catalog/components/ai_catalog_item_delete_modal.vue';
import StarButton from 'ee/ai/catalog/components/star_button.vue';
import aiCatalogProjectsMaintainerQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_projects_maintainer.query.graphql';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  EVENT_ITEM_TYPE_CUSTOM_AGENT,
  EVENT_ITEM_TYPE_CUSTOM_FLOW,
  TRACK_EVENT_ENABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_DELETE_AI_CATALOG_ITEM,
  TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM,
  TRACK_EVENT_ITEM_TYPES,
  TRACK_EVENT_ORIGIN_EXPLORE,
  TRACK_EVENT_ORIGIN_PROJECT,
  TRACK_EVENT_ORIGIN_GROUP,
  TRACK_EVENT_PAGE_SHOW,
} from 'ee/ai/catalog/constants';
import {
  mockAgent,
  mockFoundationalAgent,
  mockFoundationalCatalogAgent,
  mockFoundationalCatalogFlow,
  mockProjectsMaintainerResponse,
  mockProjectFactory,
} from '../mock_data';

const EVENT_ITEM_TYPE_BY_TYPE = {
  [AI_CATALOG_TYPE_AGENT]: EVENT_ITEM_TYPE_CUSTOM_AGENT,
  [AI_CATALOG_TYPE_FLOW]: EVENT_ITEM_TYPE_CUSTOM_FLOW,
};

const identityEventProperties = (itemType) => ({
  item_type: EVENT_ITEM_TYPE_BY_TYPE[itemType],
  custom_item_id: 1,
  item_version: '1.0.0',
});

jest.mock('~/lib/utils/common_utils');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogItemActions', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    item: mockAgent,
    itemRoutes: {
      duplicate: '/items/:id/duplicate',
      edit: '/items/:id/edit',
      run: '/items/:id/run',
    },
    deleteFn: jest.fn(),
  };
  const routeParams = { id: '4' };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const mockProjectsMaintainerQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectsMaintainerResponse);

  const defaultProvide = {
    isGlobalNamespace: false,
    isProjectNamespace: false,
    isGroupNamespace: false,
  };

  const createComponent = ({
    props = {},
    provide = {},
    glAbilities = {},
    glFeatures = {},
  } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogProjectsMaintainerQuery, mockProjectsMaintainerQueryHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogItemActions, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: { ...defaultProvide, ...provide, glAbilities },
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: {
          push: jest.fn(),
        },
        glFeatures,
      },
      stubs: { GlModal },
    });
  };

  const findStarButton = () => wrapper.findComponent(StarButton);
  const findEditButton = () => wrapper.findComponentByTestId('edit-button');
  const findDisableButton = () => wrapper.findComponentByTestId('disable-button');
  const findDisableDropdownItem = () => wrapper.findComponentByTestId('disable-dropdown-item');
  const findEnableButton = () => wrapper.findComponentByTestId('enable-button');
  const findMoreActions = () => wrapper.findByTestId('more-actions-dropdown');
  const findDuplicateButton = () => wrapper.findComponentByTestId('duplicate-button');
  const findReportButton = () => wrapper.findByTestId('report-button');
  const findDeleteButton = () => wrapper.findComponentByTestId('delete-button');
  const findDeleteModal = () => wrapper.findComponent(AiCatalogItemDeleteModal);
  const findDropdownTooltip = () => wrapper.findComponent(GlTooltip);
  const findConsumerModal = () => wrapper.findComponent(AiCatalogItemConsumerModal);

  const openDeleteModal = async () => {
    findDeleteButton().vm.$emit('action');
    await nextTick();
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders "More actions" tooltip', () => {
      expect(findDropdownTooltip().text()).toBe('More actions');
    });
  });

  describe('star button', () => {
    afterEach(() => {
      isLoggedIn.mockReset();
    });

    it('renders the star button with the correct item prop', () => {
      createComponent();

      expect(findStarButton().exists()).toBe(true);
      expect(findStarButton().props('item')).toEqual(mockAgent);
    });

    it('passes disabled=true to the star button when user is not logged in', () => {
      isLoggedIn.mockReturnValue(false);
      createComponent();

      expect(findStarButton().props('disabled')).toBe(true);
    });

    it('passes disabled=false to the star button when user is logged in', () => {
      isLoggedIn.mockReturnValue(true);
      createComponent();

      expect(findStarButton().props('disabled')).toBe(false);
    });

    it('does not render for foundational agents', () => {
      createComponent({ props: { item: mockFoundationalAgent } });

      expect(findStarButton().exists()).toBe(false);
    });
  });

  describe('report button visibility', () => {
    it('renders when user has reportAiCatalogItem permission and item is not GitLab-maintained', () => {
      createComponent({
        props: {
          item: {
            ...mockAgent,
            verificationLevel: 'UNVERIFIED',
          },
        },
        glAbilities: {
          reportAiCatalogItem: true,
        },
      });

      expect(findReportButton().exists()).toBe(true);
    });

    it('does not render when item is GitLab-maintained', () => {
      createComponent({
        props: {
          item: {
            ...mockAgent,
            verificationLevel: 'GITLAB_MAINTAINED',
          },
        },
        glAbilities: {
          reportAiCatalogItem: true,
        },
      });

      expect(findReportButton().exists()).toBe(false);
    });

    it('does not render when user lacks reportAiCatalogItem permission', () => {
      createComponent({
        props: {
          item: {
            ...mockAgent,
            verificationLevel: 'UNVERIFIED',
          },
        },
        glAbilities: {
          reportAiCatalogItem: false,
        },
      });

      expect(findReportButton().exists()).toBe(false);
    });
  });

  describe('at the Explore level', () => {
    beforeEach(async () => {
      createComponent({
        provide: { isGlobalNamespace: true },
      });
      await waitForPromises();
    });

    it('checks if user is maintainer of at least one project', () => {
      expect(mockProjectsMaintainerQueryHandler).toHaveBeenCalled();
    });

    it('passes duoLicensedFeature to the maintainer query', () => {
      expect(mockProjectsMaintainerQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ duoLicensedFeature: 'AI_CATALOG' }),
      );
    });

    it('does not render AiCatalogItemConsumerModal', () => {
      expect(findConsumerModal().exists()).toBe(false);
    });

    describe('when user is logged in', () => {
      beforeEach(async () => {
        isLoggedIn.mockReturnValue(true);
        createComponent({
          provide: { isGlobalNamespace: true },
        });
        await waitForPromises();
      });

      it('renders AiCatalogItemConsumerModal', () => {
        expect(findConsumerModal().props('canEnable')).toBe(true);
      });
    });
  });

  describe('at the Project level', () => {
    beforeEach(async () => {
      isLoggedIn.mockReturnValue(true);
      createComponent({
        glAbilities: { adminAiCatalogItemConsumer: true },
        provide: {
          isGlobalNamespace: false,
          isProjectNamespace: true,
          projectPath: 'gitlab-duo/test',
        },
      });
      await waitForPromises();
    });

    it('does not check if user is maintainer of at least one project', () => {
      expect(mockProjectsMaintainerQueryHandler).not.toHaveBeenCalled();
    });

    it('renders AiCatalogItemConsumerModal', () => {
      expect(findConsumerModal().props('canEnable')).toBe(true);
    });
  });

  describe.each`
    scenario                                      | canAdmin | canUse   | foundational | editBtn  | disableBtn | enableBtn | moreActions | duplicateBtn | deleteBtn | itemType
    ${'not logged in'}                            | ${false} | ${false} | ${false}     | ${false} | ${false}   | ${true}   | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, not admin of item'}             | ${false} | ${true}  | ${false}     | ${false} | ${false}   | ${true}   | ${true}     | ${true}      | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of item'}                 | ${true}  | ${true}  | ${false}     | ${true}  | ${false}   | ${true}   | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of flow item'}            | ${true}  | ${true}  | ${false}     | ${true}  | ${false}   | ${true}   | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_FLOW}
    ${'logged in, foundational agent'}            | ${false} | ${true}  | ${true}      | ${false} | ${false}   | ${false}  | ${true}     | ${true}      | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin foundational agent'}      | ${true}  | ${true}  | ${true}      | ${true}  | ${false}   | ${false}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, foundational flow'}             | ${false} | ${true}  | ${true}      | ${false} | ${false}   | ${false}  | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_FLOW}
    ${'logged in, admin foundational flow'}       | ${true}  | ${true}  | ${true}      | ${true}  | ${false}   | ${false}  | ${true}     | ${false}     | ${true}   | ${AI_CATALOG_TYPE_FLOW}
    ${'logged in, foundational third-party flow'} | ${false} | ${true}  | ${true}      | ${false} | ${false}   | ${true}   | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW}
  `(
    'at the Explore level, when $scenario',
    ({
      canAdmin,
      canUse,
      foundational,
      editBtn,
      disableBtn,
      enableBtn,
      moreActions,
      duplicateBtn,
      deleteBtn,
      itemType,
    }) => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              itemType,
              foundational,
              userPermissions: {
                adminAiCatalogItem: canAdmin,
              },
              configurationForProject: {
                id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
              },
            },
            itemRoutes: {
              ...defaultProps.itemRoutes,
            },
          },
          provide: {
            isGlobalNamespace: true,
          },
          glAbilities: { readAiCatalog: canUse },
        });
        isLoggedIn.mockReturnValue(canUse);
      });

      it(`${editBtn ? 'renders' : 'does not render'} Edit button`, () => {
        expect(findEditButton().exists()).toBe(editBtn);
        if (editBtn) {
          expect(findEditButton().props('to')).toMatchObject({
            name: defaultProps.itemRoutes.edit,
            params: { id: routeParams.id },
          });
        }
      });

      it(`${disableBtn ? 'renders' : 'does not render'} "Disable" button`, () => {
        expect(findDisableButton().exists()).toBe(disableBtn);
      });

      it(`${enableBtn ? 'renders' : 'does not render'} "Enable" button`, () => {
        expect(findEnableButton().exists()).toBe(enableBtn);
      });

      it(`${moreActions ? 'renders' : 'does not render'} more actions`, () => {
        expect(findMoreActions().exists()).toBe(moreActions);
      });

      it(`${duplicateBtn ? 'renders' : 'does not render'} Duplicate button`, () => {
        expect(findDuplicateButton().exists()).toBe(duplicateBtn);
      });

      it(`${deleteBtn ? 'renders' : 'does not render'} Delete button`, () => {
        expect(findDeleteButton().exists()).toBe(deleteBtn);
      });
    },
  );

  describe('at the Explore level with non-DAP users', () => {
    describe('when user is logged out', () => {
      beforeEach(() => {
        isLoggedIn.mockReturnValue(false);
        createComponent({
          props: {
            item: {
              ...mockAgent,
              userPermissions: {
                adminAiCatalogItem: false,
              },
            },
          },
          provide: {
            isGlobalNamespace: true,
          },
          glAbilities: { readAiCatalog: false },
        });
      });

      it('renders disabled Enable button', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(true);
      });

      it('shows "Log in to enable" tooltip', () => {
        const tooltipWrapper = wrapper.findByTestId('enable-button-wrapper');
        expect(tooltipWrapper.attributes('title')).toBe('Log in to enable');
      });

      it('does not render dropdown', () => {
        expect(findMoreActions().exists()).toBe(false);
      });
    });

    describe('when user is logged in but does not have readAiCatalog ability', () => {
      beforeEach(async () => {
        isLoggedIn.mockReturnValue(true);
        createComponent({
          props: {
            item: {
              ...mockAgent,
              userPermissions: {
                adminAiCatalogItem: false,
              },
            },
          },
          provide: {
            isGlobalNamespace: true,
          },
          glAbilities: { readAiCatalog: false },
        });
        await waitForPromises();
      });

      it('renders disabled Enable button', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(true);
      });

      it('shows contact admin tooltip', () => {
        const tooltipWrapper = wrapper.findByTestId('enable-button-wrapper');
        expect(tooltipWrapper.attributes('title')).toBe(
          'Contact your administrator to enable GitLab Duo',
        );
      });

      it('does not render dropdown', () => {
        expect(findMoreActions().exists()).toBe(false);
      });
    });

    describe('when user has readAiCatalog ability but no maintainer projects', () => {
      const mockProjectsMaintainerEmptyHandler = jest.fn().mockResolvedValue({
        data: { projects: { nodes: [] } },
      });

      beforeEach(async () => {
        isLoggedIn.mockReturnValue(true);
        mockApollo = createMockApollo([
          [aiCatalogProjectsMaintainerQuery, mockProjectsMaintainerEmptyHandler],
        ]);

        wrapper = shallowMountExtended(AiCatalogItemActions, {
          apolloProvider: mockApollo,
          propsData: {
            ...defaultProps,
            item: {
              ...mockAgent,
              userPermissions: {
                adminAiCatalogItem: false,
              },
            },
          },
          provide: {
            ...defaultProvide,
            isGlobalNamespace: true,
            glAbilities: { readAiCatalog: true },
          },
          mocks: {
            $route: { params: routeParams },
            $router: { push: jest.fn() },
            glFeatures: {},
          },
          stubs: { GlModal },
        });
        await waitForPromises();
      });

      it('renders enabled Enable button (modal handles no-project state)', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(false);
      });

      it('does not show tooltip', () => {
        const tooltipWrapper = wrapper.findByTestId('enable-button-wrapper');
        expect(tooltipWrapper.attributes('title')).toBeUndefined();
      });
    });
  });

  describe.each`
    scenario                                         | canAdmin | canUse   | enabledSetting | foundational | editBtn  | disableBtn | enableBtn | enableDisabled | moreActions | duplicateBtn | deleteBtn | itemType                 | isGlobalNamespace | isEnabled
    ${'not logged in'}                               | ${false} | ${false} | ${true}        | ${false}     | ${false} | ${false}   | ${true}   | ${true}        | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${false}
    ${'logged in, custom agents disabled'}           | ${true}  | ${true}  | ${false}       | ${false}     | ${true}  | ${false}   | ${true}   | ${false}       | ${true}     | ${false}     | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${false}
    ${'logged in, not admin of enabled item'}        | ${false} | ${true}  | ${true}        | ${false}     | ${false} | ${true}    | ${false}  | ${false}       | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${true}
    ${'logged in, admin of item'}                    | ${true}  | ${true}  | ${true}        | ${false}     | ${true}  | ${false}   | ${true}   | ${false}       | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${false}
    ${'logged in, admin of enabled item'}            | ${true}  | ${true}  | ${true}        | ${false}     | ${true}  | ${true}    | ${false}  | ${false}       | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${true}
    ${'logged in, admin of enabled flow item'}       | ${true}  | ${true}  | ${true}        | ${false}     | ${true}  | ${true}    | ${false}  | ${false}       | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_FLOW}  | ${false}          | ${true}
    ${'logged in, foundational agent'}               | ${false} | ${true}  | ${true}        | ${true}      | ${false} | ${false}   | ${false}  | ${false}       | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${false}
    ${'logged in, admin of foundational agent'}      | ${true}  | ${true}  | ${true}        | ${true}      | ${true}  | ${false}   | ${false}  | ${false}       | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${true}
    ${'logged in, admin enabled foundational agent'} | ${true}  | ${true}  | ${true}        | ${true}      | ${true}  | ${false}   | ${false}  | ${false}       | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${true}
    ${'logged in, admin of foundational flow item'}  | ${true}  | ${true}  | ${true}        | ${true}      | ${true}  | ${true}    | ${false}  | ${false}       | ${true}     | ${false}     | ${true}   | ${AI_CATALOG_TYPE_FLOW}  | ${false}          | ${true}
  `(
    'at the Project level, when $scenario',
    ({
      canAdmin,
      canUse,
      enabledSetting,
      foundational,
      editBtn,
      disableBtn,
      enableBtn,
      enableDisabled,
      moreActions,
      duplicateBtn,
      deleteBtn,
      itemType,
      isEnabled,
    }) => {
      beforeEach(() => {
        createComponent({
          glAbilities: { adminAiCatalogItemConsumer: canAdmin },
          props: {
            item: {
              ...mockAgent,
              itemType,
              foundational,
              userPermissions: {
                adminAiCatalogItem: canAdmin,
              },
              configurationForProject: {
                id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                enabled: isEnabled,
              },
            },
            itemRoutes: {
              ...defaultProps.itemRoutes,
            },
          },
          provide: {
            isGlobalNamespace: false,
            isProjectNamespace: true,
            projectPath: 'gitlab-duo/test',
            duoSettings: {
              duoCustomAgentsEnabled: enabledSetting,
              duoCustomFlowsEnabled: enabledSetting,
              duoExternalAgentsEnabled: enabledSetting,
            },
          },
        });
        isLoggedIn.mockReturnValue(canUse);
      });

      it(`${editBtn ? 'renders' : 'does not render'} Edit button`, () => {
        expect(findEditButton().exists()).toBe(editBtn);
        if (editBtn) {
          expect(findEditButton().props('to')).toMatchObject({
            name: defaultProps.itemRoutes.edit,
            params: { id: routeParams.id },
          });
        }
      });

      it(`${disableBtn ? 'renders' : 'does not render'} "Disable" button`, () => {
        expect(findDisableButton().exists()).toBe(disableBtn);
      });

      it('does not render "Disable" in More actions dropdown', () => {
        expect(findDisableDropdownItem().exists()).toBe(false);
      });

      it(`${enableBtn ? 'renders' : 'does not render'} "Enable" button`, () => {
        expect(findEnableButton().exists()).toBe(enableBtn);
      });

      if (enabledSetting) {
        it(`shows ${enableBtn ? `${enableDisabled ? 'disabled' : 'active'} "Enable"` : 'no Enable'} button`, () => {
          if (!enableBtn) {
            expect(findEnableButton().exists()).toBe(false);
            return;
          }
          expect(findEnableButton().props('disabled')).toBe(enableDisabled);
          expect(findEnableButton().text()).toBe('Enable');
        });
      } else {
        it(`shows disabled "Enabled" button with tooltip`, () => {
          if (!enableBtn) {
            expect(findEnableButton().exists()).toBe(false);
            return;
          }
          expect(findEnableButton().props('disabled')).toBe(true);
          const tooltipWrapper = wrapper.findByTestId('enable-button-wrapper');
          expect(tooltipWrapper.attributes('title')).toBe(
            'Enabling custom agents is turned off. Contact an administrator to change this.',
          );
        });
      }

      it(`${moreActions ? 'renders' : 'does not render'} more actions`, () => {
        expect(findMoreActions().exists()).toBe(moreActions);
      });

      it(`${duplicateBtn ? 'renders' : 'does not render'} Duplicate button`, () => {
        expect(findDuplicateButton().exists()).toBe(duplicateBtn);
      });

      it(`${deleteBtn ? 'renders' : 'does not render'} Delete button`, () => {
        expect(findDeleteButton().exists()).toBe(deleteBtn);
      });
    },
  );

  describe('at the Project level, when user lacks adminAiCatalogItemConsumer permission', () => {
    const createProjectComponent = ({ isEnabled }) => {
      createComponent({
        glAbilities: { adminAiCatalogItemConsumer: false },
        props: {
          item: {
            ...mockAgent,
            userPermissions: {
              adminAiCatalogItem: false,
            },
            configurationForProject: {
              id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
              enabled: isEnabled,
            },
          },
        },
        provide: {
          isGlobalNamespace: false,
          isProjectNamespace: true,
          projectPath: 'gitlab-duo/test',
          duoSettings: {
            duoCustomAgentsEnabled: true,
            duoCustomFlowsEnabled: true,
            duoExternalAgentsEnabled: true,
          },
        },
      });
      isLoggedIn.mockReturnValue(true);
    };

    describe('when item is not enabled', () => {
      beforeEach(() => {
        createProjectComponent({ isEnabled: false });
      });

      it('renders the Enable button in a disabled state', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(true);
      });

      it('shows the "Contact maintainer to enable" tooltip', () => {
        const tooltipWrapper = wrapper.findByTestId('enable-button-wrapper');
        expect(tooltipWrapper.attributes('title')).toBe('Contact maintainer to enable');
      });

      it('does not render the Disable button', () => {
        expect(findDisableButton().exists()).toBe(false);
      });
    });

    describe('when item is enabled', () => {
      beforeEach(() => {
        createProjectComponent({ isEnabled: true });
      });

      it('renders the Disable button in a disabled state', () => {
        expect(findDisableButton().exists()).toBe(true);
        expect(findDisableButton().props('disabled')).toBe(true);
      });

      it('shows the "Contact maintainer to disable" tooltip', () => {
        const tooltipWrapper = wrapper.findByTestId('disable-button-wrapper');
        expect(tooltipWrapper.attributes('title')).toBe('Contact maintainer to disable');
      });

      it('does not render the Enable button', () => {
        expect(findEnableButton().exists()).toBe(false);
      });
    });
  });

  describe('at the Group level', () => {
    describe('when viewing an enabled item', () => {
      describe.each`
        scenario                              | canAdmin | canUse   | disableBtn | moreActions | itemType                 | isEnabled
        ${'not logged in'}                    | ${false} | ${false} | ${false}   | ${false}    | ${AI_CATALOG_TYPE_AGENT} | ${true}
        ${'logged in, not admin of item'}     | ${false} | ${true}  | ${false}   | ${false}    | ${AI_CATALOG_TYPE_AGENT} | ${true}
        ${'logged in, admin of enabled item'} | ${true}  | ${true}  | ${true}    | ${true}     | ${AI_CATALOG_TYPE_AGENT} | ${true}
      `('when $scenario', ({ canAdmin, canUse, disableBtn, moreActions, itemType, isEnabled }) => {
        beforeEach(() => {
          createComponent({
            glAbilities: { adminAiCatalogItemConsumer: canAdmin },
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: false,
                },
                configurationForGroup: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
              itemRoutes: {
                ...defaultProps.itemRoutes,
              },
            },
            provide: {
              isGlobalNamespace: false,
              isGroupNamespace: true,
              groupPath: 'test-group',
            },
          });
          isLoggedIn.mockReturnValue(canUse);
        });

        it('does not render Edit button', () => {
          expect(findEditButton().exists()).toBe(false);
        });

        it(`${disableBtn ? 'renders' : 'does not render'} "Disable" item in dropdown`, () => {
          expect(findDisableDropdownItem().exists()).toBe(disableBtn);
        });

        it('does not render primary Disable button', () => {
          expect(findDisableButton().exists()).toBe(false);
        });

        it('does not render "Enable" button', () => {
          expect(findEnableButton().exists()).toBe(false);
        });

        it(`${moreActions ? 'renders' : 'does not render'} more actions`, () => {
          expect(findMoreActions().exists()).toBe(moreActions);
        });

        it('does not render Duplicate button', () => {
          expect(findDuplicateButton().exists()).toBe(false);
        });

        it('does not render Report button', () => {
          expect(findReportButton().exists()).toBe(false);
        });

        it('does not render Delete button', () => {
          expect(findDeleteButton().exists()).toBe(false);
        });
      });
    });

    describe('when viewing an enabled foundational item', () => {
      describe.each`
        scenario                | baseItem
        ${'foundational agent'} | ${mockFoundationalCatalogAgent}
        ${'foundational flow'}  | ${mockFoundationalCatalogFlow}
      `('when viewing a $scenario as consumer admin', ({ baseItem }) => {
        beforeEach(() => {
          createComponent({
            props: {
              item: {
                ...baseItem,
                configurationForGroup: { enabled: true },
              },
            },
            provide: { isGroupNamespace: true },
          });
        });

        it('does not render "Disable" item in dropdown', () => {
          expect(findDisableDropdownItem().exists()).toBe(false);
        });
      });
    });

    describe('when viewing a disabled item', () => {
      describe.each`
        scenario                          | canAdmin | canUse   | itemType                 | isEnabled
        ${'not logged in'}                | ${false} | ${false} | ${AI_CATALOG_TYPE_AGENT} | ${false}
        ${'logged in, not admin of item'} | ${false} | ${true}  | ${AI_CATALOG_TYPE_AGENT} | ${false}
        ${'logged in, admin of item'}     | ${true}  | ${true}  | ${AI_CATALOG_TYPE_AGENT} | ${false}
      `('when $scenario', ({ canAdmin, canUse, itemType, isEnabled }) => {
        beforeEach(() => {
          createComponent({
            glAbilities: { adminAiCatalogItemConsumer: canAdmin },
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: false,
                },
                configurationForGroup: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
              itemRoutes: {
                ...defaultProps.itemRoutes,
              },
            },
            provide: {
              isGlobalNamespace: false,
              isGroupNamespace: true,
              groupPath: 'test-group',
            },
          });
          isLoggedIn.mockReturnValue(canUse);
        });

        it('does not render Edit button', () => {
          expect(findEditButton().exists()).toBe(false);
        });

        it('does not render "Enable" button', () => {
          expect(findEnableButton().exists()).toBe(false);
        });

        it('does not render "Disable" item in dropdown', () => {
          expect(findDisableDropdownItem().exists()).toBe(false);
        });

        it('does not render primary "Disable" button', () => {
          expect(findDisableButton().exists()).toBe(false);
        });

        it('does not render more actions', () => {
          expect(findMoreActions().exists()).toBe(false);
        });

        it('does not render Duplicate button', () => {
          expect(findDuplicateButton().exists()).toBe(false);
        });

        it('does not render Report button', () => {
          expect(findReportButton().exists()).toBe(false);
        });

        it('does not render Delete button', () => {
          expect(findDeleteButton().exists()).toBe(false);
        });
      });
    });
  });

  describe('delete modal', () => {
    beforeEach(() => {
      createComponent({
        props: {
          item: {
            ...mockAgent,
            userPermissions: {
              adminAiCatalogItem: true,
            },
          },
        },
      });
    });

    it('is not shown by default', () => {
      expect(findDeleteModal().exists()).toBe(false);
    });

    it('is shown with correct props after clicking delete', async () => {
      await openDeleteModal();

      expect(findDeleteModal().exists()).toBe(true);
      expect(findDeleteModal().props('item')).toMatchObject(
        expect.objectContaining({ id: mockAgent.id }),
      );
      expect(findDeleteModal().props('deleteFn')).toBe(defaultProps.deleteFn);
    });

    it('is hidden when the modal emits close', async () => {
      await openDeleteModal();
      expect(findDeleteModal().exists()).toBe(true);

      findDeleteModal().vm.$emit('close');
      await nextTick();

      expect(findDeleteModal().exists()).toBe(false);
    });
  });

  describe('tracking', () => {
    describe.each`
      scenario                           | itemType                 | isGlobalNamespace | isEnabled | buttonFinder        | expectedOrigin
      ${'Enable agent at Explore level'} | ${AI_CATALOG_TYPE_AGENT} | ${true}           | ${false}  | ${findEnableButton} | ${TRACK_EVENT_ORIGIN_EXPLORE}
      ${'Enable flow at Project level'}  | ${AI_CATALOG_TYPE_FLOW}  | ${false}          | ${false}  | ${findEnableButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
    `(
      'when clicking $scenario',
      ({ itemType, isGlobalNamespace, isEnabled, buttonFinder, expectedOrigin }) => {
        beforeEach(() => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            glAbilities: { adminAiCatalogItemConsumer: true },
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
            },
            provide: {
              isGlobalNamespace,
              isProjectNamespace: !isGlobalNamespace,
              projectPath: 'gitlab-duo/test',
              duoSettings: {
                duoCustomFlowsEnabled: true,
              },
            },
          });
        });

        it(`tracks event  ${TRACK_EVENT_ENABLE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit('click');

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_ENABLE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
              ...identityEventProperties(itemType),
            },
            undefined,
          );
        });
      },
    );

    describe.each`
      scenario                            | itemType                 | isGlobalNamespace | isEnabled | buttonFinder               | buttonEvent | expectedOrigin                | projectPath          | groupPath
      ${'Disable agent at Project level'} | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${true}   | ${findDisableButton}       | ${'click'}  | ${TRACK_EVENT_ORIGIN_PROJECT} | ${'gitlab-duo/test'} | ${undefined}
      ${'Disable flow at Project level'}  | ${AI_CATALOG_TYPE_FLOW}  | ${false}          | ${true}   | ${findDisableButton}       | ${'click'}  | ${TRACK_EVENT_ORIGIN_PROJECT} | ${'gitlab-duo/test'} | ${undefined}
      ${'Disable agent at Group level'}   | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${true}   | ${findDisableDropdownItem} | ${'action'} | ${TRACK_EVENT_ORIGIN_GROUP}   | ${undefined}         | ${'test-group'}
      ${'Disable flow at Group level'}    | ${AI_CATALOG_TYPE_FLOW}  | ${false}          | ${true}   | ${findDisableDropdownItem} | ${'action'} | ${TRACK_EVENT_ORIGIN_GROUP}   | ${undefined}         | ${'test-group'}
    `(
      'when clicking $scenario',
      ({
        itemType,
        isGlobalNamespace,
        isEnabled,
        buttonFinder,
        buttonEvent,
        expectedOrigin,
        projectPath,
        groupPath,
      }) => {
        beforeEach(() => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            glAbilities: { adminAiCatalogItemConsumer: true },
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
                configurationForGroup: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/2',
                  enabled: isEnabled,
                },
              },
              disableConfirmMessage: 'Are you sure you want to disable this agent?',
            },
            provide: {
              isGlobalNamespace,
              isProjectNamespace: Boolean(projectPath),
              isGroupNamespace: Boolean(groupPath),
              projectPath,
              groupPath,
            },
          });
        });

        it(`tracks event  ${TRACK_EVENT_DISABLE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit(buttonEvent);

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
              ...identityEventProperties(itemType),
            },
            undefined,
          );
        });
      },
    );

    describe('when a fully-loaded version is provided', () => {
      const versionWithDetails = {
        versionName: '2.0.0',
        tools: { nodes: [{ name: 'read_file' }, { name: 'grep' }] },
        mcpTools: ['search'],
        mcpServers: { nodes: [{ id: 'gid://gitlab/Ai::Catalog::McpServer/1' }] },
      };

      const itemWithProjectConfiguration = {
        ...mockAgent,
        userPermissions: { adminAiCatalogItem: true },
        configurationForProject: {
          id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
          enabled: false,
        },
      };

      const expectedVersionProperties = {
        item_type: EVENT_ITEM_TYPE_CUSTOM_AGENT,
        custom_item_id: 1,
        item_version: '2.0.0',
        item_schema_version: 'v1',
        tools: 'read_file,grep',
        mcp_tools: 'search',
        mcp_servers: '1',
      };

      beforeEach(() => {
        isLoggedIn.mockReturnValue(true);
      });

      it('includes the richer version properties on the enable event', async () => {
        createComponent({
          glAbilities: { adminAiCatalogItemConsumer: true },
          props: { item: itemWithProjectConfiguration, version: versionWithDetails },
          provide: {
            isProjectNamespace: true,
            projectPath: 'gitlab-duo/test',
            duoSettings: { duoCustomAgentsEnabled: true },
          },
        });

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        await findEnableButton().vm.$emit('click');
        await nextTick();

        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_ENABLE_AI_CATALOG_ITEM,
          {
            label: TRACK_EVENT_ITEM_TYPES[AI_CATALOG_TYPE_AGENT],
            origin: TRACK_EVENT_ORIGIN_PROJECT,
            page: TRACK_EVENT_PAGE_SHOW,
            ...expectedVersionProperties,
          },
          undefined,
        );
      });

      it('includes the richer version properties on the disable event', async () => {
        createComponent({
          glAbilities: { adminAiCatalogItemConsumer: true },
          props: {
            item: {
              ...itemWithProjectConfiguration,
              configurationForProject: { id: 'x', enabled: true },
            },
            version: versionWithDetails,
          },
          provide: {
            isProjectNamespace: true,
            projectPath: 'gitlab-duo/test',
          },
        });

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        await findDisableButton().vm.$emit('click');
        await nextTick();

        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
          {
            label: TRACK_EVENT_ITEM_TYPES[AI_CATALOG_TYPE_AGENT],
            origin: TRACK_EVENT_ORIGIN_PROJECT,
            page: TRACK_EVENT_PAGE_SHOW,
            ...expectedVersionProperties,
          },
          undefined,
        );
      });
    });

    describe.each`
      scenario                           | itemType                 | isGlobalNamespace | isEnabled | buttonFinder        | expectedOrigin
      ${'Delete agent at Explore level'} | ${AI_CATALOG_TYPE_AGENT} | ${true}           | ${false}  | ${findDeleteButton} | ${TRACK_EVENT_ORIGIN_EXPLORE}
      ${'Delete flow at Project level'}  | ${AI_CATALOG_TYPE_FLOW}  | ${false}          | ${false}  | ${findDeleteButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
      ${'Delete agent at Project level'} | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${false}  | ${findDeleteButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
    `(
      'when clicking $scenario',
      ({ itemType, isGlobalNamespace, isEnabled, buttonFinder, expectedOrigin }) => {
        beforeEach(() => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
            },
            provide: {
              isGlobalNamespace,
              isProjectNamespace: !isGlobalNamespace,
              projectPath: isGlobalNamespace ? undefined : 'gitlab-duo/test',
            },
          });
        });

        it(`tracks event  ${TRACK_EVENT_DELETE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit('action');

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_DELETE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
              ...identityEventProperties(itemType),
            },
            undefined,
          );
        });
      },
    );

    describe.each`
      scenario                              | itemType                 | isGlobalNamespace | isEnabled | buttonFinder           | expectedOrigin
      ${'Duplicate agent at Explore level'} | ${AI_CATALOG_TYPE_AGENT} | ${true}           | ${false}  | ${findDuplicateButton} | ${TRACK_EVENT_ORIGIN_EXPLORE}
      ${'Duplicate flow at Project level'}  | ${AI_CATALOG_TYPE_FLOW}  | ${false}          | ${false}  | ${findDuplicateButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
      ${'Duplicate agent at Project level'} | ${AI_CATALOG_TYPE_AGENT} | ${false}          | ${false}  | ${findDuplicateButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
    `(
      'when clicking $scenario',
      ({ itemType, isGlobalNamespace, isEnabled, buttonFinder, expectedOrigin }) => {
        beforeEach(() => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
            },
            provide: {
              isGlobalNamespace,
              isProjectNamespace: !isGlobalNamespace,
              projectPath: isGlobalNamespace ? undefined : 'gitlab-duo/test',
              duoSettings: {
                duoCustomFlowsEnabled: true,
                duoCustomAgentsEnabled: true,
              },
            },
          });
        });

        it(`tracks event  ${TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit('action');

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
              ...identityEventProperties(itemType),
            },
            undefined,
          );
        });
      },
    );
  });

  describe('third-party flow duplicate button visibility', () => {
    describe.each`
      scenario                                                 | itemType                            | glAbility | aiCatalogThirdPartyFlows | aiCatalogCreateThirdPartyFlows | shouldRender
      ${'THIRD_PARTY_FLOW with ability enabled'}               | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${true}   | ${false}                 | ${false}                       | ${true}
      ${'THIRD_PARTY_FLOW with feature flags enabled'}         | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${null}   | ${true}                  | ${true}                        | ${true}
      ${'THIRD_PARTY_FLOW with feature not available'}         | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${false}  | ${false}                 | ${false}                       | ${false}
      ${'THIRD_PARTY_FLOW with only one feature flag enabled'} | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${null}   | ${true}                  | ${false}                       | ${false}
      ${'non-THIRD_PARTY_FLOW with feature not available'}     | ${AI_CATALOG_TYPE_AGENT}            | ${false}  | ${false}                 | ${false}                       | ${true}
    `(
      'when $scenario',
      ({
        itemType,
        glAbility,
        aiCatalogThirdPartyFlows,
        aiCatalogCreateThirdPartyFlows,
        shouldRender,
      }) => {
        beforeEach(() => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            glAbilities: {
              createAiCatalogThirdPartyFlow: glAbility,
            },
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
              },
            },
            provide: {
              isGlobalNamespace: true,

              glFeatures: {
                aiCatalogThirdPartyFlows,
                aiCatalogCreateThirdPartyFlows,
              },
            },
          });
        });

        it(`${shouldRender ? 'renders' : 'does not render'} Duplicate button`, () => {
          expect(findDuplicateButton().exists()).toBe(shouldRender);
        });
      },
    );
  });

  describe('private item viewed outside its managing project', () => {
    const owningProjectId = '42';
    const owningProjectName = 'Group 1 / Project 1';
    const mockPrivateAgent = {
      ...mockAgent,
      public: false,
      project: mockProjectFactory({
        id: `gid://gitlab/Project/${owningProjectId}`,
        name: 'Project 1',
        nameWithNamespace: owningProjectName,
        webUrl: 'https://gitlab.com/group-1/project-1',
      }),
    };

    const findEnableTooltipWrapper = () => wrapper.findByTestId('enable-button-wrapper');

    beforeEach(() => {
      isLoggedIn.mockReturnValue(true);
    });

    describe('from the global Explore namespace', () => {
      beforeEach(async () => {
        createComponent({
          props: { item: mockPrivateAgent },
          provide: { isGlobalNamespace: true },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('does not disable the Enable button (Explore is not gated)', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(false);
      });

      it('does not show the managing-project tooltip', () => {
        expect(findEnableTooltipWrapper().attributes('title')).toBe(undefined);
      });
    });

    describe('when inside a different project (same group or not)', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockPrivateAgent,
              configurationForProject: { enabled: false },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: '99',
            projectPath: 'group-1/sibling-project',
            duoSettings: {
              duoCustomAgentsEnabled: true,
            },
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('disables the Enable button', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(true);
      });

      it('shows the managing project tooltip', () => {
        expect(findEnableTooltipWrapper().attributes('title')).toBe(
          `This private agent is managed by ${owningProjectName} and can't be enabled from this project.`,
        );
      });
    });

    describe('when inside the owning project', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockPrivateAgent,
              configurationForProject: { enabled: false },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: owningProjectId,
            projectPath: 'group-1/project-1',
            duoSettings: {
              duoCustomAgentsEnabled: true,
            },
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('does not disable the Enable button', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(false);
      });
    });

    describe('for a public item viewed outside the owning project', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockPrivateAgent,
              public: true,
              configurationForProject: { enabled: false },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: '99',
            projectPath: 'other-group/some-project',
            duoSettings: {
              duoCustomAgentsEnabled: true,
            },
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('does not disable the Enable button (public items are not gated)', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(false);
      });
    });
  });

  describe('already-enabled private item', () => {
    const owningProjectId = '42';
    const owningProjectName = 'Group 1 / Project 1';
    const mockPrivateEnabledAgent = {
      ...mockAgent,
      public: false,
      isEnabledInManagedByProject: true,
      project: mockProjectFactory({
        id: `gid://gitlab/Project/${owningProjectId}`,
        name: 'Project 1',
        nameWithNamespace: owningProjectName,
        webUrl: 'https://gitlab.com/group-1/project-1',
      }),
    };

    const findEnableTooltipWrapper = () => wrapper.findByTestId('enable-button-wrapper');

    beforeEach(() => {
      isLoggedIn.mockReturnValue(true);
    });

    describe('from the global Explore namespace', () => {
      beforeEach(async () => {
        createComponent({
          props: { item: mockPrivateEnabledAgent },
          provide: { isGlobalNamespace: true },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('renders the Enable button as disabled', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(true);
      });

      it('renders the button label as "Enabled"', () => {
        expect(findEnableButton().text()).toBe('Enabled');
      });

      it('shows the "already enabled" tooltip', () => {
        expect(findEnableTooltipWrapper().attributes('title')).toBe(
          'This agent is already enabled.',
        );
      });
    });

    describe('from inside the owning project', () => {
      // Inside the owning project where the item is already enabled, existing
      // behaviour replaces the Enable button entirely with a Disable action in
      // the dropdown — there is no Enable affordance to disable.
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockPrivateEnabledAgent,
              configurationForProject: { enabled: true },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: owningProjectId,
            projectPath: 'group-1/project-1',
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('does not render the Enable button (replaced by Disable action)', () => {
        expect(findEnableButton().exists()).toBe(false);
      });
    });

    describe('when the private item is NOT yet enabled in its owning project', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockPrivateEnabledAgent,
              isEnabledInManagedByProject: false,
            },
          },
          provide: { isGlobalNamespace: true },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('renders the Enable button as enabled (not disabled)', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(false);
      });

      it('renders the button label as "Enable"', () => {
        expect(findEnableButton().text()).toBe('Enable');
      });

      it('does not show the "already enabled" tooltip', () => {
        expect(findEnableTooltipWrapper().attributes('title')).toBeUndefined();
      });
    });

    describe('for a public item that is already enabled in the current project', () => {
      // Existing behaviour preserved: public-item flow is untouched and still
      // reads isEnabled from configurationForProject.enabled.
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              public: true,
              isEnabledInManagedByProject: true,
              configurationForProject: { enabled: false },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: '99',
            projectPath: 'group-1/some-project',
            duoSettings: {
              duoCustomAgentsEnabled: true,
            },
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('does not gate the button based on isEnabledInManagedByProject', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(false);
        expect(findEnableButton().text()).toBe('Enable');
      });
    });
  });

  describe('restricted item', () => {
    const owningProjectId = '42';
    const owningProjectName = 'Group 1 / Project 1';
    const mockRestrictedAgent = {
      ...mockAgent,
      public: false,
      visibility: 'RESTRICTED',
      project: mockProjectFactory({
        id: `gid://gitlab/Project/${owningProjectId}`,
        name: 'Project 1',
        nameWithNamespace: owningProjectName,
        webUrl: 'https://gitlab.com/group-1/project-1',
      }),
    };
    const findEnableTooltipWrapper = () => wrapper.findByTestId('enable-button-wrapper');

    beforeEach(() => {
      isLoggedIn.mockReturnValue(true);
    });

    describe('when viewed from a sibling project (same TLG, item not yet enabled there)', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockRestrictedAgent,
              configurationForProject: { enabled: false },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: '99',
            projectPath: 'group-1/sibling-project',
            duoSettings: { duoCustomAgentsEnabled: true },
            glFeatures: { aiCatalogInternalVisibility: true },
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('shows Enable (not Disable)', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findDisableButton().exists()).toBe(false);
      });

      it('renders the Enable button as enabled', () => {
        expect(findEnableButton().props('disabled')).toBe(false);
      });

      it('does not show the managing-project tooltip', () => {
        expect(findEnableTooltipWrapper().attributes('title')).toBeUndefined();
      });
    });

    describe('when viewed from a sibling project where the item IS already enabled', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockRestrictedAgent,
              configurationForProject: { enabled: true },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: '99',
            projectPath: 'group-1/sibling-project',
            duoSettings: { duoCustomAgentsEnabled: true },
            glFeatures: { aiCatalogInternalVisibility: true },
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('shows the Disable button instead of Enable', () => {
        expect(findDisableButton().exists()).toBe(true);
        expect(findEnableButton().exists()).toBe(false);
      });
    });

    describe('when the flag is off (falls back to private behaviour)', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            item: {
              ...mockRestrictedAgent,
              configurationForProject: { enabled: false },
            },
          },
          provide: {
            isProjectNamespace: true,
            projectId: '99',
            projectPath: 'group-1/sibling-project',
            duoSettings: { duoCustomAgentsEnabled: true },
          },
          glAbilities: { adminAiCatalogItemConsumer: true, readAiCatalog: true },
        });
        await waitForPromises();
      });

      it('disables the Enable button (treated as private)', () => {
        expect(findEnableButton().exists()).toBe(true);
        expect(findEnableButton().props('disabled')).toBe(true);
      });
    });
  });

  describe('foundational agent duplicate event', () => {
    beforeEach(() => {
      isLoggedIn.mockReturnValue(true);
      createComponent({
        props: { item: mockFoundationalCatalogAgent },
        provide: { isGlobalNamespace: true },
      });
    });

    it('tracks the duplicate event with foundational agent properties', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findDuplicateButton().vm.$emit('action');
      await nextTick();

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM,
        {
          label: TRACK_EVENT_ITEM_TYPES[AI_CATALOG_TYPE_AGENT],
          origin: TRACK_EVENT_ORIGIN_EXPLORE,
          page: TRACK_EVENT_PAGE_SHOW,
          item_type: 'foundational_agent',
          item_version: '1.0.0',
          flow_name: 'chat',
          component_name: 'orbit_agent',
        },
        undefined,
      );
    });
  });
});
