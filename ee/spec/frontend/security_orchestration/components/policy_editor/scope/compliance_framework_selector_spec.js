import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlButton,
  GlCollapsibleListbox,
  GlListboxItem,
  GlModal,
  GlPopover,
  GlFormGroup,
} from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';
import ComplianceFrameworkSelector from 'ee/security_orchestration/components/policy_editor/scope/compliance_framework_selector.vue';
import getComplianceFrameworksForDropdownQuery from 'ee/security_orchestration/components/policy_editor/scope/graphql/get_compliance_frameworks_for_dropdown.query.graphql';
import ComplianceFrameworkFormModal from 'ee/groups/settings/compliance_frameworks/components/form_modal.vue';
import ProjectsCountMessage from 'ee/security_orchestration/components/shared/projects_count_message.vue';
import createComplianceFrameworkMutation from 'ee/groups/settings/compliance_frameworks/graphql/queries/create_compliance_framework.mutation.graphql';
import {
  validCreateResponse,
  mockPageInfo,
} from 'ee_jest/groups/settings/compliance_frameworks/mock_data';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';

describe('ComplianceFrameworkSelector', () => {
  let wrapper;
  let requestHandlers;

  const showMock = jest.fn();
  const hideMock = jest.fn();
  const openMock = jest.fn();

  const defaultNodes = [
    {
      id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 1),
      name: 'A1',
      default: true,
      description: 'description 1',
      color: '#cd5b45',
      namespaceId: 'gid://gitlab/Group/1',
    },
    {
      id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 2),
      name: 'B2',
      default: false,
      description: 'description 2',
      color: '#cd5b45',
      namespaceId: 'gid://gitlab/Group/1',
    },
    {
      id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 3),
      name: 'a3',
      default: true,
      description: 'description 3',
      color: '#cd5b45',
      namespaceId: 'gid://gitlab/Group/1',
    },
  ];

  const moreNodes = [
    ...defaultNodes,
    {
      id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 4),
      name: 'A4',
      default: true,
      description: 'description 4',
      color: '#cd5b45',
      namespaceId: 'gid://gitlab/Group/1',
    },
  ];

  const defaultNodesIds = defaultNodes.map(({ id }) => id);

  const mapItems = (items) =>
    items.map(({ id, name, ...framework }) => ({ value: id, text: name, ...framework }));

  const mockApolloHandlers = (nodes = defaultNodes, hasNextPage = false) => {
    return {
      complianceFrameworks: jest.fn().mockResolvedValue({
        data: {
          namespace: {
            id: 1,
            name: 'name',
            complianceFrameworks: {
              count: nodes.length,
              pageInfo: { ...mockPageInfo(), hasNextPage },
              nodes,
            },
          },
        },
      }),
      createFrameworkHandler: jest.fn().mockResolvedValue(validCreateResponse),
    };
  };

  const createMockApolloProvider = (handlers) => {
    Vue.use(VueApollo);

    requestHandlers = handlers;
    return createMockApollo([
      [getComplianceFrameworksForDropdownQuery, requestHandlers.complianceFrameworks],
      [createComplianceFrameworkMutation, requestHandlers.createFrameworkHandler],
    ]);
  };

  const createComponent = ({
    propsData = {},
    handlers = mockApolloHandlers(),
    stubs = {},
  } = {}) => {
    wrapper = shallowMountExtended(ComplianceFrameworkSelector, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        fullPath: 'gitlab-org',
        ...propsData,
      },
      stubs: {
        GlCollapsibleListbox: stubComponent(GlCollapsibleListbox, {
          template: `<div><slot name="footer"></slot></div>`,
          methods: {
            open: openMock,
          },
        }),
        ComplianceFrameworkFormModal,
        GlModal: stubComponent(GlModal, {
          methods: {
            show: showMock,
            hide: hideMock,
          },
        }),
        ...stubs,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateFrameworkButton = () => wrapper.findComponent(GlButton);
  const findGlFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findComplianceFrameworkFormModal = () =>
    wrapper.findComponent(ComplianceFrameworkFormModal);
  const selectAll = () => findDropdown().vm.$emit('select-all');
  const resetAll = () => findDropdown().vm.$emit('reset');
  const findAllPopovers = () => wrapper.findAllComponents(GlPopover);
  const findProjectsCountMessage = () => wrapper.findComponent(ProjectsCountMessage);

  describe('without selected frameworks', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should render loading state', () => {
      expect(findDropdown().props('loading')).toBe(true);
    });

    it('should load compliance framework', async () => {
      await waitForPromises();
      expect(findDropdown().props('loading')).toBe(false);
      expect(findDropdown().props('items')).toEqual(mapItems(defaultNodes));
    });

    it('should select framework ids', async () => {
      const [{ id }] = defaultNodes;

      await waitForPromises();
      findDropdown().vm.$emit('select', [id]);
      expect(wrapper.emitted('select')).toEqual([[[getIdFromGraphQLId(id)]]]);
    });

    it('should select all frameworks', async () => {
      await waitForPromises();
      selectAll();
      expect(wrapper.emitted('select')).toEqual([
        [defaultNodesIds.map((id) => getIdFromGraphQLId(id))],
      ]);
    });

    it('renders default text when loading', () => {
      expect(findDropdown().props('toggleText')).toBe('Select compliance frameworks');
    });

    it('does not render footer with count by default', () => {
      expect(findProjectsCountMessage().exists()).toBe(false);
    });

    it('should search frameworks despite case', async () => {
      await waitForPromises();

      expect(findDropdown().props('items')).toHaveLength(3);

      await findDropdown().vm.$emit('search', 'a');
      expect(findDropdown().props('items')).toEqual(mapItems([defaultNodes[0], defaultNodes[2]]));
      expect(findDropdown().props('items')).toHaveLength(2);
    });

    it('should render framework create form', () => {
      findCreateFrameworkButton().vm.$emit('click');

      expect(showMock).toHaveBeenCalled();
      findComplianceFrameworkFormModal().vm.$emit('change');

      expect(hideMock).toHaveBeenCalled();
      expect(openMock).toHaveBeenCalled();
    });
  });

  describe('popover with project list', () => {
    it('renders popover with projects list', async () => {
      createComponent({
        stubs: {
          GlCollapsibleListbox,
        },
      });

      await waitForPromises();

      expect(findAllPopovers().at(0).props('title')).toBe('A1');
      expect(findAllPopovers().at(1).props('title')).toBe('B2');
      expect(findAllPopovers().at(2).props('title')).toBe('a3');
    });
  });

  describe('create new framework', () => {
    it('re-fetches compliance frameworks when a new one is created', async () => {
      createComponent({});
      expect(requestHandlers.complianceFrameworks).toHaveBeenCalledTimes(1);

      jest.spyOn(wrapper.vm.$apollo.queries.complianceFrameworks, 'refetch');
      findComplianceFrameworkFormModal().vm.$emit('change');
      await waitForPromises();
      expect(wrapper.vm.$apollo.queries.complianceFrameworks.refetch).toHaveBeenCalled();
    });
  });

  describe('compliance framework list is empty', () => {
    it('renders default text when no frameworks were fetched', async () => {
      createComponent({
        handlers: mockApolloHandlers([]),
      });
      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('Select compliance frameworks');
    });
  });

  describe('selected frameworks', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selectedFrameworkIds: defaultNodesIds,
        },
      });
    });

    it('should be possible to preselect frameworks', async () => {
      await waitForPromises();
      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);
    });

    it('renders all frameworks selected text', async () => {
      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('A1, B2 +1 more');
    });

    it('should reset all frameworks', async () => {
      await waitForPromises();
      resetAll();

      expect(wrapper.emitted('select')).toEqual([[[]]]);
    });
  });

  describe('selected frameworks that does not exist', () => {
    it('renders default placeholder when selected frameworks do not exist', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: ['one', 'two'],
        },
      });

      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('Select compliance frameworks');
    });

    it('filters selected frameworks that does not exist', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: ['one', 'two'],
        },
      });

      await waitForPromises();
      findDropdown().vm.$emit('select', [defaultNodesIds[0]]);

      expect(wrapper.emitted('select')).toEqual([[[getIdFromGraphQLId(defaultNodesIds[0])]]]);
    });
  });

  describe('one selected project', () => {
    it('should render text for selected framework', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: [defaultNodesIds[0]],
        },
      });

      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe(defaultNodes[0].name);
    });
  });

  describe('when the fetch query throws an error', () => {
    it('emits an error event', async () => {
      createComponent({
        handlers: {
          complianceFrameworks: jest.fn().mockRejectedValue({}),
        },
      });
      await waitForPromises();
      expect(wrapper.emitted('framework-query-error')).toHaveLength(1);
    });
  });

  describe('when query response has no frameworks', () => {
    it('emits error when query does not return frameworks', async () => {
      createComponent({
        handlers: {
          complianceFrameworks: jest.fn().mockResolvedValue({
            data: {
              namespace: {
                id: 1,
                name: 'name',
              },
            },
          }),
        },
      });
      await waitForPromises();
      expect(wrapper.emitted('framework-query-error')).toHaveLength(1);
    });
  });

  describe('error state', () => {
    it.each`
      showError | variant      | category       | groupErrorAttribute
      ${false}  | ${'default'} | ${'primary'}   | ${'true'}
      ${true}   | ${'danger'}  | ${'secondary'} | ${null}
    `(
      `should render variant $variant and category $category when showError is $showError`,
      ({ showError, variant, category, groupErrorAttribute }) => {
        createComponent({
          propsData: {
            showError,
          },
        });

        expect(findGlFormGroup().element.getAttribute('state')).toBe(groupErrorAttribute);
        expect(findDropdown().props('variant')).toBe(variant);
        expect(findDropdown().props('category')).toBe(category);
      },
    );
  });

  describe('full id format', () => {
    it('should emit full format of id', async () => {
      createComponent({
        propsData: {
          useShortIdFormat: false,
        },
      });

      await waitForPromises();
      selectAll();

      expect(wrapper.emitted('select')).toEqual([[defaultNodesIds]]);
    });

    it('should render selected ids in full format', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: defaultNodesIds,
          useShortIdFormat: false,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);
    });
  });

  describe('infinite scroll', () => {
    it('fetches more frameworks when bottom is reached with correct cursor', async () => {
      createComponent({
        handlers: mockApolloHandlers(defaultNodes, true),
      });

      await waitForPromises();

      const initialItemCount = findDropdown().props('items').length;
      expect(initialItemCount).toBe(3);

      findDropdown().vm.$emit('bottom-reached');

      expect(requestHandlers.complianceFrameworks).toHaveBeenCalledTimes(2);
      expect(requestHandlers.complianceFrameworks).toHaveBeenNthCalledWith(2, {
        after: mockPageInfo().endCursor,
        fullPath: 'gitlab-org',
        ids: null,
        search: '',
        withCount: false,
      });
    });
  });

  describe('selection after search', () => {
    it('should add frameworks to existing selection after search', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: defaultNodesIds,
        },
        handlers: mockApolloHandlers(moreNodes),
        stubs: {
          GlCollapsibleListbox,
          GlListboxItem,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);

      findDropdown().vm.$emit('search', '4');
      await waitForPromises();

      expect(requestHandlers.complianceFrameworks).toHaveBeenCalledTimes(2);
      expect(requestHandlers.complianceFrameworks).toHaveBeenNthCalledWith(2, {
        search: '4',
        fullPath: 'gitlab-org',
        ids: null,
        withCount: false,
      });

      await waitForPromises();

      await wrapper
        .findComponentByTestId(`listbox-item-${moreNodes[3].id}`)
        .vm.$emit('select', true);

      expect(wrapper.emitted('select')).toEqual([[[1, 2, 3, 4]]]);
    });
  });

  describe('missing frameworks', () => {
    it('loads frameworks if they were selected but missing from first loaded page', async () => {
      createComponent({
        propsData: { selectedFrameworkIds: [4] },
      });
      await waitForPromises();

      expect(requestHandlers.complianceFrameworks).toHaveBeenNthCalledWith(2, {
        fullPath: 'gitlab-org',
        ids: [moreNodes[3].id],
        withCount: false,
      });
    });
  });

  describe('footer with count', () => {
    it('renders footer with items count', async () => {
      createComponent({
        propsData: {
          withItemsCount: true,
        },
      });
      await waitForPromises();

      expect(findProjectsCountMessage().exists()).toBe(true);
      expect(findProjectsCountMessage().props('count')).toBe(defaultNodes.length);
      expect(findProjectsCountMessage().props('totalCount')).toBe(defaultNodes.length);
      expect(findProjectsCountMessage().props('infoText')).toBe('frameworks');
      expect(findProjectsCountMessage().props('showInfoIcon')).toBe(false);
    });
  });
});
