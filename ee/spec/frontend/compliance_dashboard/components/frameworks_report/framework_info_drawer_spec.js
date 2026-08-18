import {
  GlBadge,
  GlLabel,
  GlButton,
  GlLink,
  GlPopover,
  GlSprintf,
  GlLoadingIcon,
  GlDrawer,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import FrameworkInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/framework_info_drawer.vue';
import projectsInNamespaceWithFrameworkQuery from 'ee/compliance_dashboard/components/frameworks_report/graphql/projects_in_namespace_with_framework.query.graphql';
import complianceRequirementControlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import { shallowMountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import {
  createFramework,
  mockPageInfo,
  mockRequirements,
  mockInternalControls,
  mockExternalControl,
} from 'ee_jest/compliance_dashboard/mock_data';
import { DOCS_URL } from '~/constants';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import DrawerAccordion from 'ee/compliance_dashboard/components/shared/drawer_accordion.vue';

jest.mock('~/lib/utils/copy_to_clipboard', () => ({
  copyToClipboard: jest.fn().mockResolvedValue(),
}));

Vue.use(VueApollo);

describe('FrameworkInfoDrawer component', () => {
  let wrapper;

  function createMockApolloProvider({
    projectsInNamespaceResolverMock,
    complianceRequirementControlsResolverMock = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: [...mockInternalControls, mockExternalControl],
        },
      },
    }),
  }) {
    return createMockApollo([
      [projectsInNamespaceWithFrameworkQuery, projectsInNamespaceResolverMock],
      [complianceRequirementControlsQuery, complianceRequirementControlsResolverMock],
    ]);
  }

  const $toast = {
    show: jest.fn(),
  };

  const GROUP_PATH = 'foo';
  const EXPECTED_REQUIREMENTS_COUNT = 3;

  const defaultFramework = createFramework({
    id: 1,
    isDefault: true,
    projects: 3,
    complianceRequirements: { nodes: mockRequirements },
  });

  const nonDefaultFramework = createFramework({
    id: 2,
    complianceRequirements: { nodes: [] },
  });

  const policiesCount = defaultFramework.securityPolicies.nodes.length;

  const findDefaultBadge = () => wrapper.findComponent(GlLabel);
  const findTitle = () => wrapper.findByTestId('framework-name');
  const findEditFrameworkBtn = () => wrapper.findComponentByTestId('edit-framework-btn');

  const findIdSection = () => wrapper.findByTestId('sidebar-id');
  const findIdSectionTitle = () => wrapper.findByTestId('sidebar-id-title');
  const findFrameworkId = () => wrapper.findByTestId('framework-id');
  const findFrameworkCopyIdButton = () => findIdSection().findComponent(GlButton);
  const findIdPopover = () => findIdSection().findComponent(GlPopover);

  const findDescriptionTitle = () => wrapper.findByTestId('sidebar-description-title');
  const findDescription = () => wrapper.findByTestId('sidebar-description');

  const findRequirementsSection = () => wrapper.findByTestId('requirements');
  const findRequirementsTitle = () => wrapper.findByTestId('sidebar-requirements-title');
  const findRequirementsCount = () => wrapper.findByTestId('requirements-count-badge');
  const findRequirementsAccordion = () => findRequirementsSection().findComponent(DrawerAccordion);
  const findExternalControlBadges = () =>
    wrapper.findAllComponents(GlBadge).filter((badge) => badge.text() === 'External');
  const findCopyControlIdButton = () => wrapper.findAllComponentsByTestId('copy-control-id-button');
  const findProjectsTitle = () => wrapper.findByTestId('sidebar-projects-title');
  const findProjectsLinks = () =>
    wrapper.findByTestId('sidebar-projects').findAllComponents(GlLink);
  const findLoadMoreButton = () =>
    extendedWrapper(wrapper.findByTestId('sidebar-projects')).findByText('Load more');
  const findProjectsCount = () => wrapper.findByTestId('sidebar-projects').findComponent(GlBadge);
  const findPoliciesTitle = () => wrapper.findByTestId('sidebar-policies-title');
  const findPoliciesLinks = () =>
    wrapper.findByTestId('sidebar-policies').findAllComponents(GlLink);
  const findPoliciesCount = () => wrapper.findByTestId('sidebar-policies').findComponent(GlBadge);
  const findPopover = () => wrapper.findByTestId('edit-framework-popover');

  const pendingPromiseMock = jest.fn().mockResolvedValue(new Promise(() => {}));

  const createComponent = ({
    props = {},
    provide = {},
    projectsInNamespaceResolverMock = pendingPromiseMock,
    complianceRequirementControlsResolverMock = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: [...mockInternalControls, mockExternalControl],
        },
      },
    }),
  } = {}) => {
    const apolloProvider = createMockApolloProvider({
      projectsInNamespaceResolverMock,
      complianceRequirementControlsResolverMock,
    });

    wrapper = shallowMountExtended(FrameworkInfoDrawer, {
      apolloProvider,
      propsData: {
        showDrawer: true,
        ...props,
      },
      stubs: {
        GlSprintf,
        GlButton,
        BButton: false,
        DrawerAccordion,
      },
      provide: {
        groupSecurityPoliciesPath: '/group-policies',
        canAccessRootAncestorComplianceCenter: true,
        ...provide,
      },
      mocks: {
        $toast,
      },
    });
  };

  describe('default framework display', () => {
    beforeEach(() => {
      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
      });
    });

    describe('for drawer body content', () => {
      it('renders the title', () => {
        expect(findTitle().text()).toBe(defaultFramework.name);
      });

      it('renders the default badge', () => {
        expect(findDefaultBadge().exists()).toBe(true);
      });

      it('renders the edit framework button', () => {
        expect(findEditFrameworkBtn().exists()).toBe(true);
      });

      it('renders the ID accordion', () => {
        expect(findIdSectionTitle().text()).toBe('Compliance framework ID');
      });

      it('renders popover with a help link', () => {
        expect(findIdPopover().props('title')).toBe('Using the ID');
        expect(findIdPopover().text()).toMatchInterpolatedText(
          'Use the compliance framework ID in configuration or API requests. Learn more.',
        );
        expect(findIdPopover().findComponent(GlLink).attributes('href')).toBe(
          `${DOCS_URL}/user/application_security/policies/_index.html#scope`,
        );
      });

      it('renders the ID of the framework', () => {
        expect(findFrameworkId().text()).toBe('1');
      });

      it('renders the copy ID button', () => {
        expect(findFrameworkCopyIdButton().text()).toBe('Copy ID');
      });

      it('calls copyFrameworkIdToClipboard method when copy button is clicked', async () => {
        await findFrameworkCopyIdButton().vm.$emit('click');
        await waitForPromises();
        expect(copyToClipboard).toHaveBeenCalledWith('1');
        expect($toast.show).toHaveBeenCalledWith('Framework ID copied to clipboard.');
      });

      it('renders the Description accordion', () => {
        expect(findDescriptionTitle().text()).toBe(`Description`);
        expect(findDescription().text()).toBe(defaultFramework.description);
      });

      it('renders the Associated Projects accordion', () => {
        expect(findProjectsTitle().text()).toBe(`Associated Projects`);
      });

      it('renders the Associated Projects count badge as loading', () => {
        expect(findProjectsCount().findComponent(GlLoadingIcon).exists()).toBe(true);
      });

      describe('Associated projects list when loaded', () => {
        const TOTAL_COUNT = 30;
        const makeProjectsListResponse = ({ pageInfo = mockPageInfo() } = {}) => {
          return {
            namespace: {
              __typename: 'Group',
              id: 'gid://gitlab/Group/1',
              projects: {
                ...defaultFramework.projects,
                count: TOTAL_COUNT,
                pageInfo,
              },
            },
          };
        };

        let projectsInNamespaceResolverMock;
        beforeEach(() => {
          projectsInNamespaceResolverMock = jest.fn().mockResolvedValue({
            data: makeProjectsListResponse(),
          });

          createComponent({
            projectsInNamespaceResolverMock,
            props: {
              groupPath: GROUP_PATH,
              rootAncestor: {
                path: GROUP_PATH,
              },
              framework: defaultFramework,
            },
          });

          return waitForPromises();
        });

        it('renders the Associated Projects count', () => {
          expect(findProjectsCount().text()).toBe(`${TOTAL_COUNT}`);
        });

        it('renders the Associated Projects list', () => {
          expect(findProjectsLinks().wrappers).toHaveLength(3);
          expect(findProjectsLinks().at(0).text()).toContain(
            defaultFramework.projects.nodes[0].name,
          );
          expect(findProjectsLinks().at(0).attributes('href')).toBe(
            defaultFramework.projects.nodes[0].webUrl,
          );
        });

        describe('load more button', () => {
          const secondPageResponse = makeProjectsListResponse();
          secondPageResponse.namespace.projects.nodes =
            secondPageResponse.namespace.projects.nodes.map((node) => ({
              ...node,
              id: `gid://gitlab/Project/${node.id}-page-2`,
            }));

          beforeEach(() => {});
          it('renders when we have next page in list', () => {
            expect(findLoadMoreButton().exists()).toBe(true);
          });

          it('clicking button loads next page', async () => {
            projectsInNamespaceResolverMock.mockResolvedValueOnce({
              data: secondPageResponse,
            });
            await findLoadMoreButton().trigger('click');
            await waitForPromises();
            expect(projectsInNamespaceResolverMock).toHaveBeenCalledWith(
              expect.objectContaining({
                after: mockPageInfo().endCursor,
              }),
            );
          });

          it('does not render when we do not have next page', async () => {
            secondPageResponse.namespace.projects.pageInfo.hasNextPage = false;

            createComponent({
              projectsInNamespaceResolverMock: jest.fn().mockResolvedValue({
                data: secondPageResponse,
              }),
              props: {
                groupPath: GROUP_PATH,
                rootAncestor: {
                  path: GROUP_PATH,
                },
                framework: defaultFramework,
              },
            });

            await waitForPromises();
            expect(findLoadMoreButton().exists()).toBe(false);
          });
        });
      });

      it('renders the Policies accordion', () => {
        expect(findPoliciesTitle().text()).toBe(`Policies`);
      });

      it('renders the Policies count', () => {
        expect(findPoliciesCount().text()).toBe(`${policiesCount}`);
      });

      it('renders the Policies list', () => {
        expect(findPoliciesLinks().wrappers).toHaveLength(policiesCount);
        expect(findPoliciesLinks().at(0).attributes('href')).toBe(
          `/groups/bar/-/security/policies`,
        );
        const inGroupApprovalPolicy = defaultFramework.securityPolicies.nodes.find(
          (p) => p.type === 'approval_policy' && p.source.namespace.fullPath === GROUP_PATH,
        );
        expect(findPoliciesLinks().at(1).attributes('href')).toBe(
          `/group-policies/${inGroupApprovalPolicy.name}/edit?type=approval_policy`,
        );
      });

      it('does not render edit button popover', () => {
        expect(findPopover().exists()).toBe(false);
      });
    });
  });

  describe('requirements display', () => {
    beforeEach(async () => {
      const frameworkWithRequirements = {
        ...defaultFramework,
        complianceRequirements: {
          nodes: mockRequirements,
        },
      };

      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: frameworkWithRequirements,
        },
      });

      await waitForPromises();
    });

    it('renders the requirements title', () => {
      expect(findRequirementsTitle().text()).toBe('Requirements');
    });

    it('renders the requirements count', () => {
      expect(findRequirementsCount().text()).toBe(EXPECTED_REQUIREMENTS_COUNT.toString());
    });

    it('renders the requirements accordion when requirements exist', () => {
      const accordion = findRequirementsAccordion();
      expect(accordion.exists()).toBe(true);
    });

    it('displays requirement descriptions correctly', () => {
      const accordion = findRequirementsAccordion();
      expect(accordion.props('items')).toEqual(mockRequirements);
    });
  });

  describe('requirements with controls', () => {
    beforeEach(async () => {
      const frameworkWithRequirements = {
        ...defaultFramework,
        complianceRequirements: {
          nodes: mockRequirements,
        },
      };

      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: frameworkWithRequirements,
        },
      });

      await waitForPromises();
    });

    it('displays external control badge for external controls', () => {
      const badges = findExternalControlBadges();
      expect(badges.length).toBeGreaterThan(0);
    });

    it('displays copy control ID button for external controls', () => {
      const copyControlIdButton = findCopyControlIdButton();
      expect(copyControlIdButton.exists()).toBe(true);
      expect(copyControlIdButton.at(0).text()).toBe('Copy ID');
    });

    it('calls copyControlIdToClipboard method when copy button is clicked', async () => {
      await findCopyControlIdButton().at(0).vm.$emit('click');
      await waitForPromises();
      expect(copyToClipboard).toHaveBeenCalledWith('3');
      expect($toast.show).toHaveBeenCalledWith('Control ID copied to clipboard.');
    });

    it('displays internal controls correctly', () => {
      expect(findExternalControlBadges()).toHaveLength(1);
      expect(findCopyControlIdButton()).toHaveLength(1);
    });
  });

  describe('requirements loading state', () => {
    it('shows loading icon when controls are being fetched', () => {
      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
        complianceRequirementControlsResolverMock: pendingPromiseMock,
      });

      expect(findRequirementsCount().findComponent(GlLoadingIcon).exists()).toBe(true);
    });
  });

  describe('framework without requirements', () => {
    beforeEach(async () => {
      const frameworkWithoutRequirements = {
        ...defaultFramework,
        complianceRequirements: { nodes: [] },
      };

      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: frameworkWithoutRequirements,
        },
      });

      await waitForPromises();
    });

    it('shows the requirements section with count of zero', () => {
      expect(findRequirementsSection().exists()).toBe(true);
      expect(findRequirementsCount().text()).toBe('0');
    });

    it('should render an empty requirements accordion', () => {
      const accordion = findRequirementsAccordion();
      expect(accordion.exists()).toBe(true);
      expect(accordion.props('items')).toEqual([]);
    });
  });

  describe('framework display', () => {
    beforeEach(() => {
      createComponent({
        props: {
          framework: nonDefaultFramework,
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
        },
      });
    });

    describe('for drawer body content', () => {
      it('does not renders the default badge', () => {
        expect(findDefaultBadge().exists()).toBe(false);
      });
    });
  });

  describe('when viewing framework in a subgroup', () => {
    beforeEach(() => {
      createComponent({
        props: {
          groupPath: `${GROUP_PATH}/child`,
          rootAncestor: {
            path: GROUP_PATH,
            webUrl: `/web/${GROUP_PATH}`,
            name: 'Root',
          },
          framework: defaultFramework,
        },
      });
    });

    it('renders disabled edit framework button', () => {
      expect(findEditFrameworkBtn().props('disabled')).toBe(true);
    });

    it('renders popover', () => {
      expect(findPopover().text()).toMatchInterpolatedText(
        'You must edit the compliance framework in top-level group Root',
      );
    });

    it('shows additional info when user does not have access to top-level group', () => {
      createComponent({
        props: {
          groupPath: `${GROUP_PATH}/child`,
          rootAncestor: {
            path: GROUP_PATH,
            webUrl: `/web/${GROUP_PATH}`,
            name: 'Root',
          },
          framework: defaultFramework,
        },
        provide: { canAccessRootAncestorComplianceCenter: false },
      });

      expect(findPopover().text()).toMatchInterpolatedText(
        'You must have the Owner role for the top-level group Root',
      );
    });
  });

  it('does not render associated projects when they are not provided', () => {
    createComponent({
      props: {
        groupPath: GROUP_PATH,
        rootAncestor: {
          path: GROUP_PATH,
        },
        framework: { ...defaultFramework, projects: null },
      },
    });

    expect(findProjectsTitle().exists()).toBe(false);
  });

  describe('framework watcher functionality', () => {
    let projectsInNamespaceResolverMock;

    const makeProjectsListResponse = ({
      pageInfo = mockPageInfo(),
      count = 30,
      nodes = defaultFramework.projects.nodes,
    } = {}) => {
      return {
        namespace: {
          __typename: 'Group',
          id: 'gid://gitlab/Group/1',
          projects: {
            nodes,
            count,
            pageInfo,
          },
        },
      };
    };

    beforeEach(() => {
      projectsInNamespaceResolverMock = jest.fn().mockResolvedValue({
        data: makeProjectsListResponse(),
      });
    });

    it('resets projects display when framework changes', async () => {
      createComponent({
        projectsInNamespaceResolverMock,
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
      });

      await waitForPromises();

      expect(findProjectsLinks()).toHaveLength(3);
      expect(findProjectsCount().text()).toBe('30');
      expect(findLoadMoreButton().exists()).toBe(true);

      const newFramework = createFramework({ id: 999, name: 'New Framework' });

      projectsInNamespaceResolverMock.mockResolvedValueOnce({
        data: makeProjectsListResponse(),
      });

      await wrapper.setProps({ framework: newFramework });
      await waitForPromises();

      expect(findProjectsLinks()).toHaveLength(3);
      expect(findProjectsCount().text()).toBe('30');
      expect(findLoadMoreButton().exists()).toBe(true);

      expect(projectsInNamespaceResolverMock).toHaveBeenLastCalledWith(
        expect.objectContaining({
          frameworkId: 'gid://gitlab/ComplianceManagement::Framework/999',
        }),
      );
    });

    it('maintains projects display when the same framework is set', async () => {
      createComponent({
        projectsInNamespaceResolverMock,
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
      });

      await waitForPromises();

      const initialProjectsCount = findProjectsLinks().length;
      const initialCountText = findProjectsCount().text();
      const initialLoadMoreExists = findLoadMoreButton().exists();

      const callCountBeforeSet = projectsInNamespaceResolverMock.mock.calls.length;

      await wrapper.setProps({ framework: { ...defaultFramework } });

      await Vue.nextTick();

      expect(findProjectsLinks()).toHaveLength(initialProjectsCount);
      expect(findLoadMoreButton().exists()).toBe(initialLoadMoreExists);
      expect(findProjectsCount().text()).toBe(initialCountText);

      expect(projectsInNamespaceResolverMock.mock.calls).toHaveLength(callCountBeforeSet);
    });

    it('handles framework change from null to a framework', async () => {
      createComponent({
        projectsInNamespaceResolverMock,
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: null,
        },
      });

      expect(findProjectsTitle().exists()).toBe(false);

      await wrapper.setProps({ framework: defaultFramework });
      await waitForPromises();

      expect(findProjectsTitle().exists()).toBe(true);
      expect(findProjectsLinks()).toHaveLength(3);
      expect(findProjectsCount().text()).toBe('30');
      expect(findLoadMoreButton().exists()).toBe(true);
    });

    it('handles framework change from a framework to null', async () => {
      createComponent({
        projectsInNamespaceResolverMock,
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
      });

      await waitForPromises();

      expect(findProjectsTitle().exists()).toBe(true);
      expect(findProjectsLinks()).toHaveLength(3);

      await wrapper.setProps({ framework: null });

      expect(wrapper.findComponent(GlDrawer).props('open')).toBe(false);
    });

    it('shows loading state correctly during framework changes', async () => {
      const pendingResolverMock = jest.fn().mockReturnValue(new Promise(() => {}));

      createComponent({
        projectsInNamespaceResolverMock: pendingResolverMock,
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
      });

      expect(findProjectsCount().findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findProjectsLinks()).toHaveLength(0);

      const newFramework = createFramework({ id: 999, name: 'New Framework' });
      await wrapper.setProps({ framework: newFramework });

      expect(findProjectsCount().findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findProjectsLinks()).toHaveLength(0);
    });
  });

  describe('orderedRequirements computed property', () => {
    it('sorts requirements by numeric ID', () => {
      const unsortedRequirements = [
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/3',
          name: 'Requirement 3',
          description: 'Description 3',
          __typename: 'ComplianceManagement::Requirement',
          complianceRequirementsControls: { nodes: [] },
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/1',
          name: 'Requirement 1',
          description: 'Description 1',
          __typename: 'ComplianceManagement::Requirement',
          complianceRequirementsControls: { nodes: [] },
        },
        {
          id: 'gid://gitlab/ComplianceManagement::Requirement/2',
          name: 'Requirement 2',
          description: 'Description 2',
          __typename: 'ComplianceManagement::Requirement',
          complianceRequirementsControls: { nodes: [] },
        },
      ];

      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: {
            ...defaultFramework,
            complianceRequirements: { nodes: unsortedRequirements },
          },
        },
      });

      const sortedRequirements = wrapper.vm.orderedRequirements;

      expect(sortedRequirements[0].name).toBe('Requirement 1');
      expect(sortedRequirements[1].name).toBe('Requirement 2');
      expect(sortedRequirements[2].name).toBe('Requirement 3');
    });

    it('returns empty array when requirements are not provided', () => {
      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: {
            ...defaultFramework,
            complianceRequirements: { nodes: null },
          },
        },
      });

      expect(wrapper.vm.orderedRequirements).toEqual([]);
    });
  });
});
