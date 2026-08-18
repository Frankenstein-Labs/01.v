import { GlButton, GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import FrameworksNeedsAttention from 'ee/compliance_dashboard/components/dashboard/frameworks_needs_attention.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';

describe('FrameworksNeedsAttention', () => {
  let wrapper;

  const GROUP_PATH = 'test-group';
  const GROUP_SECURITY_POLICIES_PATH = `/groups/${GROUP_PATH}/-/security/policies`;
  const PARENT_GROUP_PATH = 'parent-group';

  const mockFrameworks = [
    {
      id: 'gid://gitlab/ComplianceFramework/1',
      framework: {
        id: 'gid://gitlab/ComplianceFramework/1',
        name: 'SOX Framework',
        color: '#ff0000',
        securityPolicies: {
          nodes: [
            {
              name: 'Scan Policy 1',
              type: 'scan_execution_policy',
              source: { namespace: { id: 'gid://gitlab/Group/1', fullPath: GROUP_PATH } },
            },
            {
              name: 'VM Policy 1',
              type: 'vulnerability_management_policy',
              source: { namespace: { id: 'gid://gitlab/Group/2', fullPath: PARENT_GROUP_PATH } },
            },
          ],
        },
      },
      projectsCount: 5,
      requirementsCount: 10,
      requirementsWithoutControls: [
        { id: 'req1', name: 'Requirement 1' },
        { id: 'req2', name: 'Requirement 2' },
      ],
    },
    {
      id: 'gid://gitlab/ComplianceFramework/2',
      framework: {
        id: 'gid://gitlab/ComplianceFramework/2',
        name: 'PCI Framework',
        color: '#00ff00',
        securityPolicies: { nodes: [] },
      },
      projectsCount: 0,
      requirementsCount: 0,
      requirementsWithoutControls: [],
    },
  ];

  const defaultProps = { frameworks: mockFrameworks };

  const defaultProvide = {
    groupPath: GROUP_PATH,
    groupSecurityPoliciesPath: GROUP_SECURITY_POLICIES_PATH,
  };

  const findHeaders = () => wrapper.findAll('thead th');
  const findTableRow = (index) => wrapper.findAll('tbody tr').at(index);

  const createComponent = (props = {}, provide = {}, glAbilities = {}) => {
    wrapper = mount(FrameworksNeedsAttention, {
      propsData: { ...defaultProps, ...props },
      provide: {
        ...defaultProvide,
        ...provide,
        glAbilities: { adminComplianceFramework: true, ...glAbilities },
      },
      mocks: { $router: { push: jest.fn() } },
      stubs: { FrameworkBadge },
    });
  };

  describe('permissions', () => {
    it('includes actions column when user can admin compliance framework', () => {
      createComponent();
      expect(findHeaders().at(5).text()).toBe('Actions');
    });

    it('excludes actions column when user cannot admin compliance framework', () => {
      createComponent({}, {}, { adminComplianceFramework: false });
      const headers = findHeaders();
      expect(headers).toHaveLength(5);
      expect(headers.wrappers.every((h) => h.text() !== 'Actions')).toBe(true);
    });
  });

  describe('cells rendering', () => {
    beforeEach(() => createComponent());

    it('renders FrameworkBadge in framework column', () => {
      const badge = findTableRow(0).findAll('td').at(0).findComponent(FrameworkBadge);
      expect(badge.exists()).toBe(true);
      expect(badge.props('framework')).toEqual(mockFrameworks[0].framework);
      expect(badge.props('popoverMode')).toBe('hidden');
    });
  });

  describe('projects count cell rendering', () => {
    beforeEach(() => createComponent());

    it('renders project count with danger styling when count is 0', () => {
      const dangerSpan = findTableRow(1).findAll('td').at(1).find('span.gl-text-danger');
      expect(dangerSpan.exists()).toBe(true);
      expect(dangerSpan.classes()).toContain('gl-font-bold');
      expect(dangerSpan.text()).toBe('0');
    });

    it('renders project count normally when count is greater than 0', () => {
      const cell = findTableRow(0).findAll('td').at(1);
      expect(cell.find('span.gl-text-danger').exists()).toBe(false);
      expect(cell.text()).toBe('5');
    });
  });

  describe('requirements count cell rendering', () => {
    beforeEach(() => createComponent());

    it('renders requirements count with danger styling when count is 0', () => {
      const dangerSpan = findTableRow(1).findAll('td').at(2).find('span.gl-text-danger');
      expect(dangerSpan.exists()).toBe(true);
      expect(dangerSpan.classes()).toContain('gl-font-bold');
      expect(dangerSpan.text()).toBe('0');
    });

    it('renders requirements count normally when count is greater than 0', () => {
      const cell = findTableRow(0).findAll('td').at(2);
      expect(cell.find('span.gl-text-danger').exists()).toBe(false);
      expect(cell.text()).toBe('10');
    });
  });

  describe('requirements without controls cell rendering', () => {
    beforeEach(() => createComponent());

    it('renders dash when no requirements without controls', () => {
      expect(findTableRow(1).findAll('td').at(3).text()).toBe('-');
    });

    it('renders list of requirements when present', () => {
      const list = findTableRow(0).findAll('td').at(3).find('ul');
      expect(list.exists()).toBe(true);
      expect(list.classes()).toContain('gl-pl-3');
      expect(list.classes()).toContain('gl-text-danger');

      const items = list.findAll('li');
      expect(items).toHaveLength(2);
      expect(items.at(0).text()).toBe('Requirement 1');
      expect(items.at(1).text()).toBe('Requirement 2');
    });

    it('applies proper CSS classes to column header', () => {
      const header = findHeaders().at(3);
      expect(header.classes()).toContain('@md/panel:gl-max-w-20');
      expect(header.classes()).toContain('gl-text-left');
    });

    it('applies proper CSS classes to table cells', () => {
      const cell = findTableRow(0).findAll('td').at(3);
      expect(cell.classes()).toContain('@md/panel:gl-max-w-20');
      expect(cell.classes()).toContain('gl-text-left');
    });
  });

  describe('policies cell rendering', () => {
    beforeEach(() => createComponent());

    it('renders dash when no policies', () => {
      const cell = findTableRow(1).findAll('td').at(4);
      expect(cell.text()).toBe('-');
      expect(cell.findAllComponents(GlLink)).toHaveLength(0);
    });

    it('renders a link for each policy', () => {
      const links = findTableRow(0).findAll('td').at(4).findAllComponents(GlLink);
      expect(links).toHaveLength(2);
      expect(links.at(0).text()).toBe('Scan Policy 1');
      expect(links.at(1).text()).toBe('VM Policy 1');
    });

    it('links to the policy edit page when the policy is from the current group', () => {
      const links = findTableRow(0).findAll('td').at(4).findAllComponents(GlLink);
      expect(links.at(0).attributes('href')).toBe(
        `${GROUP_SECURITY_POLICIES_PATH}/Scan Policy 1/edit?type=scan_execution_policy`,
      );
    });

    it('links to the source group policies page when the policy is from a different group', () => {
      const links = findTableRow(0).findAll('td').at(4).findAllComponents(GlLink);
      expect(links.at(1).attributes('href')).toBe(
        `/groups/${PARENT_GROUP_PATH}/-/security/policies`,
      );
    });

    it('falls back to the group security policies path when the source namespace is missing', () => {
      createComponent({
        frameworks: [
          {
            ...mockFrameworks[0],
            framework: {
              ...mockFrameworks[0].framework,
              securityPolicies: {
                nodes: [{ name: 'No Source Policy', type: 'scan_execution_policy', source: {} }],
              },
            },
          },
        ],
      });
      const link = findTableRow(0).findAll('td').at(4).findComponent(GlLink);
      expect(link.attributes('href')).toBe(GROUP_SECURITY_POLICIES_PATH);
    });
  });

  describe('actions cell rendering', () => {
    it('renders edit button when user can admin compliance framework', () => {
      createComponent();
      const button = findTableRow(0).findAll('td').at(5).findComponent(GlButton);
      expect(button.text()).toBe('Edit framework');
    });

    it('does not render actions cell when user cannot admin compliance framework', () => {
      createComponent({}, {}, { adminComplianceFramework: false });
      const cells = findTableRow(0).findAll('td');
      expect(cells).toHaveLength(5);
      expect(cells.wrappers.every((cell) => !cell.findComponent(GlButton).exists())).toBe(true);
    });
  });
});
