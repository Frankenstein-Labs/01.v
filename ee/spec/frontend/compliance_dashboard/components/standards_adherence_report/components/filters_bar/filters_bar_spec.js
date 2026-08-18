import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlDisclosureDropdown, GlFilteredSearch } from '@gitlab/ui';
import FiltersBar, {
  FILTERS,
} from 'ee/compliance_dashboard/components/standards_adherence_report/components/filters_bar/filters_bar.vue';
import { GROUP_BY } from 'ee/compliance_dashboard/components/standards_adherence_report/constants';
import complianceFrameworksInGroupQuery from 'ee/compliance_dashboard/components/standards_adherence_report/graphql/queries/compliance_frameworks_in_group.query.graphql';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const defaultFrameworks = [
  {
    id: 'gid://gitlab/ComplianceManagement::Framework/1',
    name: 'SOC 2',
    description: 'Service Organization Control 2 compliance framework',
    color: '#6699cc',
    default: true,
    complianceRequirements: {
      nodes: [
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/101',
          name: 'Security Monitoring',
          description: 'Continuous monitoring of security events',
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/102',
          name: 'Access Control',
          description: 'Policies and procedures for managing access',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/ComplianceManagement::Framework/2',
    name: 'GDPR',
    description: 'General Data Protection Regulation compliance framework',
    color: '#ff9900',
    default: false,
    complianceRequirements: {
      nodes: [
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/201',
          name: 'Data Protection',
          description: 'Measures to protect personal data',
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/202',
          name: 'Data Subject Rights',
          description: 'Processes to handle data subject requests',
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/203',
          name: 'Breach Notification',
          description: 'Procedures for data breach notification',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/ComplianceManagement::Framework/3',
    name: 'HIPAA',
    description: 'Health Insurance Portability and Accountability Act framework',
    color: '#33cc66',
    default: false,
    complianceRequirements: {
      nodes: [
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/301',
          name: 'PHI Security',
          description: 'Protection of personal health information',
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/302',
          name: 'Audit Controls',
          description: 'Implementation of audit controls',
        },
      ],
    },
  },
];

const createComplianceFrameworksInNamespaceMock = (nodes = defaultFrameworks) => ({
  data: {
    namespace: {
      id: 'gid://gitlab/Group/123',
      name: 'Example Group',
      complianceFrameworks: {
        nodes,
      },
    },
  },
});

describe('FiltersBar', () => {
  let wrapper;

  const createComponent = ({
    props = {},
    mountFn = shallowMountExtended,
    requestHandlers = [],
  } = {}) => {
    const apolloProvider = createMockApollo(requestHandlers);

    wrapper = mountFn(FiltersBar, {
      apolloProvider,
      propsData: {
        groupPath: 'group/path',
        ...props,
      },
    });

    return wrapper;
  };

  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findDropdownLabel = () => wrapper.findByTestId('dropdown-label');

  describe('rendering', () => {
    it('does not render anything when frameworks is empty', () => {
      createComponent({
        requestHandlers: [
          [
            complianceFrameworksInGroupQuery,
            jest.fn().mockResolvedValue(createComplianceFrameworksInNamespaceMock([])),
          ],
        ],
      });

      expect(wrapper.text()).toBe('');
    });

    it('renders the filters bar when frameworks are loaded', async () => {
      createComponent({
        requestHandlers: [
          [
            complianceFrameworksInGroupQuery,
            jest.fn().mockResolvedValue(createComplianceFrameworksInNamespaceMock()),
          ],
        ],
      });

      await waitForPromises();
      expect(wrapper.exists()).toBe(true);
    });

    it('does not show the group-by dropdown when withGroupBy is false', async () => {
      createComponent({
        props: { withGroupBy: false },
        requestHandlers: [
          [
            complianceFrameworksInGroupQuery,
            jest.fn().mockResolvedValue(createComplianceFrameworksInNamespaceMock()),
          ],
        ],
      });

      await waitForPromises();
      expect(findDropdownLabel().exists()).toBe(false);
    });

    it('shows the group-by dropdown when withGroupBy is true', async () => {
      createComponent({
        props: { withGroupBy: true },
        requestHandlers: [
          [
            complianceFrameworksInGroupQuery,
            jest.fn().mockResolvedValue(createComplianceFrameworksInNamespaceMock()),
          ],
        ],
      });

      await waitForPromises();
      expect(findDropdownLabel().exists()).toBe(true);
    });
  });

  describe('computed properties behavior', () => {
    let complianceFrameworksHandler;

    beforeEach(() => {
      complianceFrameworksHandler = jest
        .fn()
        .mockResolvedValue(createComplianceFrameworksInNamespaceMock());
    });

    it('computes dropdownItems without projects when withProjects is false', async () => {
      createComponent({
        props: { withProjects: false, withGroupBy: true },
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
      });

      await waitForPromises();

      const projectsItem = findDisclosureDropdown()
        .props('items')
        .find((item) => item.value === GROUP_BY.PROJECTS);

      expect(projectsItem).toBeUndefined();
    });

    it('computes dropdownItems with projects when withProjects is true', async () => {
      createComponent({
        props: { withProjects: true, withGroupBy: true },
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
        mountFn: mountExtended,
      });

      await waitForPromises();

      const projectsItem = findDisclosureDropdown()
        .props('items')
        .find((item) => item.value === GROUP_BY.PROJECTS);

      expect(projectsItem).toBeDefined();
    });

    it('correctly filters tokens based on groupBy prop', async () => {
      createComponent({
        props: { groupBy: GROUP_BY.FRAMEWORKS },
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
        mountFn: mountExtended,
      });

      await waitForPromises();

      const availableTokens = findFilteredSearch().props('availableTokens');
      const frameworkToken = availableTokens.find(
        (token) => token.type === FILTERS[GROUP_BY.FRAMEWORKS],
      );

      expect(frameworkToken).toBeUndefined();
    });
  });

  describe('event handling', () => {
    let complianceFrameworksHandler;

    beforeEach(() => {
      complianceFrameworksHandler = jest
        .fn()
        .mockResolvedValue(createComplianceFrameworksInNamespaceMock());
    });

    it('emits update:groupBy when a group is selected', async () => {
      createComponent({
        props: { withGroupBy: true },
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
      });

      await waitForPromises();
      findDisclosureDropdown().vm.$emit('action', { value: GROUP_BY.REQUIREMENTS });

      expect(wrapper.emitted('update:groupBy')[0]).toEqual([GROUP_BY.REQUIREMENTS]);
    });

    it('emits update:filters when filters are submitted', async () => {
      createComponent({
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
      });

      await waitForPromises();

      const filterValue = [{ type: FILTERS[GROUP_BY.REQUIREMENTS], value: { data: 'req-1' } }];

      findFilteredSearch().vm.$emit('submit', filterValue);

      expect(wrapper.emitted('update:filters')[0]).toEqual([
        { [FILTERS[GROUP_BY.REQUIREMENTS]]: 'req-1' },
      ]);
    });

    it('emits empty object when filters are cleared', async () => {
      createComponent({
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
      });

      await waitForPromises();
      findFilteredSearch().vm.$emit('clear');

      expect(wrapper.emitted('update:filters')[0]).toEqual([{}]);
    });

    it('emits load event when frameworks are loaded', async () => {
      createComponent({
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
      });

      await waitForPromises();

      expect(wrapper.emitted('load')).toBeDefined();
    });

    it('filters selectedTokens when groupBy changes', async () => {
      createComponent({
        props: { groupBy: GROUP_BY.FRAMEWORKS, withGroupBy: true },
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
      });

      await waitForPromises();

      const filterValue = [
        { type: FILTERS[GROUP_BY.REQUIREMENTS], value: { data: 'req-1' } },
        { type: FILTERS[GROUP_BY.PROJECTS], value: { data: 'project-1' } },
      ];

      findFilteredSearch().vm.$emit('submit', filterValue);
      findDisclosureDropdown().vm.$emit('action', { value: GROUP_BY.REQUIREMENTS });
      await nextTick();

      const lastEmit = wrapper.emitted('update:filters').pop();
      expect(lastEmit[0]).toEqual({
        [FILTERS[GROUP_BY.PROJECTS]]: 'project-1',
      });
    });
  });

  describe('apollo integration', () => {
    it('calls query with correct variables', async () => {
      const complianceFrameworksHandler = jest
        .fn()
        .mockResolvedValue(createComplianceFrameworksInNamespaceMock());

      createComponent({
        props: { groupPath: 'test/group' },
        requestHandlers: [[complianceFrameworksInGroupQuery, complianceFrameworksHandler]],
      });

      await waitForPromises();

      expect(complianceFrameworksHandler).toHaveBeenCalledWith({
        fullPath: 'test/group',
      });
    });

    it('extracts requirements from frameworks response', async () => {
      createComponent({
        requestHandlers: [
          [
            complianceFrameworksInGroupQuery,
            jest.fn().mockResolvedValue(createComplianceFrameworksInNamespaceMock()),
          ],
        ],
        mountFn: mountExtended,
      });

      await waitForPromises();

      const requirementToken = findFilteredSearch()
        .props('availableTokens')
        .find((t) => t.type === FILTERS[GROUP_BY.REQUIREMENTS]);

      const mockRequirementNames = defaultFrameworks.flatMap((f) =>
        f.complianceRequirements.nodes.map((r) => r.name),
      );
      expect(requirementToken.requirements.map((r) => r.name)).toStrictEqual(mockRequirementNames);
    });
  });
});
