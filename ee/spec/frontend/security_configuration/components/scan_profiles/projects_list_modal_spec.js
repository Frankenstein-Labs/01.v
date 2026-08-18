import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlLoadingIcon, GlKeysetPagination, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import ProjectsListModal from 'ee/security_configuration/components/scan_profiles/projects_list_modal.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import projectsByScannerStatusQuery from 'ee/security_configuration/graphql/scan_profiles/projects_by_scanner_status.query.graphql';

Vue.use(VueApollo);

jest.mock('~/alert');

const GROUP_ID = '123';

const mockProjects = [
  {
    id: 'gid://gitlab/Project/1',
    name: 'Project One',
    fullPath: 'my-group/project-one',
    avatarUrl: null,
    webPath: '/my-group/project-one',
  },
  {
    id: 'gid://gitlab/Project/2',
    name: 'Project Two',
    fullPath: 'my-group/project-two',
    avatarUrl: null,
    webPath: '/my-group/project-two',
  },
];

describe('ProjectsListModal', () => {
  let wrapper;

  const createProjectsResolver = ({ nodes = mockProjects, pageInfo = {} } = {}) =>
    jest.fn().mockResolvedValue({
      data: {
        namespaceSecurityProjects: {
          nodes,
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
            ...pageInfo,
          },
        },
      },
    });

  const createComponent = ({
    props = {},
    projectsResolver = createProjectsResolver(),
    data,
  } = {}) => {
    wrapper = mountExtended(ProjectsListModal, {
      apolloProvider: createMockApollo([[projectsByScannerStatusQuery, projectsResolver]]),
      propsData: { ...props },
      provide: { groupId: GROUP_ID },
      ...(data && { data }),
      stubs: {
        GlModal: stubComponent(GlModal, { template: RENDER_ALL_SLOTS_TEMPLATE }),
        NameCell: true,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findNameCells = () => wrapper.findAllComponents(NameCell);
  const findProjectLinks = () => wrapper.findAllComponents(GlLink);

  it('is not visible by default', () => {
    createComponent();

    expect(findModal().props('visible')).toBe(false);
  });

  describe('when opened', () => {
    it('makes the modal visible', async () => {
      createComponent();

      wrapper.vm.show();
      await waitForPromises();

      expect(findModal().props('visible')).toBe(true);
    });

    it('shows a loading icon while the list is loading', async () => {
      createComponent({ projectsResolver: jest.fn().mockReturnValue(new Promise(() => {})) });

      wrapper.vm.show();
      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('queries for projects with the provided filters', async () => {
      const projectsResolver = createProjectsResolver();
      createComponent({
        props: { filters: { hasStale: true } },
        projectsResolver,
      });

      wrapper.vm.show();
      await waitForPromises();

      expect(projectsResolver).toHaveBeenCalledWith(
        expect.objectContaining({
          namespaceId: 'gid://gitlab/Group/123',
          hasStale: true,
          first: 20,
          after: null,
          last: null,
          before: null,
        }),
      );
    });

    describe('title', () => {
      it('uses the title prop when one is provided', () => {
        createComponent({ props: { title: 'Stale scans' } });

        expect(findModal().props('title')).toBe('Stale scans');
      });

      it('falls back to the default "Projects" title when no title prop is given', () => {
        createComponent();

        expect(findModal().props('title')).toBe('Projects');
      });
    });

    describe('with projects', () => {
      beforeEach(async () => {
        createComponent();
        wrapper.vm.show();
        await waitForPromises();
      });

      it('renders a NameCell and "View project" link for each project', () => {
        expect(findNameCells()).toHaveLength(mockProjects.length);

        const links = findProjectLinks();
        expect(links).toHaveLength(mockProjects.length);
        expect(links.at(0).attributes('href')).toBe('/my-group/project-one');
        expect(links.at(0).text()).toContain('View project');
        expect(links.at(1).attributes('href')).toBe('/my-group/project-two');
      });

      it('passes hide-icons to each NameCell so the leading icon and avatar are hidden', () => {
        findNameCells().wrappers.forEach((cell) => {
          expect(cell.props('hideIcons')).toBe(true);
        });
      });

      it('applies gl-min-w-0 to each NameCell so long project paths can truncate instead of overflowing the modal', () => {
        findNameCells().wrappers.forEach((cell) => {
          expect(cell.classes()).toContain('gl-min-w-0');
        });
      });
    });

    describe('with no projects', () => {
      it('renders "No projects found" message', async () => {
        createComponent({ projectsResolver: createProjectsResolver({ nodes: [] }) });
        wrapper.vm.show();
        await waitForPromises();

        expect(wrapper.text()).toContain('No projects found');
      });
    });

    describe('on error', () => {
      it('creates an alert when the projects query fails', async () => {
        createComponent({ projectsResolver: jest.fn().mockRejectedValue(new Error()) });
        wrapper.vm.show();
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to load projects',
        });
      });
    });

    describe('pagination', () => {
      it('does not render pagination when there is only one page', async () => {
        createComponent();
        wrapper.vm.show();
        await waitForPromises();

        expect(findPagination().exists()).toBe(false);
      });

      it('renders pagination when there is a next page', async () => {
        createComponent({
          projectsResolver: createProjectsResolver({
            pageInfo: { hasNextPage: true, endCursor: 'END_CURSOR' },
          }),
          data: () => ({ visible: true }),
        });
        await waitForPromises();

        expect(findPagination().exists()).toBe(true);
      });

      it('renders pagination when there is a previous page', async () => {
        createComponent({
          projectsResolver: createProjectsResolver({
            pageInfo: { hasPreviousPage: true, startCursor: 'START_CURSOR' },
          }),
          data: () => ({ visible: true }),
        });
        await waitForPromises();

        expect(findPagination().exists()).toBe(true);
      });

      it('requests the next page with the end cursor when next is emitted', async () => {
        const projectsResolver = createProjectsResolver({
          pageInfo: { hasNextPage: true, endCursor: 'END_CURSOR' },
        });
        createComponent({ projectsResolver });
        wrapper.vm.show();
        await waitForPromises();

        findPagination().vm.$emit('next', 'END_CURSOR');
        await waitForPromises();

        expect(projectsResolver).toHaveBeenLastCalledWith(
          expect.objectContaining({ after: 'END_CURSOR', before: null, first: 20, last: null }),
        );
      });

      it('requests the previous page with the start cursor when prev is emitted', async () => {
        const projectsResolver = createProjectsResolver({
          pageInfo: { hasPreviousPage: true, startCursor: 'START_CURSOR' },
        });
        createComponent({ projectsResolver });
        wrapper.vm.show();
        await waitForPromises();

        findPagination().vm.$emit('prev', 'START_CURSOR');
        await waitForPromises();

        expect(projectsResolver).toHaveBeenLastCalledWith(
          expect.objectContaining({ before: 'START_CURSOR', after: null, first: null, last: 20 }),
        );
      });
    });
  });

  describe('when closed', () => {
    it('hides the modal and emits the hidden event', async () => {
      createComponent();
      wrapper.vm.show();
      await waitForPromises();

      findModal().vm.$emit('hidden');
      await nextTick();

      expect(findModal().props('visible')).toBe(false);
      expect(wrapper.emitted('hidden')).toHaveLength(1);
    });
  });
});
